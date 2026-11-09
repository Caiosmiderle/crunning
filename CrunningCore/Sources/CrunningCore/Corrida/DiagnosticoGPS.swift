import Foundation

/// Como o GPS se comportou durante a corrida: quantos pontos chegaram com o app
/// na frente e em segundo plano, o maior buraco sem pontos e os avisos do iOS.
/// Não guarda coordenadas, só horários e contagens. Serve para provar (ou achar)
/// falhas de gravação com a tela bloqueada.
public struct DiagnosticoGPS: Codable, Sendable, Equatable {
    public enum Tipo: String, Codable, Sendable, CaseIterable {
        case segundoPlano
        case primeiroPlano
        case parado
        case semSinal
        case usoInsuficiente
        case precisaoReduzida
        case semPermissao
        /// O iOS fechou o app e ele foi reaberto (pelo sistema ou por você) no meio da corrida.
        case reaberto

        public var descricao: String {
            switch self {
            case .segundoPlano: "App em segundo plano"
            case .primeiroPlano: "App de volta na tela"
            case .parado: "iOS: aparelho parado"
            case .semSinal: "iOS: sem localização"
            case .usoInsuficiente: "iOS: app sem permissão de uso em segundo plano"
            case .precisaoReduzida: "iOS: localização aproximada"
            case .semPermissao: "iOS: sem permissão de localização"
            case .reaberto: "O iOS fechou o app; corrida retomada"
            }
        }

        /// Sinal de que algo atrapalhou a gravação.
        public var ehProblema: Bool {
            switch self {
            case .semSinal, .usoInsuficiente, .precisaoReduzida, .semPermissao, .reaberto: true
            case .segundoPlano, .primeiroPlano, .parado: false
            }
        }
    }

    public struct Evento: Codable, Sendable, Equatable {
        public var instante: Date
        public var tipo: Tipo

        public init(instante: Date, tipo: Tipo) {
            self.instante = instante
            self.tipo = tipo
        }
    }

    /// Buraco a partir do qual vale contar como falha.
    public static let intervaloLongo: TimeInterval = 15
    public static let maximoEventos = 300

    public private(set) var pontosPrimeiroPlano = 0
    public private(set) var pontosSegundoPlano = 0
    public private(set) var maiorIntervalo: TimeInterval = 0
    /// Quando começou o maior buraco sem pontos.
    public private(set) var inicioMaiorIntervalo: Date?
    public private(set) var intervalosLongos = 0
    public private(set) var eventos: [Evento] = []
    public private(set) var eventosDescartados = 0

    var ultimoPonto: Date?
    var pontoDesdeUltimoEvento = true

    public init() {}

    public var pontos: Int { pontosPrimeiroPlano + pontosSegundoPlano }

    public func quantas(_ tipo: Tipo) -> Int {
        eventos.filter { $0.tipo == tipo }.count
    }

    public var temProblema: Bool {
        maiorIntervalo >= Self.intervaloLongo || eventos.contains { $0.tipo.ehProblema }
    }

    public mutating func registrarPonto(em instante: Date, segundoPlano: Bool) {
        if segundoPlano { pontosSegundoPlano += 1 } else { pontosPrimeiroPlano += 1 }
        if let ultimoPonto {
            let intervalo = instante.timeIntervalSince(ultimoPonto)
            if intervalo > maiorIntervalo {
                maiorIntervalo = intervalo
                inicioMaiorIntervalo = ultimoPonto
            }
            if intervalo >= Self.intervaloLongo { intervalosLongos += 1 }
        }
        ultimoPonto = max(ultimoPonto ?? instante, instante)
        pontoDesdeUltimoEvento = true
    }

    /// Registra um aviso. O mesmo aviso repetido sem nenhum ponto no meio conta uma vez só
    /// (o iOS repete o mesmo sinal a cada atualização enquanto ele dura).
    public mutating func registrar(_ tipo: Tipo, em instante: Date) {
        if let ultimo = eventos.last, ultimo.tipo == tipo, !pontoDesdeUltimoEvento { return }
        pontoDesdeUltimoEvento = false
        guard eventos.count < Self.maximoEventos else {
            eventosDescartados += 1
            return
        }
        eventos.append(Evento(instante: instante, tipo: tipo))
    }
}
