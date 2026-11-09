import Foundation

/// Números das travas do plano. Cada um tem fonte (ou "prática de treinadores") em docs/CIENCIA.md.
public enum RegrasPlano {
    // MARK: Progressão (CIENCIA: "Progressão de carga e longão")

    public static let tetoProgressaoPadrao = 0.10
    public static let tetoProgressaoMaximo = 0.20
    public static let tetoProgressaoMinimo = 0.05
    /// Nenhuma semana sobe mais que isto em relação à anterior, nem na volta de um alívio ou de uma pausa.
    public static let saltoMaximoSemanal = 0.25
    /// Semanas olhadas para o teto de progressão.
    public static let janelaTeto = 3
    /// Nenhuma corrida passa 110% da maior das 4 semanas anteriores.
    public static let picoMaximoCorrida = 1.10
    public static let janelaPico = 4
    /// Abaixo disto, o volume atual conta como este piso (escolha do app).
    public static let pisoVolumeReferencia = 10_000.0
    public static let pisoLongaoReferencia = 3_000.0

    // MARK: Alívio

    public static func aliviaACada(_ nivel: Nivel) -> Int { nivel == .iniciante ? 3 : 4 }
    public static let fatorAlivio = 0.80

    // MARK: Longão

    public static let duracaoMaximaCorrida: TimeInterval = 150 * 60

    /// Fração máxima do volume semanal para a maior corrida, conforme o número de corridas.
    public static func fracaoMaximaCorrida(corridas: Int, volume: Double) -> Double {
        switch corridas {
        case ...2: 0.55
        case 3: 0.40
        case 4: 0.35
        default: volume > 64_000 ? 0.25 : 0.30
        }
    }

    public static func tetoLongao(_ objetivo: Objetivo) -> Double {
        switch objetivo {
        case let .prova(d):
            switch d {
            case ..<7_000: 12_000
            case ..<15_000: 16_000
            case ..<30_000: 20_000
            default: 32_000
            }
        case .condicionamento: 16_000
        case .comecarACorrer: 6_000
        }
    }

    // MARK: Corridas e qualidade (CIENCIA: "Treinos de qualidade")

    public static func maximoCorridas(_ nivel: Nivel) -> Int {
        switch nivel {
        case .iniciante: 4
        case .intermediario: 5
        case .avancado: 6
        }
    }

    public static func maximoQualidade(_ nivel: Nivel) -> Int { nivel == .iniciante ? 1 : 2 }

    /// Teto de distância de trabalho por sessão, dado o volume da semana.
    public static func limiteTrabalho(_ intensidade: Intensidade, volumeSemana v: Double) -> Double {
        switch intensidade {
        case .limiar: 0.10 * v
        case .intervalado: min(0.08 * v, 10_000)
        case .repeticoes: min(0.05 * v, 8_000)
        case .maratona: min(0.20 * v, 16_000)
        case .caminhada, .facil, .prova: .infinity
        }
    }

    /// No máximo 20% do volume da semana em qualidade (CIENCIA: "Distribuição de intensidade").
    public static let fracaoMaximaQualidade = 0.20
    /// Corrida fácil mais curta que vale a pena marcar.
    public static let corridaMinima = 2_000.0

    // MARK: Polimento (CIENCIA: "Polimento e periodização")

    public static func semanasPolimento(_ distancia: Double) -> Int {
        switch distancia {
        case ..<15_000: 1
        case ..<30_000: 2
        default: 3
        }
    }

    /// Volume de cada semana do polimento em relação ao pico (a última é a da prova).
    public static func fatoresPolimento(_ semanas: Int) -> [Double] {
        switch semanas {
        case ...1: [0.50]
        case 2: [0.70, 0.50]
        default: [0.80, 0.62, 0.48]
        }
    }

    // MARK: Começar a correr (CIENCIA: "Iniciante")

    /// (corrida, caminhada, ciclos) por semana: a corrida total sobe até 30 minutos contínuos.
    public static let progressaoCaminhadaCorrida: [(correr: TimeInterval, caminhar: TimeInterval, ciclos: Int)] = [
        (60, 90, 8),     //  8 min de corrida
        (90, 90, 6),     //  9 min
        (120, 90, 5),    // 10 min
        (180, 90, 4),    // 12 min
        (300, 120, 3),   // 15 min
        (480, 120, 2),   // 16 min
        (600, 90, 2),    // 20 min
        (720, 60, 2),    // 24 min
        (1800, 0, 1),    // 30 min contínuos
    ]
}
