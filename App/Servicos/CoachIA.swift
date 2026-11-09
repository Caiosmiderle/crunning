import CrunningCore
import Foundation

/// Resposta estruturada da análise de um plano.
struct AnaliseIA: Decodable, Equatable {
    struct Ponto: Decodable, Equatable, Hashable {
        let gravidade: String
        let semanas: [Int]
        let problema: String
        let sugestao: String
        /// Correção que o motor sabe aplicar (nil quando a sugestão é só texto).
        let correcao: CorrecaoIA?
    }

    let avaliacao: String
    let resumo: String
    let pontos: [Ponto]
    let positivos: [String]
}

/// Correção sugerida pela IA, no formato do esquema. O app converte em `CorrecaoPlano`,
/// que passa pelo motor e pelas travas antes de aparecer como proposta.
struct CorrecaoIA: Decodable, Equatable, Hashable {
    let tipo: String
    let semana: Int?
    let dia: Int?
    let paraDia: Int?
    let fatorPercentual: Int?
    let semanas: Int?
    let tetoPercentual: Int?
    let dias: [Int]?
    let diaLongao: Int?
    let diasParado: Int?

    var correcao: CorrecaoPlano? {
        switch tipo {
        case "aliviar_semana":
            return semana.map { .aliviarSemana(semana: $0) }
        case "reduzir_semana":
            guard let semana, let fatorPercentual else { return nil }
            return .reduzirSemana(semana: semana, fator: Double(fatorPercentual) / 100)
        case "mover_treino":
            guard let semana, let dia, let paraDia else { return nil }
            return .moverTreino(semana: semana, de: dia, para: paraDia)
        case "trocar_treino":
            guard let semana, let dia else { return nil }
            return .trocarTreino(semana: semana, dia: dia)
        case "mudar_semanas":
            return semanas.map { .mudarSemanas($0) }
        case "mudar_teto":
            return tetoPercentual.map { .mudarTeto(Double($0) / 100) }
        case "mudar_dias":
            guard let dias, let diaLongao else { return nil }
            return .mudarDias(Set(dias), longao: diaLongao)
        case "retomar_apos_pausa":
            guard let semana, let diasParado else { return nil }
            return .retomarAposPausa(semana: semana, dias: diasParado)
        case "reajustar_prova":
            guard let semana, let semanas else { return nil }
            return .reajustarProva(aPartirDaSemana: semana, semanasRestantes: semanas)
        default:
            return nil
        }
    }
}

enum ErroCoachIA: LocalizedError {
    case semChave
    case chaveInvalida
    case semPermissao(String)
    case limite
    case pedidoInvalido(String)
    case servidor(Int, String)
    case recusa(String?)
    case respostaIncompleta
    case respostaInvalida

    var errorDescription: String? {
        switch self {
        case .semChave: L("Salve a sua chave da API em Ajustes > Coach de IA.", "Save your API key in Settings > AI Coach.")
        case .chaveInvalida: L("A chave da API foi recusada. Confira em Ajustes > Coach de IA.", "The API key was rejected. Check it in Settings > AI Coach.")
        case let .semPermissao(m): L("A chave não tem permissão para isso. \(m)", "The key does not have permission for this. \(m)")
        case .limite: L("Limite de uso da API atingido. Tente de novo em alguns minutos.", "API usage limit reached. Try again in a few minutes.")
        case let .pedidoInvalido(m): L("A API recusou o pedido: \(m)", "The API rejected the request: \(m)")
        case let .servidor(codigo, m): L("A API respondeu com erro \(codigo). \(m)", "The API returned error \(codigo). \(m)")
        case let .recusa(categoria): L("O modelo não quis analisar este pedido", "The model declined to analyze this request") + (categoria.map { " (\($0))." } ?? ".")
        case .respostaIncompleta: L("A resposta veio cortada. Tente de novo.", "The response was cut off. Try again.")
        case .respostaInvalida: L("A resposta veio num formato inesperado. Tente de novo.", "The response came in an unexpected format. Try again.")
        }
    }
}

