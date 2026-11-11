import CrunningCore
import Foundation
import SwiftData

/// Parecer do treinador de IA sobre uma corrida (o esquema que a API devolve).
struct AnaliseTreino: Codable, Equatable {
    struct Ajuste: Codable, Equatable, Hashable {
        let oQueAconteceu: String
        let comoFazer: String

        enum CodingKeys: String, CodingKey {
            case oQueAconteceu = "o_que_aconteceu"
            case comoFazer = "como_fazer"
        }
    }

    /// "boa", "aceitavel" ou "fora_do_plano".
    let execucao: String
    let resumo: String
    let positivos: [String]
    let ajustes: [Ajuste]
    let proximaVez: String

    enum CodingKeys: String, CodingKey {
        case execucao, resumo, positivos, ajustes
        case proximaVez = "proxima_vez"
    }
}

/// Quanto a análise gastou, pelos tokens que a própria API informou na resposta.
struct UsoIA: Codable, Equatable {
    let modelo: String
    let entrada: Int
    let saida: Int
    /// nil se o modelo não estiver na tabela de preços do app.
    let custoUSD: Double?
    /// A API trocou de modelo no meio (recusa por engano): o custo é aproximado.
    let comFallback: Bool

    var nomeModelo: String {
        if modelo.contains("opus") { return "Claude Opus 5.5" }
        if modelo.contains("sonnet") { return "Claude Sonnet 5.5" }
        return modelo
    }
}

struct AnaliseSalva: Codable, Equatable {
    let analise: AnaliseTreino
    let uso: UsoIA?
    let data: Date
    /// Resposta fictícia do modo de desenvolvimento (não chamou a API).
    let simulada: Bool
}

/// Análise pós-treino com o Claude Opus 5.5 (escolhido num teste cego de 3 modelos × 10 tentativas:
/// o único sem erro de conta e o que mais explicou a causa do que aconteceu). Vai só o resumo
/// agregado da corrida (`ResumoTreinoIA`): nunca rota, coordenadas, horário ou dados do Saúde.
enum AnaliseTreinoIA {
    static let modelo = ClienteClaude.opus

    /// US$ por milhão de tokens (entrada, saída), da tabela da Anthropic em novembro de 2026.
    static func precos(_ modelo: String) -> (entrada: Double, saida: Double)? {
        if modelo.contains("opus-5-5") { return (4, 20) }
        if modelo.contains("sonnet-5-5") { return (2, 10) }
        return nil
    }

    @MainActor
    static func analisar(_ corrida: Corrida, em contexto: ModelContext) async throws -> AnaliseSalva {
        let resumo = resumo(da: corrida, em: contexto)
        let salva: AnaliseSalva
        if ClienteClaude.simulado {
            try await Task.sleep(for: .seconds(1))
            salva = AnaliseSalva(analise: simulada(resumo), uso: nil, data: .now, simulada: true)
        } else {
            let corpo = try ClienteClaude.corpo(
                modelo: modelo, sistema: instrucoes,
                mensagens: [.init(papel: "user", texto: L(
                    "Analise o treino que acabei de fazer (dados agregados; tempos em min:s, pace em min/km, batimentos em bpm, esforço de 1 a 10):\n\n",
                    "Analyze the workout I just did (aggregated data; times in min:s, pace in min/km, heart rate in bpm, effort from 1 to 10):\n\n"
                ) + (try resumo.json()))],
                esquema: esquema, effort: "medium"
            )
            let dados = try await ClienteClaude.enviarBruto(corpo, modelo: modelo)
            let analise = try JSONDecoder().decode(AnaliseTreino.self, from: try ClienteClaude.texto(dados))
            salva = AnaliseSalva(analise: analise, uso: uso(dados), data: .now, simulada: false)
        }
        corrida.analiseIA = try JSONEncoder().encode(salva)
        try? contexto.save()
        return salva
    }

    // MARK: Uso e custo

