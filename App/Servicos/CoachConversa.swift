import CrunningCore
import Foundation

/// Pedido genérico à API da Anthropic com resposta em JSON (structured outputs). A chave vem
/// do Keychain; vão só dados agregados. O modelo nunca escreve o plano: escolhe operações e
/// parâmetros de uma lista fechada, que o motor aplica e confere.
enum ClienteClaude {
    static let sonnet = "claude-sonnet-5-5"
    static let haiku = "claude-haiku-5-5"

    struct Mensagem: Sendable {
        var papel: String
        var texto: String
    }

    static func corpo(modelo: String, sistema: String, mensagens: [Mensagem], esquema: [String: Any], effort: String) throws -> Data {
        var corpo: [String: Any] = [
            "model": modelo,
            "max_tokens": 16000,
            "system": sistema,
            "messages": mensagens.map { ["role": $0.papel, "content": $0.texto] },
            "output_config": ["effort": effort, "format": ["type": "json_schema", "schema": esquema]],
        ]
        // Só o Sonnet tem a troca de modelo no servidor em caso de recusa por engano.
        if modelo == sonnet { corpo["fallbacks"] = "default" }
        return try JSONSerialization.data(withJSONObject: corpo)
    }

    private struct Resposta: Decodable {
        struct Bloco: Decodable {
            let type: String
            let text: String?
        }

        struct Detalhes: Decodable { let category: String? }

        let content: [Bloco]
        let stopReason: String?
        let stopDetails: Detalhes?
    }

    /// Envia e devolve o JSON da resposta (o texto do último bloco).
    static func enviar(_ corpo: Data, modelo: String) async throws -> Data {
        guard let chave = Chaveiro.ler() else { throw ErroCoachIA.semChave }
        var pedido = URLRequest(url: CoachIA.endereco, timeoutInterval: 180)
        pedido.httpMethod = "POST"
        pedido.setValue("application/json", forHTTPHeaderField: "content-type")
        pedido.setValue(chave, forHTTPHeaderField: "x-api-key")
        pedido.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        if modelo == sonnet { pedido.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta") }
        pedido.httpBody = corpo
        for tentativa in 0..<2 {
            let (dados, resposta) = try await URLSession.shared.data(for: pedido)
            let http = resposta as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            if status == 200 { return try texto(dados) }
            let mensagem = CoachIA.mensagemDeErro(dados)
            if (status == 429 || status >= 500) && tentativa == 0 {
                let espera = Double(http?.value(forHTTPHeaderField: "retry-after") ?? "") ?? 3
                try await Task.sleep(for: .seconds(min(max(espera, 1), 20)))
                continue
            }
            switch status {
            case 401: throw ErroCoachIA.chaveInvalida
            case 403: throw ErroCoachIA.semPermissao(mensagem)
            case 429: throw ErroCoachIA.limite
            case 400, 404, 413: throw ErroCoachIA.pedidoInvalido(mensagem)
            default: throw ErroCoachIA.servidor(status, mensagem)
            }
        }
        throw ErroCoachIA.limite
    }

    static func texto(_ dados: Data) throws -> Data {
        let decodificador = JSONDecoder()
        decodificador.keyDecodingStrategy = .convertFromSnakeCase
        guard let r = try? decodificador.decode(Resposta.self, from: dados) else { throw ErroCoachIA.respostaInvalida }
        switch r.stopReason {
        case "refusal": throw ErroCoachIA.recusa(r.stopDetails?.category)
        case "max_tokens": throw ErroCoachIA.respostaIncompleta
        default: break
        }
        guard let t = r.content.last(where: { $0.type == "text" })?.text, let json = t.data(using: .utf8) else {
            throw ErroCoachIA.respostaInvalida
        }
        return json
    }

    static var simulado: Bool {
        let d = UserDefaults.standard
        return d.bool(forKey: Preferencias.modoDesenvolvimento) && d.bool(forKey: Preferencias.simularCoach)
    }
}

/// O que vai para a IA sobre o plano em uso: o resumo agregado e o que foi feito ou perdido.
struct ContextoAgendaIA: Encodable {
    let hoje: String
    let semanaAtual: Int?
    let diaDeHoje: Int?
    let feitos: [String]
    let perdidos: [String]
    let esforcoPorSessao: [String: Int]
    /// Treinos de qualidade recentes: "rapido", "lento" ou "na faixa".
    let ritmoDosTreinosDeQualidade: [String]
    let plano: ResumoPlanoIA