/// Revisão do plano por IA, chamando a API da Anthropic direto do iPhone com a chave do
/// Keychain. Vai só o resumo agregado do plano: nunca rota, GPS, nome ou dados do Saúde.
/// A análise é um parecer: quem muda o plano continua sendo o motor (com as travas).
enum CoachIA {
    static let modelo = "claude-sonnet-5-5"
    static let endereco = URL(string: "https://api.anthropic.com/v1/messages")!

    static func analisar(_ plano: Plano, alertas: [String]) async throws -> AnaliseIA {
        guard let chave = Chaveiro.ler() else { throw ErroCoachIA.semChave }
        var pedido = URLRequest(url: endereco, timeoutInterval: 180)
        pedido.httpMethod = "POST"
        pedido.setValue("application/json", forHTTPHeaderField: "content-type")
        pedido.setValue(chave, forHTTPHeaderField: "x-api-key")
        pedido.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // Se o Sonnet 5.5 recusar por engano, a API tenta de novo em outro modelo na mesma chamada.
        pedido.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        pedido.httpBody = try corpo(plano, alertas: alertas)

        for tentativa in 0..<2 {
            let (dados, resposta) = try await URLSession.shared.data(for: pedido)
            let http = resposta as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            if status == 200 { return try ler(dados) }
            let mensagem = mensagemDeErro(dados)
            let temporario = status == 429 || status >= 500
            if temporario && tentativa == 0 {
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

    // MARK: Pedido

    static func corpo(_ plano: Plano, alertas: [String]) throws -> Data {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.sortedKeys]
        let resumo = String(decoding: try codificador.encode(ResumoPlanoIA(plano: plano, alertas: alertas)), as: UTF8.self)
        let corpo: [String: Any] = [
            "model": modelo,
            "max_tokens": 16000,
            "fallbacks": "default",
            "system": instrucoes,
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": esquema],
            ],
            "messages": [
                ["role": "user", "content": "Analise este plano gerado pelo motor do CRUNNING (distâncias em km, tempos em minutos):\n\n" + resumo],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: corpo)
    }

    static func anulavel(_ tipo: [String: Any]) -> [String: Any] {
        ["anyOf": [tipo, ["type": "null"]]]
    }

    static var esquemaCorrecao: [String: Any] { anulavel(esquemaCorrecaoObjeto) }

    static var esquemaCorrecaoObjeto: [String: Any] {
        let inteiro: [String: Any] = ["type": "integer"]
        return [
            "type": "object",
            "properties": [
                "tipo": ["type": "string", "enum": [
                    "aliviar_semana", "reduzir_semana", "mover_treino", "trocar_treino", "mudar_semanas", "mudar_teto", "mudar_dias",
                    "retomar_apos_pausa", "reajustar_prova",
                ]],
                "semana": anulavel(inteiro),
                "dia": anulavel(inteiro),
                "paraDia": anulavel(inteiro),
                "fatorPercentual": anulavel(inteiro),
                "semanas": anulavel(inteiro),
                "tetoPercentual": anulavel(inteiro),
                "dias": anulavel(["type": "array", "items": inteiro]),
                "diaLongao": anulavel(inteiro),
                "diasParado": anulavel(inteiro),
            ],
            "required": ["tipo", "semana", "dia", "paraDia", "fatorPercentual", "semanas", "tetoPercentual", "dias", "diaLongao", "diasParado"],
            "additionalProperties": false,
        ]
    }

    static var esquema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "avaliacao": ["type": "string", "enum": ["boa", "aceitavel", "problematica"]],
                "resumo": ["type": "string"],
                "pontos": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "gravidade": ["type": "string", "enum": ["alta", "media", "baixa"]],
                            "semanas": ["type": "array", "items": ["type": "integer"]],
                            "problema": ["type": "string"],
                            "sugestao": ["type": "string"],
                            "correcao": esquemaCorrecao,
                        ],
                        "required": ["gravidade", "semanas", "problema", "sugestao", "correcao"],
                        "additionalProperties": false,
                    ],
                ],
                "positivos": ["type": "array", "items": ["type": "string"]],
            ],
            "required": ["avaliacao", "resumo", "pontos", "positivos"],
            "additionalProperties": false,
        ]
    }

    static let instrucoesBase = """
    Você é um treinador de corrida experiente revisando um plano de treino gerado por um motor de regras determinístico, para um corredor amador que treina sozinho. O seu parecer ajuda a achar o que não faz sentido para um treinador, mesmo quando as travas de segurança do motor foram respeitadas.

    Avalie:
    - Se a progressão de volume e do longão faz sentido semana a semana (sem saltos, sem quedas sem motivo, sem semanas repetidas sem razão).
    - Se o longão é claramente a maior corrida e se as outras corridas têm tamanhos coerentes entre si.
    - Se a distribuição de intensidade é adequada (a maior parte fácil) e se os treinos de qualidade são variados, bem posicionados na semana e adequados à fase.
    - Se o plano é específico para o objetivo (por exemplo, longão e ritmo de prova na maratona; intervalado na prova de 5 km).
    - Se as fases, as semanas de alívio e o polimento fazem sentido para o número de semanas.
    - Se o plano é realista para o volume atual, a maior corrida recente e o nível informados.
    - Os alertas que o próprio motor emitiu.

    Regras:
    - Use só os dados enviados. Não invente treinos, números ou fatos sobre o corredor.
    - As travas de segurança do motor são obrigatórias e não podem ser contrariadas pelas suas sugestões: nenhuma corrida passa 10% da maior corrida das 4 semanas anteriores; o volume semanal sobe no máximo o teto informado sobre as 3 semanas anteriores e nunca mais de 25% de uma semana para a outra; no máximo 2 treinos de qualidade por semana (1 para iniciante), nunca em dias seguidos nem colados no longão; até 20% do volume em qualidade.
    - Aponte problemas concretos, com as semanas envolvidas e uma sugestão prática. Separe gravidade: alta (faz o plano errar o objetivo ou arrisca lesão), média (atrapalha o rendimento), baixa (ajuste fino).
    - Se o plano estiver bom, diga isso e liste poucos pontos.
    - Não dê conselho médico.
    - Escreva em \(Idioma.atual == .ingles ? "inglês (English)" : "português do Brasil"), de forma direta, como um treinador falando com o atleta.
    """

    static let instrucoesDasOperacoes = """
    Correções que o app sabe aplicar (campo "correcao" de cada ponto):
    - Quando uma destas operações resolve o problema, preencha "correcao"; quando não resolve, use null e deixe a sugestão só no texto. O corredor vê a correção como proposta, com o antes e o depois, e decide se aplica. O motor confere todas as travas e recusa o que não couber.
    - Semanas começam em 1. Dias: 0 = segunda, 1 = terça, 2 = quarta, 3 = quinta, 4 = sexta, 5 = sábado, 6 = domingo (o campo "indiceDia" de cada sessão).
    - "aliviar_semana" (semana): a semana vira alívio, com 20% menos volume; as seguintes são refeitas.
    - "reduzir_semana" (semana, fatorPercentual de 50 a 95): a semana fica com essa porcentagem do volume; as seguintes são refeitas.
    - "mover_treino" (semana, dia, paraDia): troca o conteúdo de dois dias da mesma semana.
    - "trocar_treino" (semana, dia): troca o treino do dia por outro com o mesmo estímulo e a mesma dose.
    - "mudar_semanas" (semanas, de 1 a 30): refaz o plano com esse número de semanas.
    - "mudar_teto" (tetoPercentual, de 5 a 20): refaz o plano com esse aumento máximo de volume por semana.
    - "mudar_dias" (dias, diaLongao): refaz o plano com esses dias de corrida (pelo menos 2) e o longão num deles.
    - "retomar_apos_pausa" (semana, diasParado acima de 5): a semana recomeça com uma fração do volume de antes e sobe aos poucos.
    - "reajustar_prova" (semana, semanas): nova data de prova; a partir da semana, faltam esse número de semanas.
    - Preencha só os campos da operação escolhida; os outros vão como null.
    """

    static let instrucoes = instrucoesBase + "\n\n" + instrucoesDasOperacoes

    // MARK: Resposta

    private struct RespostaAPI: Decodable {
        struct Bloco: Decodable {
            let type: String
            let text: String?
        }

        struct Detalhes: Decodable {
            let category: String?
        }

        let content: [Bloco]
        let stopReason: String?
        let stopDetails: Detalhes?
    }

    private struct CorpoErro: Decodable {
        struct Erro: Decodable { let message: String }
        let error: Erro
    }

    static func ler(_ dados: Data) throws -> AnaliseIA {
        let decodificador = JSONDecoder()
        decodificador.keyDecodingStrategy = .convertFromSnakeCase
        guard let resposta = try? decodificador.decode(RespostaAPI.self, from: dados) else { throw ErroCoachIA.respostaInvalida }
        switch resposta.stopReason {
        case "refusal": throw ErroCoachIA.recusa(resposta.stopDetails?.category)
        case "max_tokens": throw ErroCoachIA.respostaIncompleta
        default: break
        }
        guard let texto = resposta.content.last(where: { $0.type == "text" })?.text,
              let json = texto.data(using: .utf8),
              let analise = try? JSONDecoder().decode(AnaliseIA.self, from: json) else {
            throw ErroCoachIA.respostaInvalida
        }
        return analise
    }

    static func mensagemDeErro(_ dados: Data) -> String {
        (try? JSONDecoder().decode(CorpoErro.self, from: dados))?.error.message ?? ""
    }
}

