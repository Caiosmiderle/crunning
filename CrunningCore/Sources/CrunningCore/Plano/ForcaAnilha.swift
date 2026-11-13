import Foundation

/// Detalhes locais do treino, usados apenas na tela de força, nunca nos resumos para IA.
public struct SerieAnilha: Codable, Sendable, Equatable {
    public let tipo: String
    public let cargaKg: Double?
    public let reps: Int?
    public let segundos: Int?

    enum CodingKeys: String, CodingKey { case tipo, cargaKg = "carga_kg", reps, segundos }

    public init(tipo: String = "trabalho", cargaKg: Double? = nil, reps: Int? = nil, segundos: Int? = nil) {
        self.tipo = tipo
        self.cargaKg = cargaKg
        self.reps = reps
        self.segundos = segundos
    }
}

public struct ExercicioFeitoAnilha: Codable, Sendable, Equatable {
    public let nome: String
    public let grupo: String?
    public let series: [SerieAnilha]

    public init(nome: String, grupo: String? = nil, series: [SerieAnilha] = []) {
        self.nome = nome
        self.grupo = grupo
        self.series = series
    }
}

public struct ExercicioPrevistoAnilha: Codable, Sendable, Equatable {
    public let nome: String
    public let grupo: String?
    public let series: Int
    public let repsMin: Int?
    public let repsMax: Int?

    enum CodingKeys: String, CodingKey { case nome, grupo, series, repsMin = "reps_min", repsMax = "reps_max" }

    public init(nome: String, grupo: String? = nil, series: Int = 0, repsMin: Int? = nil, repsMax: Int? = nil) {
        self.nome = nome
        self.grupo = grupo
        self.series = series
        self.repsMin = repsMin
        self.repsMax = repsMax
    }
}

/// Aceita apenas os destinos de treino e ficha do Anilha.
public enum LinkForcaAnilha {
    public static func url(_ link: String?) -> URL? {
        guard let link,
              link.hasPrefix("anilha://treino/") || link.hasPrefix("anilha://ficha/") else { return nil }
        return URL(string: link)
    }
}

/// Treinos de força vindos do Anilha (`GET /forca`, contrato v1), com detalhes opcionais.
public struct SessaoForcaAnilha: Codable, Sendable, Equatable, Identifiable {
    public var id: String { origemID }
    public let origemID: String
    public let atualizadoEm: String
    public let apagado: Bool
    public let dataLocal: String?
    public let inicio: String?
    public let fim: String?
    /// `concluida` ou `parcial`.
    public let status: String?
    public let pernas: Bool?
    public let seriesPernas: Int?
    public let duracaoS: Int?
    public let nome: String?
    public let link: String?
    public let exercicios: [ExercicioFeitoAnilha]?

    enum CodingKeys: String, CodingKey {
        case origemID = "origem_id", atualizadoEm = "atualizado_em", apagado, dataLocal = "data_local"
        case inicio, fim, status, pernas, seriesPernas = "series_pernas", duracaoS = "duracao_s", nome
        case link, exercicios
    }

    public init(origemID: String, atualizadoEm: String, apagado: Bool = false, dataLocal: String?,
                inicio: String? = nil, fim: String? = nil, status: String? = "concluida",
                pernas: Bool? = false, seriesPernas: Int? = 0, duracaoS: Int? = nil, nome: String?,
                link: String? = nil, exercicios: [ExercicioFeitoAnilha]? = nil) {
        self.origemID = origemID
        self.atualizadoEm = atualizadoEm
        self.apagado = apagado
        self.dataLocal = dataLocal
        self.inicio = inicio
        self.fim = fim
        self.status = status
        self.pernas = pernas
        self.seriesPernas = seriesPernas
        self.duracaoS = duracaoS
        self.nome = nome
        self.link = link
        self.exercicios = exercicios
    }
}

