import CrunningCore
import Foundation

/// Resposta estruturada da análise de um plano.
struct AnaliseIA: Decodable, Equatable {
    struct Ponto: Decodable, Equatable, Hashable {
        let gravidade: String
        let semanas: [Int]
        let problema: String
        let sugestao: String
    }

    let avaliacao: String
    let resumo: String
    let pontos: [Ponto]
    let positivos: [String]
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
        case .semChave: "Salve a sua chave da API em Ajustes > Coach de IA."
        case .chaveInvalida: "A chave da API foi recusada. Confira em Ajustes > Coach de IA."
        case let .semPermissao(m): "A chave não tem permissão para isso. \(m)"
        case .limite: "Limite de uso da API atingido. Tente de novo em alguns minutos."
        case let .pedidoInvalido(m): "A API recusou o pedido: \(m)"
        case let .servidor(codigo, m): "A API respondeu com erro \(codigo). \(m)"
        case let .recusa(categoria): "O modelo não quis analisar este pedido" + (categoria.map { " (\($0))." } ?? ".")
        case .respostaIncompleta: "A resposta veio cortada. Tente de novo."
        case .respostaInvalida: "A resposta veio num formato inesperado. Tente de novo."
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
                        ],
                        "required": ["gravidade", "semanas", "problema", "sugestao"],
                        "additionalProperties": false,
                    ],
                ],
                "positivos": ["type": "array", "items": ["type": "string"]],
            ],
            "required": ["avaliacao", "resumo", "pontos", "positivos"],
            "additionalProperties": false,
        ]
    }

    static let instrucoes = """
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
    - Escreva em português do Brasil, de forma direta, como um treinador falando com o atleta.
    """

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
                        Sessao(dia: Self.dias[dia], tipo: $0.tipo.nome, treino: $0.treino.nome, km: km($0.distancia),
                               minutos: Int(($0.duracao / 60).rounded()),
                               trabalhoDeQualidadeKm: $0.trabalhoDeQualidade > 0 ? km($0.trabalhoDeQualidade) : nil)
                    }
                }
            )
        }
    }
}