    init(agenda: AgendaPlano, ladosRecentes: [Bool?], hoje: Date = .now) {
        let p = agenda.posicao(de: hoje)
        self.hoje = hoje.formatted(.iso8601.year().month().day())
        semanaAtual = p?.semana
        diaDeHoje = p?.dia
        let ordenados = agenda.registros.sorted { $0.key < $1.key }
        feitos = ordenados.filter { $0.value == .feita }.map { "semana-dia \($0.key)" }
        perdidos = ordenados.filter { $0.value == .perdida }.map { "semana-dia \($0.key)" }
        esforcoPorSessao = agenda.esforcos
        ritmoDosTreinosDeQualidade = ladosRecentes.map { $0.map { $0 ? "rapido" : "lento" } ?? "na faixa" }
        plano = ResumoPlanoIA(plano: agenda.plano, alertas: GeradorPlano.alertas(agenda.plano))
    }

    func json() -> String {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.sortedKeys]
        return (try? codificador.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
}

// MARK: - Chat de ajustes (Haiku)

struct RespostaChatCoach: Decodable {
    let mensagem: String
    let acoes: [CorrecaoIA]
}

enum CoachChat {
    static var esquema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "mensagem": ["type": "string"],
                "acoes": ["type": "array", "items": CoachIA.esquemaCorrecaoObjeto],
            ],
            "required": ["mensagem", "acoes"],
            "additionalProperties": false,
        ]
    }

    static func sistema(_ contexto: ContextoAgendaIA) -> String {
        """
        Você é o treinador de corrida do CRUNNING conversando com o atleta sobre o plano dele. Ele escreve situações como "viajo semana que vem", "estou com a canela dolorida", "troca o longão de dia" ou "quero mais semanas".

        Responda em \(Idioma.atual == .ingles ? "inglês (English)" : "português do Brasil"), curto e direto, como um treinador. Em "mensagem", explique o que você propõe e por quê. Em "acoes", liste as operações do motor que resolvem o pedido (pode ser nenhuma). O atleta vê a proposta com o antes e o depois e decide se salva; o motor confere todas as travas de segurança e recusa o que não couber.

        Regras:
        - Use só as operações do esquema; nunca invente treinos ou números. Não mexa em semanas que já passaram (antes de "semanaAtual").
        - Dor que muda a passada ou que persiste, febre ou sintomas abaixo do pescoço: oriente parar e procurar um profissional; não prescreva treino por cima. Não dê conselho médico.
        - Se o pedido não couber nas operações, explique o que dá para fazer.

        \(CoachIA.instrucoesDasOperacoes)

        Plano atual e o que foi feito (distâncias em km, tempos em minutos):
        \(contexto.json())
        """
    }

    /// Responde à conversa. `extra` vai como última mensagem do atleta (por exemplo, o erro do motor numa segunda tentativa).
    static func responder(_ historico: [ClienteClaude.Mensagem], contexto: ContextoAgendaIA) async throws -> RespostaChatCoach {
        if ClienteClaude.simulado { return simular(historico.last?.texto ?? "", semana: contexto.semanaAtual ?? 1) }
        let corpo = try ClienteClaude.corpo(modelo: ClienteClaude.haiku, sistema: sistema(contexto), mensagens: historico, esquema: esquema, effort: "medium")
        let json = try await ClienteClaude.enviar(corpo, modelo: ClienteClaude.haiku)
        guard let r = try? JSONDecoder().decode(RespostaChatCoach.self, from: json) else { throw ErroCoachIA.respostaInvalida }
        return r
    }

    /// Modo de desenvolvimento: respostas fixas por palavra-chave, sem chamar a API.
    static func simular(_ texto: String, semana: Int) -> RespostaChatCoach {
        let t = texto.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR")).lowercased()
        func acao(_ tipo: String, semana: Int? = nil, fator: Int? = nil, dias: Int? = nil) -> CorrecaoIA {
            CorrecaoIA(tipo: tipo, semana: semana, dia: nil, paraDia: nil, fatorPercentual: fator, semanas: nil,
                       tetoPercentual: nil, dias: nil, diaLongao: nil, diasParado: dias)
        }
        if t.contains("viag") || t.contains("ferias") {
            return RespostaChatCoach(mensagem: "(simulado) Sem problema: deixo a semana que vem como alívio, com 20% menos volume.", acoes: [acao("aliviar_semana", semana: semana + 1)])
        }
        if t.contains("dor") || t.contains("canela") || t.contains("joelho") {
            return RespostaChatCoach(mensagem: "(simulado) Vamos reduzir esta semana para 80%. Se a dor mudar a passada ou continuar, pare e procure um profissional.", acoes: [acao("reduzir_semana", semana: semana, fator: 80)])
        }
        if t.contains("parad") {
            return RespostaChatCoach(mensagem: "(simulado) Depois de duas semanas parado, a volta é aos poucos.", acoes: [acao("retomar_apos_pausa", semana: semana, dias: 14)])
        }
        return RespostaChatCoach(mensagem: "(simulado) Entendi. Neste modo eu só reajo a viagem, dor e tempo parado.", acoes: [])
    }
}