    private struct RespostaUso: Decodable {
        struct Uso: Decodable {
            let inputTokens: Int
            let outputTokens: Int
            let cacheCreationInputTokens: Int?
            let cacheReadInputTokens: Int?
        }

        struct Bloco: Decodable { let type: String }

        let model: String?
        let usage: Uso?
        let content: [Bloco]
    }

    static func uso(_ dados: Data) -> UsoIA? {
        let decodificador = JSONDecoder()
        decodificador.keyDecodingStrategy = .convertFromSnakeCase
        guard let r = try? decodificador.decode(RespostaUso.self, from: dados), let u = r.usage else { return nil }
        let modelo = r.model ?? Self.modelo
        let entrada = u.inputTokens + (u.cacheCreationInputTokens ?? 0) + (u.cacheReadInputTokens ?? 0)
        let custo = precos(modelo).map { (Double(entrada) * $0.entrada + Double(u.outputTokens) * $0.saida) / 1_000_000 }
        return UsoIA(modelo: modelo, entrada: entrada, saida: u.outputTokens, custoUSD: custo,
                     comFallback: r.content.contains { $0.type == "fallback" })
    }

    // MARK: Pedido

    /// O resumo agregado: etapas (ou parciais na corrida livre), batimentos, esforço, o contexto do
    /// plano e o último treino com o mesmo nome.
    @MainActor
    static func resumo(da corrida: Corrida, em contexto: ModelContext) -> ResumoTreinoIA {
        let resultados = corrida.carregarResultados()
        let parciais = corrida.esteira ? [] : Parciais.calcular(corrida.carregarAmostras())
        let agenda = (try? contexto.fetch(FetchDescriptor<PlanoAtivo>()))?.first?.agenda

        var plano: String?
        if let numero = corrida.planoSemana, let agenda, let semana = agenda.plano.semanas.first(where: { $0.numero == numero }) {
            let total = agenda.plano.semanas.count
            plano = agenda.plano.entrada.objetivo.nome
                + L(", semana \(numero) de \(total), fase ", ", week \(numero) of \(total), ") + semana.fase.nome
                + (semana.alivio ? L(", semana de alívio", ", recovery week") : "")
        }

        let idade = UserDefaults.standard.integer(forKey: Preferencias.idade)
        let fcMaxima = ZonasDoUsuario.fcMaxima()
        let corredor = ResumoTreinoIA.Corredor(
            nivel: agenda?.plano.entrada.nivel.nome,
            idade: (10...100).contains(idade) ? idade : nil,
            fcMaxima: fcMaxima.map { Int($0.valor.rounded()) },
            fcMaximaMedida: fcMaxima.map { !$0.estimada },
            vdot: ZonasDoUsuario.atuais().map { ($0.vdot * 10).rounded() / 10 }
        )

        return ResumoTreinoIA(
            treino: corrida.titulo, plano: plano, esteira: corrida.esteira, corredor: corredor, esforco: corrida.esforcoPercebido,
            resultados: resultados, fc: corrida.carregarFC(), inicioCorrida: corrida.inicio, parciais: parciais,
            distancia: corrida.distanciaMetros, tempoEmMovimento: corrida.duracaoEmMovimento, tempoTotal: corrida.duracaoTotal,
            subida: corrida.subidaMetros, anterior: resultados.isEmpty ? nil : anterior(a: corrida, em: contexto)
        )
    }