/// Força prevista pelo plano do Anilha nos próximos 14 dias.
public struct ForcaPlanejadaAnilha: Codable, Sendable, Equatable {
    public let dataLocal: String
    public let nome: String
    public let pernas: Bool
    /// `planejado`, `feito`, `pulado` ou `movido`.
    public let status: String
    public let fichaID: String?
    public let link: String?
    public let exercicios: [ExercicioPrevistoAnilha]?

    enum CodingKeys: String, CodingKey {
        case dataLocal = "data_local", nome, pernas, status, fichaID = "ficha_id", link, exercicios
    }

    public init(dataLocal: String, nome: String, pernas: Bool, status: String = "planejado",
                fichaID: String? = nil, link: String? = nil, exercicios: [ExercicioPrevistoAnilha]? = nil) {
        self.dataLocal = dataLocal
        self.nome = nome
        self.pernas = pernas
        self.status = status
        self.fichaID = fichaID
        self.link = link
        self.exercicios = exercicios
    }
}

public struct RespostaForcaAnilha: Decodable, Sendable {
    public let versao: Int
    public let cursor: String
    public let feitas: [SessaoForcaAnilha]
    public let planejadas: [ForcaPlanejadaAnilha]
}

/// O que o CRUNNING guarda do Anilha. As feitas chegam por cursor (só o que mudou) e valem pela
/// última edição; as lápides ficam guardadas para uma versão antiga não voltar. As planejadas
/// chegam inteiras a cada leitura e substituem as anteriores.
public struct EstadoForcaAnilha: Codable, Sendable, Equatable {
    public var cursor: String?
    public var feitas: [String: SessaoForcaAnilha]
    public var planejadas: [ForcaPlanejadaAnilha]
    /// 1 depois da primeira leitura com exercícios e séries. Estado salvo antes disso (nil) relê
    /// as duas últimas semanas inteiras uma vez, para os treinos já guardados ganharem o detalhe.
    public var versaoDetalhe: Int?

    public init() {
        cursor = nil
        feitas = [:]
        planejadas = []
        versaoDetalhe = nil
    }

    /// Cursor da próxima leitura: nenhum enquanto o detalhe ainda não foi lido.
    public var cursorParaLeitura: String? { versaoDetalhe == 1 ? cursor : nil }

    /// Aplica uma resposta. Versão desconhecida não muda nada.
    @discardableResult
    public mutating func aplicar(_ r: RespostaForcaAnilha) -> Bool {
        guard r.versao == 1 else { return false }
        for s in r.feitas {
            if let atual = feitas[s.origemID], Self.antes(s.atualizadoEm, atual.atualizadoEm) { continue }
            feitas[s.origemID] = s
        }
        planejadas = r.planejadas
        cursor = r.cursor
        versaoDetalhe = 1
        return true
    }

    /// Feitas (sem lápide) e previstas ainda abertas de um dia (`yyyy-MM-dd`, no fuso do aparelho).
    /// Previsão do dia some quando já há sessão feita nele.
    public func doDia(_ chave: String) -> (feitas: [SessaoForcaAnilha], planejadas: [ForcaPlanejadaAnilha]) {
        let f = feitas.values
            .filter { !$0.apagado && $0.dataLocal == chave }
            .sorted { ($0.inicio ?? "", $0.origemID) < ($1.inicio ?? "", $1.origemID) }
        let p = f.isEmpty ? planejadas.filter { $0.dataLocal == chave && $0.status == "planejado" } : []
        return (f, p)
    }

    /// `yyyy-MM-dd` de uma data no calendário dado (o mesmo formato de `data_local`).
    public static func chave(_ data: Date, calendario: Calendar) -> String {
        let c = calendario.dateComponents([.year, .month, .day], from: data)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// `a` é estritamente anterior a `b` (ISO 8601; se não der para ler, compara o texto).
    static func antes(_ a: String, _ b: String) -> Bool {
        if let da = instante(a), let db = instante(b) { return da < db }
        return a < b
    }

    static func instante(_ s: String) -> Date? {
        if let d = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(s) { return d }
        return try? Date.ISO8601FormatStyle().parse(s)
    }
}