// MARK: - Revisão semanal (Sonnet)

enum RevisaoCoach {
    static func revisar(_ contexto: ContextoAgendaIA) async throws -> AnaliseIA {
        if ClienteClaude.simulado {
            let semana = (contexto.semanaAtual ?? 1) + 1
            return AnaliseIA(
                avaliacao: "aceitavel",
                resumo: "(simulado) Semana com boa aderência, mas as fáceis pareceram pesadas.",
                pontos: [AnaliseIA.Ponto(gravidade: "media", semanas: [semana], problema: "Esforço alto nas corridas fáceis.",
                                         sugestao: "Uma semana de alívio antes de subir de novo.",
                                         correcao: CorrecaoIA(tipo: "aliviar_semana", semana: semana, dia: nil, paraDia: nil, fatorPercentual: nil,
                                                              semanas: nil, tetoPercentual: nil, dias: nil, diaLongao: nil, diasParado: nil))],
                positivos: ["Treinos de qualidade no ritmo."]
            )
        }
        let sistema = CoachIA.instrucoes + """


        Esta é a revisão semanal do plano em uso: compare o planejado com o feito (sessões feitas e perdidas, esforço percebido de cada uma e se os treinos de qualidade saíram rápidos, lentos ou na faixa). Avalie a aderência e proponha correções só para semanas a partir da atual ("semanaAtual"). Se a semana foi bem, diga isso.
        """
        let mensagem = ClienteClaude.Mensagem(papel: "user", texto: "Revise o plano em uso (distâncias em km, tempos em minutos):\n\n" + contexto.json())
        let corpo = try ClienteClaude.corpo(modelo: ClienteClaude.sonnet, sistema: sistema, mensagens: [mensagem], esquema: CoachIA.esquema, effort: "medium")
        let json = try await ClienteClaude.enviar(corpo, modelo: ClienteClaude.sonnet)
        guard let analise = try? JSONDecoder().decode(AnaliseIA.self, from: json) else { throw ErroCoachIA.respostaInvalida }
        return analise
    }
}

