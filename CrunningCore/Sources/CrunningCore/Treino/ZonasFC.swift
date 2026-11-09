import Foundation

/// Zona de batimento de uma intensidade, em batimentos por minuto.
public struct ZonaFC: Equatable, Sendable {
    /// 1 a 5 (Z1 caminhada, Z2 fácil, Z3 maratona, Z4 limiar, Z5 intervalado).
    public let numero: Int
    /// Limite de baixo (nil em Z1: "até").
    public let minimo: Int?
    public let maximo: Int
    /// Frações da FC máxima que geraram a faixa.
    public let fracaoMinima: Double?
    public let fracaoMaxima: Double

    public var rotulo: String { "Z\(numero)" }

    /// "Z2 · 124–150 bpm" ou "Z1 · até 124 bpm".
    public var texto: String {
        if let minimo { return "\(rotulo) · \(minimo)–\(maximo) bpm" }
        return "\(rotulo) · até \(maximo) bpm"
    }

    public func contem(_ bpm: Int) -> Bool {
        bpm <= maximo && bpm >= (minimo ?? 0)
    }
}

extension FrequenciaCardiaca {
    /// Faixas em % da FC máxima por intensidade, de Daniels (*Daniels' Running Formula*, 4ª ed.,
    /// conferido em resumo secundário; docs/CIENCIA.md): fácil 65–79%, maratona 80–90%,
    /// limiar 88–92%, intervalado 98–100%. Repetições e ritmo de prova não têm faixa de batimento
    /// (curtos demais para o batimento estabilizar; vão pelo ritmo). Caminhada: abaixo do fácil.
    public static func fracoes(_ intensidade: Intensidade) -> (numero: Int, minima: Double?, maxima: Double)? {
        switch intensidade {
        case .caminhada: (1, nil, 0.65)
        case .facil: (2, 0.65, 0.79)
        case .maratona: (3, 0.80, 0.90)
        case .limiar: (4, 0.88, 0.92)
        case .intervalado: (5, 0.98, 1.0)
        case .repeticoes, .prova: nil
        }
    }

    /// Zona da intensidade para a FC máxima dada (nil sem faixa ou FC máxima fora do razoável).
    public static func zona(_ intensidade: Intensidade, fcMaxima: Double) -> ZonaFC? {
        guard (120...230).contains(fcMaxima), let f = fracoes(intensidade) else { return nil }
        // Arredondamento para fora: a faixa nunca fica mais estreita que a da tabela.
        let minimo = f.minima.map { Int(($0 * fcMaxima).rounded(.down)) }
        let maximo = Int((f.maxima * fcMaxima).rounded(.up))
        return ZonaFC(numero: f.numero, minimo: minimo, maximo: maximo, fracaoMinima: f.minima, fracaoMaxima: f.maxima)
    }
}
