import Foundation

/// Ajuste de ritmo pelo calor (docs/CIENCIA.md, "Calor").
///
/// - WBGT simplificado do Bureau of Meteorology da Austrália: 0,567·T + 0,393·e + 3,94, com a
///   pressão de vapor `e` em hPa. Ignora sol e vento; é uma aproximação conhecida por ter viés.
/// - Lentidão pelos quartis de WBGT de Ely e colegas (2007, MSSE 39:487): os mais rápidos ficaram
///   1,7%, 2,5%, 3,3% e 4,5% acima do recorde do percurso nos quartis de cerca de 5–10, 10–15,
///   15–20 e 20–25 °C de WBGT. O ajuste é a diferença para o quartil mais frio. Corredores mais
///   lentos perderam mais, então este é o mínimo: o esforço manda.
public enum Calor {
    public enum Avaliacao: Equatable, Sendable {
        case semAjuste
        /// Fração para deixar os ritmos mais lentos (0,016 = 1,6%).
        case ajuste(Double)
        /// Acima de 25 °C de WBGT: fora da faixa estudada.
        case foraDaFaixa
    }

    /// Pressão de vapor (hPa) pela temperatura (°C) e umidade relativa (%).
    public static func pressaoVapor(temperatura t: Double, umidade: Double) -> Double {
        min(max(umidade, 0), 100) / 100 * 6.105 * exp(17.27 * t / (237.7 + t))
    }

    public static func wbgtSimplificado(temperatura t: Double, umidade: Double) -> Double {
        0.567 * t + 0.393 * pressaoVapor(temperatura: t, umidade: umidade) + 3.94
    }

    public static func avaliar(wbgt: Double) -> Avaliacao {
        switch wbgt {
        case ..<10: .semAjuste
        case ..<15: .ajuste(0.008)
        case ..<20: .ajuste(0.016)
        case ...25: .ajuste(0.028)
        default: .foraDaFaixa
        }
    }

    /// Fração aplicada aos ritmos: na faixa estudada, a do quartil; acima dela, a maior estudada
    /// (sem extrapolar), com o aviso de ir pelo esforço.
    public static func fracao(_ a: Avaliacao) -> Double {
        switch a {
        case .semAjuste: 0
        case let .ajuste(f): f
        case .foraDaFaixa: 0.028
        }
    }

    public static func texto(_ a: Avaliacao) -> String {
        switch a {
        case .semAjuste: L("Sem ajuste: abaixo de 10 °C de WBGT.", "No adjustment: below 10 °C WBGT.")
        case let .ajuste(f):
            L("Ritmos \(Formatador.numero(f * 100, casas: 1))% mais lentos. É o mínimo medido em maratonistas rápidos; se o esforço subir, vá pelo esforço.",
              "Paces \(Formatador.numero(f * 100, casas: 1))% slower. This is the minimum measured in fast marathoners; if the effort rises, go by effort.")
        case .foraDaFaixa:
            L("Calor acima da faixa estudada (25 °C de WBGT): corra pelo esforço, encurte o treino forte, beba água e pare se sentir tontura, náusea ou calafrio.",
              "Heat above the studied range (25 °C WBGT): run by effort, shorten the hard workout, drink water and stop if you feel dizzy, nauseous or chilled.")
        }
    }

    public static func ajustar(_ f: FaixaRitmo, fracao: Double) -> FaixaRitmo {
        guard fracao > 0 else { return f }
        return FaixaRitmo(lento: f.lento * (1 + fracao), rapido: f.rapido * (1 + fracao), alvo: f.alvo * (1 + fracao))
    }
}
