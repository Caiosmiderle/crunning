import Foundation

/// Faixas dos eixos dos gráficos da corrida.
public enum EscalaGrafico {
    /// Faixa do eixo y que mostra os dados com uma folga de `folga` (fração da faixa) em cada
    /// lado. `vaoMinimo` impede que um terreno quase plano vire montanha. Com `cortarPicosAltos`,
    /// o topo para no percentil 95 mais metade da faixa central, para uma parada (ritmo de
    /// caminhada) não achatar o resto do gráfico; o pico sai cortado.
    public static func dominio(_ valores: [Double], folga: Double = 0.08, vaoMinimo: Double = 0,
                               cortarPicosAltos: Bool = false) -> ClosedRange<Double>? {
        let v = valores.filter(\.isFinite).sorted()
        guard let menor = v.first, var maior = v.last else { return nil }
        if cortarPicosAltos, v.count >= 10 {
            let p5 = v[Int(Double(v.count - 1) * 0.05)]
            let p95 = v[Int(Double(v.count - 1) * 0.95)]
            maior = min(maior, p95 + max(p95 - p5, 1) * 0.5)
        }
        var baixo = menor - (maior - menor) * folga
        var alto = maior + (maior - menor) * folga
        let minimo = max(vaoMinimo, 1e-6)
        if alto - baixo < minimo {
            let meio = (alto + baixo) / 2
            baixo = meio - minimo / 2
            alto = meio + minimo / 2
        }
        return baixo...alto
    }

    /// Texto curto de um valor do eixo x: "2", "2,5".
    public static func rotuloX(_ valor: Double) -> String {
        let arredondado = (valor * 10).rounded() / 10
        if arredondado == arredondado.rounded() { return String(Int(arredondado)) }
        return String(format: "%.1f", arredondado).replacingOccurrences(of: ".", with: ",")
    }
}
