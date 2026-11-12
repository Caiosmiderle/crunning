import Foundation
import Testing
@testable import CrunningCore

@Suite("Rota da imagem de compartilhar")
struct RotaCompartilhadaTests {
    /// Reta para o norte, 1 ponto a cada 10 m, a partir de um lugar fictício no oceano.
    static func reta(metros: Int, seg: (Int) -> Int = { _ in 0 }) -> [AmostraTrilha] {
        (0...(metros / 10)).map { i in
            AmostraTrilha(t: Double(i * 3), lat: -10 + Double(i * 10) / 111_195, lon: -30, alt: nil,
                          d: Double(i * 10), mov: Double(i * 3), seg: seg(i))
        }
    }

    @Test func apararTiraComecoEFim() {
        let a = RotaCompartilhada.aparar(Self.reta(metros: 1000), metros: 200)
        #expect(a.first?.d == 200)
        #expect(a.last?.d == 800)
        // Corrida curta demais: nada de rota.
        #expect(RotaCompartilhada.aparar(Self.reta(metros: 500), metros: 200).isEmpty)
        // Sem aparo: tudo.
        #expect(RotaCompartilhada.aparar(Self.reta(metros: 500), metros: 0).count == 51)
    }

    @Test func formaCabeNoQuadradoSemDistorcer() throws {
        let f = RotaCompartilhada.forma(Self.reta(metros: 1000))
        #expect(f.count == 1)
        let traco = try #require(f.first)
        // Reta norte-sul: x fica no meio, y vai de 1 (sul, embaixo) a 0 (norte, em cima).
        #expect(traco.allSatisfy { abs($0.x - 0.5) < 1e-9 })
        #expect(abs((traco.first?.y ?? 0) - 1) < 1e-9)
        #expect(abs(traco.last?.y ?? 1) < 1e-9)
    }

    @Test func pausaQuebraOTracoELimitaPontos() {
        let amostras = Self.reta(metros: 2000) { $0 < 100 ? 0 : 1 }
        let f = RotaCompartilhada.forma(amostras, maximoPontos: 50)
        #expect(f.count == 2)
        #expect(f.reduce(0) { $0 + $1.count } <= 60)
        #expect(RotaCompartilhada.forma(Array(amostras.prefix(1))).isEmpty)
    }
}
