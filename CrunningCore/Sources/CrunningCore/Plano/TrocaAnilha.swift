import Foundation

/// Troca com o Anilha (app de musculação do Caio), versão 1. O contrato completo mora no
/// repositório do Anilha, em docs/CONTRATO_TROCA_CRUNNING.md. Só resumos: nunca rota, GPS,
/// coordenadas, batimentos, nome ou texto livre. Unidades em metros e segundos.
public enum TrocaAnilha {
    public static let versao = 1
    /// Até quantos dias à frente vão os treinos planejados.
    public static let diasPlanejados = 14

    // MARK: Tipos

    /// `RunType` do Anilha: leve, longo ou intervalado.
    public static func tipo(_ t: TipoTreino?) -> String {
        switch t {
        case .longao: "longo"
        case .intervalado, .repeticoes, .limiar, .ritmoProva, .prova: "intervalado"
        default: "leve"
        }
    }

    /// O tipo que define a corrida: a primeira etapa de qualidade; senão longão; senão nada
    /// (corrida livre ou só rodagem vira "leve").
    public static func tipoDominante(_ resultados: [ResultadoEtapa]) -> TipoTreino? {
        let etapas = resultados.filter { !$0.ehExercicio }
        if let q = etapas.first(where: { $0.tipo.ehQualidade || $0.tipo == .prova }) { return q.tipo }
        if etapas.contains(where: { $0.tipo == .longao }) { return .longao }
        return etapas.first?.tipo
    }

    // MARK: Formatos