/// O que vai para a IA: só dados agregados do plano.
struct ResumoPlanoIA: Encodable {
    struct Sessao: Encodable {
        let dia: String
        let indiceDia: Int
        let tipo: String
        let treino: String
        let km: Double
        let minutos: Int
        let trabalhoDeQualidadeKm: Double?
    }

    struct Semana: Encodable {
        let numero: Int
        let fase: String
        let alivio: Bool
        let volumeDeTreinoKm: Double
        let temProva: Bool
        let sessoes: [Sessao]
    }

    static let dias = ["segunda", "terça", "quarta", "quinta", "sexta", "sábado", "domingo"]

    let objetivo: String
    let semanas: Int
    let nivel: String
    let diasDisponiveisPorSemana: Int
    let volumeAtualKm: Double
    let maiorCorridaRecenteKm: Double
    let vdot: Double?
    let tetoDeProgressaoPercentual: Int
    let alertasDoMotor: [String]
    let regrasDoMotor: [String]
    let plano: [Semana]

    init(plano p: Plano, alertas: [String]) {
        func km(_ m: Double) -> Double { (m / 100).rounded() / 10 }
        let e = p.entrada
        objetivo = e.objetivo.nome
        semanas = p.semanas.count
        nivel = e.nivel.nome
        diasDisponiveisPorSemana = e.diasDisponiveis.count
        volumeAtualKm = km(e.volumeAtual)
        maiorCorridaRecenteKm = km(e.longaoAtual)
        vdot = e.vdot.map { ($0 * 10).rounded() / 10 }
        tetoDeProgressaoPercentual = Int((e.tetoProgressao * 100).rounded())
        alertasDoMotor = alertas
        regrasDoMotor = p.regras
        plano = p.semanas.map { s in
            Semana(
                numero: s.numero, fase: s.fase.nome, alivio: s.alivio, volumeDeTreinoKm: km(s.volumeTreino), temProva: s.temProva,
                sessoes: s.dias.enumerated().compactMap { dia, sessao in
                    sessao.map {
                        Sessao(dia: Self.dias[dia], indiceDia: dia, tipo: $0.tipo.nome, treino: $0.treino.nome, km: km($0.distancia),
                               minutos: Int(($0.duracao / 60).rounded()),
                               trabalhoDeQualidadeKm: $0.trabalhoDeQualidade > 0 ? km($0.trabalhoDeQualidade) : nil)
                    }
                }
            )
        }
    }
}
