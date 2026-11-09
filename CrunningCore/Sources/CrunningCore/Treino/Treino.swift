import Foundation

/// Quanto dura um passo: por tempo ou por distância.
public enum Medida: Codable, Sendable, Equatable, Hashable {
    case tempo(TimeInterval)
    case distancia(Double)
}

public enum FuncaoPasso: String, Codable, Sendable {
    case aquecimento
    case trabalho
    case recuperacao
    case desaquecimento
}

/// Um trecho do treino: função, quanto dura e em que intensidade.
public struct Passo: Codable, Sendable, Equatable {
    public var funcao: FuncaoPasso
    public var medida: Medida
    public var intensidade: Intensidade

    public init(_ funcao: FuncaoPasso, _ medida: Medida, _ intensidade: Intensidade) {
        self.funcao = funcao
        self.medida = medida
        self.intensidade = intensidade
    }

    /// Duração e distância estimadas com as zonas (o alvo da faixa de ritmo).
    /// Num trecho `.prova` por distância, o ritmo é o previsto para aquela distância.
    public func estimativa(zonas: Zonas) -> (duracao: TimeInterval, distancia: Double) {
        let distanciaProva: Double?
        switch medida {
        case let .distancia(d): distanciaProva = d
        case .tempo: distanciaProva = nil
        }
        let ritmo = zonas.faixa(intensidade, distanciaProva: distanciaProva).alvo
        switch medida {
        case let .tempo(t): return (t, t / ritmo * 1000)
        case let .distancia(d): return (d / 1000 * ritmo, d)
        }
    }
}

/// Um bloco da linha do tempo: um passo solto ou um grupo repetido ("6 x").
public enum Bloco: Codable, Sendable, Equatable {
    case passo(Passo)
    case repetir(vezes: Int, passos: [Passo])
}

/// Um treino completo, pronto para a linha do tempo e para a execução por blocos.
public struct Treino: Codable, Sendable, Equatable {
    public var nome: String
    public var tipo: TipoTreino
    public var blocos: [Bloco]
    /// Modelo que gerou o treino e a dose usada (para trocar ou reduzir sem perder a origem).
    public var modeloID: String?
    public var dose: Double?

    public init(nome: String, tipo: TipoTreino, blocos: [Bloco], modeloID: String? = nil, dose: Double? = nil) {
        self.nome = nome
        self.tipo = tipo
        self.blocos = blocos
        self.modeloID = modeloID
        self.dose = dose
    }

    /// Todos os passos em ordem, com as repetições abertas.
    public var passosExpandidos: [Passo] {
        blocos.flatMap { bloco -> [Passo] in
            switch bloco {
            case let .passo(p): [p]
            case let .repetir(vezes, passos): Array(repeating: passos, count: max(0, vezes)).flatMap { $0 }
            }
        }
    }

    public func duracaoEstimada(zonas: Zonas) -> TimeInterval {
        passosExpandidos.reduce(0) { $0 + $1.estimativa(zonas: zonas).duracao }
    }

    public func distanciaEstimada(zonas: Zonas) -> Double {
        passosExpandidos.reduce(0) { $0 + $1.estimativa(zonas: zonas).distancia }
    }

    /// Distância estimada nos trechos de trabalho de uma intensidade.
    public func distanciaDeTrabalho(em intensidade: Intensidade, zonas: Zonas) -> Double {
        passosExpandidos
            .filter { $0.funcao == .trabalho && $0.intensidade == intensidade }
            .reduce(0) { $0 + $1.estimativa(zonas: zonas).distancia }
    }

    /// Distância estimada em qualquer intensidade de qualidade (exceto ritmo de prova no dia da prova).
    public func distanciaDeQualidade(zonas: Zonas) -> Double {
        guard tipo != .prova else { return 0 }
        return passosExpandidos
            .filter { $0.intensidade.ehQualidade }
            .reduce(0) { $0 + $1.estimativa(zonas: zonas).distancia }
    }
}