    /// O último treino com o mesmo nome, feito antes deste (só treinos por etapas).
    @MainActor
    private static func anterior(a corrida: Corrida, em contexto: ModelContext) -> ResumoTreinoIA.Anterior? {
        let titulo = corrida.titulo
        let inicio = corrida.inicio
        var descritor = FetchDescriptor<Corrida>(
            predicate: #Predicate { $0.titulo == titulo && $0.inicio < inicio && !$0.simulada && !$0.exemplo },
            sortBy: [SortDescriptor(\.inicio, order: .reverse)]
        )
        descritor.fetchLimit = 5
        guard let antes = (try? contexto.fetch(descritor))?.first(where: { $0.blocos != nil }) else { return nil }
        let dias = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: antes.inicio),
                                                   to: Calendar.current.startOfDay(for: inicio)).day ?? 0
        return ResumoTreinoIA.Anterior(diasAtras: max(0, dias), nome: antes.titulo,
                                       trechosPrincipais: ResumoTreinoIA.trechosPrincipais(antes.carregarResultados()),
                                       esforcoPercebido: antes.esforcoPercebido)
    }

    static var instrucoes: String {
        """
        Você é um treinador de corrida experiente comentando um treino que o seu atleta acabou de fazer. O atleta é um corredor amador que treina sozinho com o app CRUNNING. Você recebe só dados agregados: o planejado e o feito em cada etapa (ou as parciais de km numa corrida livre), batimentos por etapa quando há pulseira, esforço percebido (1 a 10), o contexto do plano e o último treino parecido.

        Faça:
        - Compare o feito com o planejado em cada etapa e no conjunto: ritmo de cada trecho contra a faixa-alvo, regularidade entre as repetições, recuperações, aquecimento e desaquecimento. Numa corrida livre, olhe a regularidade das parciais e como começou e terminou.
        - Diga o que foi bem e o que fazer diferente, com o ajuste concreto para a próxima vez (tempo, pace ou duração quando couber).
        - Leve em conta o objetivo do treino e a fase do plano, quando vierem.
        - Se o treino foi bem executado, diga isso e não invente problema.

        Regras:
        - Use só os dados enviados. Não invente números, etapas, sensações nem condições. Cálculos simples a partir dos dados (diferenças, médias) são permitidos; confira cada conta.
        - Batimento alto em tiros curtos é esperado; só comente zona cardíaca onde o planejado pedir uma. Sem dados de batimento, não fale de batimento.
        - Não atribua o resultado a calor, sono, alimentação ou outro fator que os dados não mostrem.
        - Não dê conselho médico nem diagnóstico.
        - Seja breve: o texto aparece num cartão do app. Resumo com até 2 frases; no máximo 3 positivos e 3 ajustes.
        - Escreva em \(Idioma.atual == .ingles ? "inglês (English)" : "português do Brasil"), de forma direta, como um treinador falando com o atleta (trate por "você").
        """
    }

    static var esquema: [String: Any] {
        let texto: [String: Any] = ["type": "string"]
        return [
            "type": "object",
            "properties": [
                "execucao": ["type": "string", "enum": ["boa", "aceitavel", "fora_do_plano"]],
                "resumo": texto,
                "positivos": ["type": "array", "items": texto],
                "ajustes": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": ["o_que_aconteceu": texto, "como_fazer": texto],
                        "required": ["o_que_aconteceu", "como_fazer"],
                        "additionalProperties": false,
                    ],
                ],
                "proxima_vez": texto,
            ],
            "required": ["execucao", "resumo", "positivos", "ajustes", "proxima_vez"],
            "additionalProperties": false,
        ]
    }

    /// Resposta fictícia para testar a tela sem gastar a API (modo de desenvolvimento).
    static func simulada(_ resumo: ResumoTreinoIA) -> AnaliseTreino {
        AnaliseTreino(
            execucao: "aceitavel",
            resumo: L("(Simulado) Você fez \(resumo.etapas.count) etapas e \(Formatador.numero(resumo.totais.distanciaKm, casas: 2)) km. Esta é uma resposta de teste, sem a API.",
                      "(Simulated) You did \(resumo.etapas.count) steps and \(Formatador.numero(resumo.totais.distanciaKm, casas: 2)) km. This is a test reply, without the API."),
            positivos: [L("Aquecimento completo.", "Full warm-up.")],
            ajustes: [.init(oQueAconteceu: L("Os primeiros tiros saíram rápidos demais.", "The first reps were too fast."),
                            comoFazer: L("Mire o meio da faixa desde o primeiro.", "Aim for the middle of the range from the first one."))],
            proximaVez: L("Comece no ritmo-alvo e mantenha até o fim.", "Start at target pace and hold it to the end.")
        )
    }
}
