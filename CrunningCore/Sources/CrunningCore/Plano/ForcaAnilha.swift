import Foundation

/// Treinos de força vindos do Anilha (`GET /forca`, contrato v1). Só o que o calendário precisa:
/// dia, nome da ficha, status e se teve perna. Nada de carga, série a série ou dado de saúde.
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

    enum CodingKeys: String, CodingKey {
        case origemID = "origem_id", atualizadoEm = "atualizado_em", apagado, dataLocal = "data_local"
        case inicio, fim, status, pernas, seriesPernas = "series_pernas", duracaoS = "duracao_s", nome
    }

    public init(origemID: String, atualizadoEm: String, apagado: Bool = false, dataLocal: String?,
                inicio: String? = nil, fim: String? = nil, status: String? = "concluida",
                pernas: Bool? = false, seriesPernas: Int? = 0, duracaoS: Int? = nil, nome: String?) {
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
    }
}

/// Força prevista pelo plano do Anilha nos próximos 14 dias.
public struct ForcaPlanejadaAnilha: Codable, Sendable, Equatable {
    public let dataLocal: String
    public let nome: String
    public let pernas: Bool
    /// `planejado`, `feito`, `pulado` ou `movido`.
    public let status: String

    enum CodingKeys: String, CodingKey { case dataLocal = "data_local", nome, pernas, status }

    public init(dataLocal: String, nome: String, pernas: Bool, status: String = "planejado") {
        self.dataLocal = dataLocal
        self.nome = nome
        self.pernas = pernas
        self.status = status
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

    public init() {
        cursor = nil
        feitas = [:]
        planejadas = []
    }

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