// MARK: - Plano montado com o coach (Sonnet)

/// Respostas do questionário (o que a pessoa contou), mandadas como estão.
struct QuestionarioPlano: Encodable {
    var objetivo: String
    var semanas: Int
    var nivel: String
    var dias: [Int]
    var diaLongao: Int
    var volumeAtualKm: Int
    var maiorCorridaRecenteKm: Int
    var terreno: String
    var lesoesELimitacoes: String
    var temProvaDeReferencia: Bool
}

struct EscolhaPlanoIA: Decodable {
    let objetivo: String
    let semanas: Int
    let nivel: String
    let dias: [Int]
    let diaLongao: Int
    let volumeAtualKm: Double
    let longaoAtualKm: Double
    let tetoPercentual: Int
    let explicacao: String
}

enum CriadorPlanoCoach {
    static let objetivos = ["5 km", "10 km", "Meia maratona", "Maratona", "Condicionamento", "Começar a correr"]

    static func objetivo(_ nome: String) -> Objetivo {
        switch nome {
        case "5 km": .cincoK
        case "10 km": .dezK
        case "Meia maratona": .meia
        case "Maratona": .maratona
        case "Começar a correr": .comecarACorrer
        default: .condicionamento
        }
    }

    static func nivel(_ nome: String) -> Nivel {
        Nivel.allCases.first { $0.nome == nome } ?? .intermediario
    }