    public static func instante(_ data: Date, calendario: Calendar = CalendarioTreino.padrao()) -> String {
        let f = ISO8601DateFormatter()
        f.timeZone = calendario.timeZone
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: data)
    }

    public static func dataLocal(_ data: Date, calendario: Calendar = CalendarioTreino.padrao()) -> String {
        let c = calendario.dateComponents([.year, .month, .day], from: data)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: CRUNNING → Anilha: corridas feitas

    public struct Planejado: Codable, Sendable, Equatable {
        public var semana: Int
        public var dia: Int
    }

    public struct ItemCorrida: Codable, Sendable, Equatable {
        public var origemID: String
        public var atualizadoEm: String
        public var apagado: Bool
        public var inicio: String?
        public var dataLocal: String?
        public var tipo: String?
        public var tipoOrigem: String?
        public var distanciaM: Double?
        public var duracaoMovimentoS: Int?
        public var esforco: Int?
        public var esteira: Bool?
        public var planejado: Planejado?
        public var stravaID: String?

        enum CodingKeys: String, CodingKey {
            case origemID = "origem_id", atualizadoEm = "atualizado_em", apagado, inicio
            case dataLocal = "data_local", tipo, tipoOrigem = "tipo_origem", distanciaM = "distancia_m"
            case duracaoMovimentoS = "duracao_movimento_s", esforco, esteira, planejado, stravaID = "strava_id"
        }
    }

    public struct LoteCorridas: Codable, Sendable, Equatable {
        public var versao: Int
        public var itens: [ItemCorrida]

        public init(versao: Int = TrocaAnilha.versao, itens: [ItemCorrida]) {
            self.versao = versao
            self.itens = itens
        }
    }

    /// Item de uma corrida feita. Nil se o Anilha não aceitaria: distância de 5 m a 300 km e
    /// tempo em movimento de 1 s a 48 h (os limites da tabela de corridas dele).
    public static func corrida(
        codigo: String, inicio: Date, atualizadaEm: Date, distancia: Double, duracaoMovimento: TimeInterval,
        tipo t: TipoTreino?, esforco: Int?, esteira: Bool, planejado: (semana: Int, dia: Int)?,
        stravaID: Int64?, calendario: Calendar = CalendarioTreino.padrao()
    ) -> ItemCorrida? {
        let duracao = Int(duracaoMovimento.rounded())
        guard !codigo.isEmpty, distancia >= 5, distancia <= 300_000, duracao > 0, duracao <= 172_800 else { return nil }
        return ItemCorrida(
            origemID: codigo, atualizadoEm: instante(atualizadaEm, calendario: calendario), apagado: false,
            inicio: instante(inicio, calendario: calendario), dataLocal: dataLocal(inicio, calendario: calendario),
            tipo: tipo(t), tipoOrigem: t?.rawValue, distanciaM: (distancia * 10).rounded() / 10,
            duracaoMovimentoS: duracao, esforco: esforco.flatMap { (1...10).contains($0) ? $0 : nil },
            esteira: esteira, planejado: planejado.map { Planejado(semana: $0.semana, dia: $0.dia) },
            stravaID: stravaID.map { String($0) }
        )
    }

    /// Lápide de uma corrida apagada no CRUNNING.
    public static func apagada(codigo: String, em data: Date, calendario: Calendar = CalendarioTreino.padrao()) -> ItemCorrida {
        ItemCorrida(origemID: codigo, atualizadoEm: instante(data, calendario: calendario), apagado: true)
    }

    // MARK: CRUNNING → Anilha: treinos planejados

    public struct ItemPlanejado: Codable, Sendable, Equatable {
        public var origemID: String
        public var dataLocal: String
        public var tipo: String
        public var tipoOrigem: String?
        public var nome: String
        public var distanciaM: Double?
        public var duracaoS: Int?
        public var importante: Bool
        public var status: String

        enum CodingKeys: String, CodingKey {
            case origemID = "origem_id", dataLocal = "data_local", tipo, tipoOrigem = "tipo_origem", nome
            case distanciaM = "distancia_m", duracaoS = "duracao_s", importante, status
        }
    }

    public struct LotePlanejados: Codable, Sendable, Equatable {
        public var versao: Int
        public var de: String
        public var ate: String
        public var itens: [ItemPlanejado]
    }

    /// Os treinos do plano de hoje até `dias - 1` dias à frente (a janela que o Anilha substitui).
    public static func planejados(_ agenda: AgendaPlano, hoje: Date, dias: Int = diasPlanejados,
                                  calendario: Calendar = CalendarioTreino.padrao()) -> LotePlanejados {
        let comeco = calendario.startOfDay(for: hoje)
        let fim = calendario.date(byAdding: .day, value: max(1, dias) - 1, to: comeco) ?? comeco
        let inicioPlano = dataLocal(agenda.inicio, calendario: calendario)
        var itens: [ItemPlanejado] = []
        for d in 0..<max(1, dias) {
            guard let data = calendario.date(byAdding: .day, value: d, to: comeco),
                  let p = agenda.posicao(de: data, calendario: calendario),
                  let sessao = agenda.sessao(semana: p.semana, dia: p.dia) else { continue }
            let t = sessao.treino.tipo
            let status: String = switch agenda.status(semana: p.semana, dia: p.dia) {
            case .planejada: "planejada"
            case .feita: "feita"
            case .perdida: "perdida"
            }
            itens.append(ItemPlanejado(
                origemID: "plano:\(inicioPlano):\(p.semana)-\(p.dia)", dataLocal: dataLocal(data, calendario: calendario),
                tipo: tipo(t), tipoOrigem: t.rawValue, nome: String(sessao.treino.nome.prefix(60)),
                distanciaM: sessao.distancia > 0 ? (sessao.distancia * 10).rounded() / 10 : nil,
                duracaoS: sessao.duracao > 0 ? Int(sessao.duracao.rounded()) : nil,
                importante: sessao.ehForte || sessao.ehProva, status: status
            ))
        }
        return LotePlanejados(versao: versao, de: dataLocal(comeco, calendario: calendario),
                              ate: dataLocal(fim, calendario: calendario), itens: itens)
    }

    // MARK: Respostas

    public struct Rejeitado: Codable, Sendable, Equatable {
        public var origemID: String
        public var motivo: String

        enum CodingKeys: String, CodingKey {
            case origemID = "origem_id", motivo
        }
    }

    public struct RespostaCorridas: Codable, Sendable, Equatable {
        public var versao: Int
        public var aceitos: Int
        public var ignorados: Int
        public var rejeitados: [Rejeitado]
    }

    public struct RespostaPlanejados: Codable, Sendable, Equatable {
        public var versao: Int
        public var gravados: Int
        public var apagados: Int
    }

    public static func codificar<T: Encodable>(_ valor: T) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try e.encode(valor)
    }
}
