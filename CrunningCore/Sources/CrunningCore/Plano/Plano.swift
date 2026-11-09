import Foundation

public enum Objetivo: Codable, Sendable, Hashable {
    case prova(distanciaMetros: Double)
    /// Sem prova: base e construção em ciclos com alívio.
    case condicionamento
    /// Caminhada e corrida até 30 minutos contínuos.
    case comecarACorrer

    public static let cincoK = Objetivo.prova(distanciaMetros: 5000)
    public static let dezK = Objetivo.prova(distanciaMetros: 10_000)
    public static let meia = Objetivo.prova(distanciaMetros: 21_097.5)
    public static let maratona = Objetivo.prova(distanciaMetros: 42_195)

    public var distanciaProva: Double? {
        if case let .prova(d) = self { return d }
        return nil
    }

    public var nome: String {
        switch self {
        case let .prova(d):
            switch d {
            case 42_000...: "Maratona"
            case 21_000..<42_000: "Meia maratona"
            default: "Prova de \(Formatador.numero(d / 1000, casas: d.truncatingRemainder(dividingBy: 1000) == 0 ? 0 : 1)) km"
            }
        case .condicionamento: "Condicionamento"
        case .comecarACorrer: "Começar a correr"
        }
    }
}

public enum Nivel: String, CaseIterable, Codable, Sendable, Identifiable {
    case iniciante
    case intermediario
    case avancado

    public var id: String { rawValue }

    public var nome: String {
        switch self {
        case .iniciante: "Iniciante"
        case .intermediario: "Intermediário"
        case .avancado: "Avançado"
        }
    }
}

public enum Fase: String, CaseIterable, Codable, Sendable {
    case adaptacao
    case base
    case construcao
    case especifica
    case polimento

    public var nome: String {
        switch self {
        case .adaptacao: "Adaptação"
        case .base: "Base"
        case .construcao: "Construção"
        case .especifica: "Específica"
        case .polimento: "Polimento"
        }
    }
}

/// O que o gerador precisa saber. Dias: 0 = segunda ... 6 = domingo.
public struct EntradaPlano: Codable, Sendable, Equatable {
    public var objetivo: Objetivo
    public var semanas: Int
    public var nivel: Nivel
    public var diasDisponiveis: Set<Int>
    public var diaLongao: Int
    /// Volume semanal atual (média das últimas semanas), em metros.
    public var volumeAtual: Double
    /// Maior corrida das últimas 4 semanas, em metros.
    public var longaoAtual: Double
    public var vdot: Double?
    /// Teto de aumento do volume semanal (0,05 a 0,20).
    public var tetoProgressao: Double

    public init(
        objetivo: Objetivo,
        semanas: Int,
        nivel: Nivel,
        diasDisponiveis: Set<Int>,
        diaLongao: Int,
        volumeAtual: Double,
        longaoAtual: Double,
        vdot: Double? = nil,
        tetoProgressao: Double = RegrasPlano.tetoProgressaoPadrao
    ) {
        self.objetivo = objetivo
        self.semanas = semanas
        self.nivel = nivel
        self.diasDisponiveis = diasDisponiveis
        self.diaLongao = diaLongao
        self.volumeAtual = volumeAtual
        self.longaoAtual = longaoAtual
        self.vdot = vdot
        self.tetoProgressao = tetoProgressao
    }
}

/// Um treino marcado num dia, com as estimativas já calculadas.
public struct SessaoPlanejada: Codable, Sendable, Equatable {
    public var treino: Treino
    public var distancia: Double
    public var duracao: TimeInterval
    /// Distância de trabalho por intensidade de qualidade (limiar, intervalado...).
    public var trabalho: [Intensidade: Double]

    public init(treino: Treino, zonas: Zonas) {
        self.treino = treino
        distancia = treino.distanciaEstimada(zonas: zonas)
        duracao = treino.duracaoEstimada(zonas: zonas)
        var porIntensidade: [Intensidade: Double] = [:]
        if treino.tipo != .prova {
            for intensidade in Intensidade.allCases where intensidade.ehQualidade {
                let d = treino.distanciaDeTrabalho(em: intensidade, zonas: zonas)
                if d > 0 { porIntensidade[intensidade] = d }
            }
        }
        trabalho = porIntensidade
    }

    public var tipo: TipoTreino { treino.tipo }
    public var ehProva: Bool { treino.tipo == .prova }
    /// Treino de qualidade da semana (a prova não entra na contagem).
    public var ehQualidade: Bool { treino.tipo.ehQualidade && !ehProva }
    /// Dia forte: qualidade, longão ou prova (não podem ficar em dias seguidos).
    public var ehForte: Bool { treino.tipo.ehQualidade || treino.tipo == .longao }
    public var trabalhoDeQualidade: Double { trabalho.values.reduce(0, +) }
}

public struct SemanaPlano: Codable, Sendable, Equatable {
    public var numero: Int
    public var fase: Fase
    public var alivio: Bool
    /// Sete posições, de segunda a domingo; nil = descanso.
    public var dias: [SessaoPlanejada?]

    public init(numero: Int, fase: Fase, alivio: Bool, dias: [SessaoPlanejada?]) {
        self.numero = numero
        self.fase = fase
        self.alivio = alivio
        self.dias = dias
    }

    public var sessoes: [SessaoPlanejada] { dias.compactMap { $0 } }
    /// Volume de treino (a prova fica de fora das travas de progressão).
    public var volumeTreino: Double { sessoes.filter { !$0.ehProva }.reduce(0) { $0 + $1.distancia } }
    public var volumeTotal: Double { sessoes.reduce(0) { $0 + $1.distancia } }
    public var maiorCorrida: Double { sessoes.filter { !$0.ehProva }.map(\.distancia).max() ?? 0 }
    public var corridas: Int { sessoes.filter { !$0.ehProva }.count }
    public var temProva: Bool { sessoes.contains(where: \.ehProva) }
}

public struct Plano: Codable, Sendable, Equatable {
    public var entrada: EntradaPlano
    public var semanas: [SemanaPlano]
    /// As regras aplicadas, para a tela "Por que este plano?".
    public var regras: [String]
    /// Semanas que ficaram no passado numa mudança de data de prova (não são refeitas
    /// e não precisam caber no polimento).
    public var semanasConcluidas: Int

    public init(entrada: EntradaPlano, semanas: [SemanaPlano], regras: [String], semanasConcluidas: Int = 0) {
        self.entrada = entrada
        self.semanas = semanas
        self.regras = regras
        self.semanasConcluidas = semanasConcluidas
    }

    public var zonas: Zonas {
        entrada.vdot.flatMap { Zonas(vdot: $0) } ?? Zonas.estimativaSemReferencia(entrada.nivel)
    }
}

/// Resposta de `GeradorPlano.viabilidade`.
public enum Viabilidade: Equatable, Sendable {
    case viavel
    case curto(semanasMinimas: Int, motivo: String)
    case naoRecomendado(motivo: String)
}