    static var esquema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "objetivo": ["type": "string", "enum": objetivos],
                "semanas": ["type": "integer"],
                "nivel": ["type": "string", "enum": Nivel.allCases.map(\.nome)],
                "dias": ["type": "array", "items": ["type": "integer"]],
                "diaLongao": ["type": "integer"],
                "volumeAtualKm": ["type": "number"],
                "longaoAtualKm": ["type": "number"],
                "tetoPercentual": ["type": "integer"],
                "explicacao": ["type": "string"],
            ],
            "required": ["objetivo", "semanas", "nivel", "dias", "diaLongao", "volumeAtualKm", "longaoAtualKm", "tetoPercentual", "explicacao"],
            "additionalProperties": false,
        ]
    }

    static let sistema = """
    Você é o treinador de corrida do CRUNNING montando o plano de um corredor amador a partir do que ele contou. Você não escreve treinos: escolhe os parâmetros do motor de regras, que monta o plano com as travas de segurança.

    Escolha:
    - objetivo, semanas (1 a 30), nivel, dias de corrida (0 = segunda ... 6 = domingo, pelo menos 2, só entre os dias que ele disse que pode; pode usar menos, nunca outros) e diaLongao (um dos dias);
    - volumeAtualKm e longaoAtualKm: use o que ele contou; reduza só se houver lesão recente ou volta de pausa, e explique;
    - tetoPercentual (5 a 20): aumento máximo do volume por semana. Use 10 por padrão; menos com lesão recente, histórico de lesões ou iniciante; nunca mais de 10 sem motivo claro.
    Não invente tempo de prova nem dados que ele não deu. Se ele já tiver prova de referência no app, os ritmos saem dela.

    Em "explicacao", diga em 2 a 4 frases, em \(Idioma.atual == .ingles ? "inglês (English)" : "português do Brasil"), por que escolheu assim (em especial o que mudou em relação ao que ele pediu). Não dê conselho médico.
    """

    /// Pede os parâmetros à IA, monta e confere. Uma segunda tentativa leva o motivo da recusa;
    /// se falhar de novo, monta pelas regras com as respostas como estão e avisa.
    static func montar(_ q: QuestionarioPlano, vdot: Double?) async throws -> (plano: Plano, explicacao: String) {
        func entrada(_ e: EscolhaPlanoIA) -> EntradaPlano {
            // Os dias são os que você marcou: a IA pode usar menos, nunca outros.
            let marcados = Set(q.dias.filter { (0...6).contains($0) })
            var dias = Set(e.dias).intersection(marcados)
            if dias.count < 2 { dias = marcados }
            let longao = dias.contains(e.diaLongao) ? e.diaLongao : (dias.contains(q.diaLongao) ? q.diaLongao : (dias.max() ?? q.diaLongao))
            return EntradaPlano(
                objetivo: objetivo(e.objetivo), semanas: min(max(e.semanas, 1), 30), nivel: nivel(e.nivel),
                diasDisponiveis: dias, diaLongao: longao,
                volumeAtual: max(0, e.volumeAtualKm) * 1000, longaoAtual: max(0, e.longaoAtualKm) * 1000, vdot: vdot,
                tetoProgressao: Double(min(max(e.tetoPercentual, 5), 20)) / 100
            )
        }
        let doQuestionario = EscolhaPlanoIA(
            objetivo: q.objetivo, semanas: q.semanas, nivel: q.nivel, dias: q.dias, diaLongao: q.diaLongao,
            volumeAtualKm: Double(q.volumeAtualKm), longaoAtualKm: Double(q.maiorCorridaRecenteKm), tetoPercentual: 10,
            explicacao: "(simulado) Montei com as suas respostas, sem mudanças."
        )
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.sortedKeys]
        let respostas = String(decoding: try codificador.encode(q), as: UTF8.self)
        var mensagens = [ClienteClaude.Mensagem(papel: "user", texto: "Respostas do corredor:\n\n" + respostas)]
        for tentativa in 0..<2 {
            let escolha: EscolhaPlanoIA
            if ClienteClaude.simulado {
                escolha = doQuestionario
            } else {
                let corpo = try ClienteClaude.corpo(modelo: ClienteClaude.sonnet, sistema: sistema, mensagens: mensagens, esquema: esquema, effort: "medium")
                let json = try await ClienteClaude.enviar(corpo, modelo: ClienteClaude.sonnet)
                guard let e = try? JSONDecoder().decode(EscolhaPlanoIA.self, from: json) else { throw ErroCoachIA.respostaInvalida }
                escolha = e
            }
            let e = entrada(escolha)
            let motivo: String
            if e.diasDisponiveis.count < 2 || !e.diasDisponiveis.contains(e.diaLongao) {
                motivo = "Escolha pelo menos 2 dias, com o longão num deles."
            } else {
                switch GeradorPlano.viabilidade(e) {
                case .viavel:
                    let plano = GeradorPlano.gerar(e)
                    if ValidadorPlano.validar(plano).isEmpty { return (plano, escolha.explicacao) }
                    motivo = "O plano gerado não passou nas travas."
                case let .curto(_, m), let .naoRecomendado(m):
                    motivo = m
                }
            }
            if tentativa == 0, !ClienteClaude.simulado {
                let resumo = "Escolhi \(escolha.objetivo), \(escolha.semanas) semanas, \(escolha.nivel), dias \(escolha.dias), longão no dia \(escolha.diaLongao), aumento de até \(escolha.tetoPercentual)% por semana."
                mensagens.append(ClienteClaude.Mensagem(papel: "assistant", texto: resumo))
                mensagens.append(ClienteClaude.Mensagem(papel: "user", texto: "O motor recusou: \(motivo) Escolha de novo respeitando isso."))
            }
        }
        // Pelas regras, com as respostas como estão (semanas no mínimo viável).
        var e = entrada(doQuestionario)
        if case let .curto(minimas, _) = GeradorPlano.viabilidade(e) { e.semanas = minimas }
        let plano = GeradorPlano.gerar(e)
        return (plano, L("O coach não chegou a um plano que passasse nas travas; montei pelas regras com as suas respostas", "The coach could not reach a plan that passed the safety limits; I built it by the rules with your answers") + (e.semanas != q.semanas ? L(", com \(e.semanas) semanas (o mínimo para a prova).", ", with \(e.semanas) weeks (the minimum for the race).") : "."))
    }
}
