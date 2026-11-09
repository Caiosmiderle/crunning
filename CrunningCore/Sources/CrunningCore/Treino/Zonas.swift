import Foundation

/// Equações de Daniels e Gilbert (1979): custo de oxigênio de uma velocidade e fração
/// do VO2máx sustentável por um tempo. Fontes e limites em docs/CIENCIA.md ("Ritmos").
public enum Daniels {
    /// Custo de oxigênio (mL/kg/min) de correr a `v` metros por minuto.
    public static func custoOxigenio(metrosPorMinuto v: Double) -> Double {
        -4.60 + 0.182258 * v + 0.000104 * v * v
    }

    /// Fração do VO2máx que se sustenta numa prova de `t` minutos.
    public static func fracaoSustentavel(minutos t: Double) -> Double {
        0.8 + 0.1894393 * exp(-0.012778 * t) + 0.2989558 * exp(-0.1932605 * t)
    }

    /// VDOT de uma prova. Nil fora da faixa em que o modelo faz sentido
    /// (800 m a 100 km, 2 min a 6 h, índice entre 15 e 90).
    public static func vdot(distanciaMetros d: Double, tempoSegundos s: Double) -> Double? {
        guard d >= 800, d <= 100_000, s >= 120, s <= 6 * 3600 else { return nil }
        let valor = vdotSemLimites(distanciaMetros: d, minutos: s / 60)
        return (15...90).contains(valor) ? valor : nil
    }

    static func vdotSemLimites(distanciaMetros d: Double, minutos t: Double) -> Double {
        custoOxigenio(metrosPorMinuto: d / t) / fracaoSustentavel(minutos: t)
    }

    /// Velocidade (m/min) cujo custo de oxigênio é `vo2` (raiz positiva da equação de custo).
    public static func velocidade(paraVO2 vo2: Double) -> Double {
        let a = 0.000104, b = 0.182258, c = -(4.60 + vo2)
        return (-b + (b * b - 4 * a * c).squareRoot()) / (2 * a)
    }

    /// Tempo previsto (s) para a distância: o tempo cujo VDOT é igual ao informado.
    public static func tempoPrevisto(distanciaMetros d: Double, vdot alvo: Double) -> Double {
        var rapido = d / 600   // 36 km/h: VDOT altíssimo
        var lento = d / 40     // 2,4 km/h: VDOT baixíssimo
        for _ in 0..<80 {
            let meio = (rapido + lento) / 2
            if vdotSemLimites(distanciaMetros: d, minutos: meio) > alvo { rapido = meio } else { lento = meio }
        }
        return (rapido + lento) / 2 * 60
    }
}

/// Projeção de Riegel (1981): só para comparação, porque é otimista na maratona
/// para corredores recreativos (Vickers e Vertosick, 2016).
public enum Riegel {
    public static let expoente = 1.06

    public static func tempo(referenciaSegundos t1: Double, distanciaReferencia d1: Double, distanciaAlvo d2: Double) -> Double {
        t1 * pow(d2 / d1, expoente)
    }
}

/// Intensidade de um trecho de treino. Com VDOT vira faixa de ritmo; sem ele,
/// vale o esforço percebido e o teste da fala.
public enum Intensidade: String, CaseIterable, Codable, Sendable, Identifiable {
    case caminhada
    case facil
    case maratona
    case limiar
    case intervalado
    case repeticoes
    /// Ritmo previsto para a distância da prova.
    case prova

    public var id: String { rawValue }

    public var nome: String {
        switch self {
        case .caminhada: "Caminhada"
        case .facil: "Fácil"
        case .maratona: "Ritmo de maratona"
        case .limiar: "Limiar"
        case .intervalado: "Intervalado"
        case .repeticoes: "Repetições"
        case .prova: "Ritmo de prova"
        }
    }

    /// Conta como trabalho de qualidade na distribuição de intensidade.
    public var ehQualidade: Bool {
        switch self {
        case .caminhada, .facil: false
        case .maratona, .limiar, .intervalado, .repeticoes, .prova: true
        }
    }

    /// Esforço percebido de referência (escala 0 a 10). A correspondência é escolha do app.
    public var esforco: ClosedRange<Int> {
        switch self {
        case .caminhada: 1...2
        case .facil: 2...4
        case .maratona: 4...6
        case .limiar: 6...7
        case .intervalado: 8...9
        case .repeticoes: 9...10
        case .prova: 7...9
        }
    }

    /// Teste da fala: como deve estar a conversa nessa intensidade.
    public var testeDaFala: String {
        switch self {
        case .caminhada: "Conversa normal."
        case .facil: "Dá para conversar em frases inteiras."
        case .maratona: "Frases inteiras, mas com esforço."
        case .limiar: "Só frases curtas."
        case .intervalado: "Poucas palavras de cada vez."
        case .repeticoes: "Não dá para falar."
        case .prova: "Depende da distância: frases curtas a poucas palavras."
        }
    }
}

