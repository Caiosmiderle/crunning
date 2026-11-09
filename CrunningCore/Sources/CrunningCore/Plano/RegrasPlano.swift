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

    /// O volume sobe em rampa e chega ao pico nesta fração das semanas antes do polimento (escolha do app).
    public static let fracaoSemanasAtePico = 0.75

    // MARK: Alívio

    public static func aliviaACada(_ nivel: Nivel) -> Int { nivel == .iniciante ? 3 : 4 }
    public static let fatorAlivio = 0.80

    // MARK: Longão

    /// 150 minutos (Daniels); na maratona, 180 (planos de maratona passam disso com longões de 30 km).
    public static func duracaoMaximaCorrida(_ objetivo: Objetivo) -> TimeInterval {
        (objetivo.distanciaProva ?? 0) >= 30_000 ? 180 * 60 : 150 * 60
    }

    /// Fração máxima do volume semanal para a maior corrida, conforme o número de corridas.
    /// Daniels (25% a 30%) nas provas curtas e sem prova; na meia e na maratona, a faixa
    /// mais alta usada por planos de maratona (prática de treinadores, ver CIENCIA.md).
    public static func fracaoMaximaCorrida(corridas: Int, volume: Double, objetivo: Objetivo) -> Double {
        let distancia = objetivo.distanciaProva ?? 0
        if distancia >= 30_000 {
            switch corridas {
            case ...2: return 0.55
            case 3: return 0.48
            case 4: return 0.42
            default: return 0.38
            }
        }
        if distancia >= 15_000 {
            switch corridas {
            case ...2: return 0.55
            case 3: return 0.43
            case 4: return 0.38
            default: return 0.33
            }
        }
        switch corridas {
        case ...2: return 0.55
        case 3: return 0.40
        case 4: return 0.35
        default: return volume > 64_000 ? 0.25 : 0.30
        }
    }

    /// Fração do volume semanal que o longão busca, conforme o número de corridas (escolha do app,
    /// dentro do teto acima): com ela, o longão fica cerca de 30% maior que as outras corridas.
    public static func fracaoLongaoAlvo(corridas: Int) -> Double {
        switch corridas {
        case ...2: 0.50
        case 3: 0.39
        case 4: 0.31
        case 5: 0.27
        default: 0.24
        }
    }

    /// As outras corridas da semana ficam abaixo do longão: fáceis até 80% dele, qualidade até 85%.
    /// Com 3 corridas, 80% é o que deixa o longão dentro do teto de 40% do volume sem a semana encolher.
    public static let fracaoFacilDoLongao = 0.80
    public static let fracaoQualidadeDoLongao = 0.85
    /// Folga do validador para "nenhuma corrida maior que o longão" (arredondamento de 100 m).
    public static let fracaoMaximaDoLongao = 0.90

    // MARK: Corridas fáceis (escolha do app, prática de treinadores)

    /// Corrida fácil mais curta que o gerador marca quando sobra volume (os dias livres são todos usados).
    public static let duracaoMinimaFacil: TimeInterval = 20 * 60
    /// A recuperação depois de um dia forte é curta e leve.
    public static let duracaoMaximaRecuperacao: TimeInterval = 50 * 60
    public static let pesoRecuperacao = 0.80
    /// Trote a mais que o aquecimento e o desaquecimento de um treino de qualidade podem ganhar, cada um.
    public static let aquecimentoExtraMaximo = 1_500.0

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

    /// Polimento num plano de `total` semanas: nunca mais que um quarto do plano.
    public static func semanasPolimento(_ distancia: Double, totalSemanas total: Int) -> Int {
        min(semanasPolimento(distancia), max(1, total / 4), max(1, total))
    }

    // MARK: Viabilidade (CIENCIA: "Viabilidade do plano")

    /// Longão de pico recomendado para a prova (prática de treinadores).
    public static func longaoRecomendado(_ distancia: Double, nivel: Nivel) -> Double {
        let base: Double
        switch distancia {
        case ..<7_000: base = 8_000
        case ..<15_000: base = 12_000
        case ..<30_000: base = 18_000
        default: base = 26_000
        }
        return nivel == .iniciante ? base * 0.85 : base
    }

    /// Mínimo de semanas por distância (prática de treinadores); iniciante pede 50% a mais.
    public static func semanasMinimas(_ distancia: Double, nivel: Nivel) -> Int {
        let base: Int
        switch distancia {
        case ..<7_000: base = 4
        case ..<15_000: base = 6
        case ..<30_000: base = 8
        default: base = 12
        }
        return nivel == .iniciante ? Int((Double(base) * 1.5).rounded(.up)) : base
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