/// Faixa de ritmo em segundos por km. `lento` é o maior número (mais devagar).
public struct FaixaRitmo: Codable, Sendable, Equatable {
    public var lento: Double
    public var rapido: Double
    public var alvo: Double

    public init(lento: Double, rapido: Double, alvo: Double) {
        self.lento = max(lento, rapido)
        self.rapido = min(lento, rapido)
        self.alvo = min(max(alvo, self.rapido), self.lento)
    }

    public func contem(_ segundosPorKm: Double) -> Bool {
        segundosPorKm <= lento && segundosPorKm >= rapido
    }
}

/// Zonas de ritmo a partir do VDOT. Frações em docs/CIENCIA.md ("Zonas de ritmo").
public struct Zonas: Codable, Sendable, Equatable {
    public let vdot: Double

    /// Frações do VDOT: (mais lenta, alvo, mais rápida).
    static let fracoes: [Intensidade: (lento: Double, alvo: Double, rapido: Double)] = [
        .facil: (0.59, 0.66, 0.74),
        .limiar: (0.83, 0.88, 0.88),
        .intervalado: (0.95, 0.975, 1.00),
        .repeticoes: (1.03, 1.05, 1.07),
    ]
    /// Folga (em velocidade) em volta do ritmo previsto de maratona e de prova.
    static let folgaRitmoPrevisto = 0.03
    /// Caminhada sem relação com o VDOT: de 4 a cerca de 6,7 km/h.
    public static let caminhada = FaixaRitmo(lento: 900, rapido: 540, alvo: 660)
    public static let distanciaMaratona = 42_195.0

    public init?(vdot: Double) {
        guard (15...90).contains(vdot) else { return nil }
        self.vdot = vdot
    }

    public init?(distanciaMetros: Double, tempoSegundos: Double) {
        guard let valor = Daniels.vdot(distanciaMetros: distanciaMetros, tempoSegundos: tempoSegundos) else { return nil }
        self.vdot = valor
    }

    /// VDOT só para estimar distâncias quando não há prova de referência (escolha do app).
    public static func estimativaSemReferencia(_ nivel: Nivel) -> Zonas {
        switch nivel {
        case .iniciante: Zonas(vdot: 30)!
        case .intermediario: Zonas(vdot: 40)!
        case .avancado: Zonas(vdot: 50)!
        }
    }

    public func tempoPrevisto(distanciaMetros d: Double) -> Double {
        Daniels.tempoPrevisto(distanciaMetros: d, vdot: vdot)
    }

    /// Faixa de ritmo da intensidade. Para `.prova`, informe a distância da prova.
    public func faixa(_ intensidade: Intensidade, distanciaProva: Double? = nil) -> FaixaRitmo {
        switch intensidade {
        case .caminhada:
            return Zonas.caminhada
        case .maratona:
            return faixaPrevista(distancia: Zonas.distanciaMaratona)
        case .prova:
            return faixaPrevista(distancia: distanciaProva ?? Zonas.distanciaMaratona)
        case .facil, .limiar, .intervalado, .repeticoes:
            let f = Zonas.fracoes[intensidade]!
            return FaixaRitmo(
                lento: ritmo(metrosPorMinuto: Daniels.velocidade(paraVO2: f.lento * vdot)),
                rapido: ritmo(metrosPorMinuto: Daniels.velocidade(paraVO2: f.rapido * vdot)),
                alvo: ritmo(metrosPorMinuto: Daniels.velocidade(paraVO2: f.alvo * vdot))
            )
        }
    }

    private func faixaPrevista(distancia: Double) -> FaixaRitmo {
        let alvo = tempoPrevisto(distanciaMetros: distancia) / distancia * 1000
        return FaixaRitmo(
            lento: alvo / (1 - Zonas.folgaRitmoPrevisto),
            rapido: alvo / (1 + Zonas.folgaRitmoPrevisto),
            alvo: alvo
        )
    }

    private func ritmo(metrosPorMinuto v: Double) -> Double { 60_000 / v }
}

/// Frequência cardíaca é opcional e só estimada (erro típico de cerca de 10 bpm).
public enum FrequenciaCardiaca {
    public static let erroTipicoBpm = 10.0

    /// Tanaka, Monahan e Seals (2001): 208 − 0,7 × idade.
    public static func maximaEstimada(idade: Int) -> Double {
        208 - 0.7 * Double(idade)
    }
}

/// Carga de uma sessão pelo esforço percebido (Foster e colegas, 2001).
public enum CargaTreino {
    public static func sessao(esforco: Int, minutos: Double) -> Double {
        Double(min(max(esforco, 0), 10)) * max(0, minutos)
    }
}
