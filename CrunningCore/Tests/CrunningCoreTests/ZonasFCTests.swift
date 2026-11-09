import Foundation
import Testing
@testable import CrunningCore

@Suite("Zonas de batimento")
struct ZonasFCTests {
    @Test func faixasDeDaniels() throws {
        // FC máxima 190: fácil 65–79% = 123,5–150,1 -> 123–151 (arredonda para fora).
        let facil = try #require(FrequenciaCardiaca.zona(.facil, fcMaxima: 190))
        #expect(facil.numero == 2 && facil.minimo == 123 && facil.maximo == 151)
        #expect(facil.texto == "Z2 · 123–151 bpm")
        let limiar = try #require(FrequenciaCardiaca.zona(.limiar, fcMaxima: 190))
        #expect(limiar.minimo == 167 && limiar.maximo == 175)
        let intervalado = try #require(FrequenciaCardiaca.zona(.intervalado, fcMaxima: 190))
        #expect(intervalado.minimo == 186 && intervalado.maximo == 190)
        let caminhada = try #require(FrequenciaCardiaca.zona(.caminhada, fcMaxima: 190))
        #expect(caminhada.minimo == nil && caminhada.texto == "Z1 · até 124 bpm")
    }

    @Test func semFaixaQuandoNaoFazSentido() {
        #expect(FrequenciaCardiaca.zona(.repeticoes, fcMaxima: 190) == nil)
        #expect(FrequenciaCardiaca.zona(.prova, fcMaxima: 190) == nil)
        #expect(FrequenciaCardiaca.zona(.facil, fcMaxima: 90) == nil)
    }

    @Test func zonasSobemComAIntensidade() {
        let ordem: [Intensidade] = [.caminhada, .facil, .maratona, .limiar, .intervalado]
        let zonas = ordem.compactMap { FrequenciaCardiaca.zona($0, fcMaxima: 185) }
        #expect(zonas.map(\.numero) == [1, 2, 3, 4, 5])
        for (a, b) in zip(zonas, zonas.dropFirst()) { #expect(a.maximo <= b.maximo) }
        #expect(zonas[1].contem(140) && !zonas[1].contem(160))
    }

    @Test func maximaEstimadaPelaIdade() throws {
        // Tanaka: 208 − 0,7 × 30 = 187.
        let fc = FrequenciaCardiaca.maximaEstimada(idade: 30)
        #expect(abs(fc - 187) < 1e-9)
        let z = try #require(FrequenciaCardiaca.zona(.facil, fcMaxima: fc))
        #expect(z.minimo == 121 && z.maximo == 148)
    }

    @Test func zonaSoOndeOBatimentoFirma() {
        // Tiro de 400 m (~1,5 min) e repetições vão pelo pace; limiar de 20 min e o trote longo, pela zona.
        #expect(!FrequenciaCardiaca.usaZona(Passo(.trabalho, .distancia(400), .intervalado), duracaoEstimada: 90))
        #expect(FrequenciaCardiaca.usaZona(Passo(.trabalho, .tempo(1200), .limiar), duracaoEstimada: 1200))
        #expect(FrequenciaCardiaca.usaZona(Passo(.aquecimento, .tempo(600), .facil), duracaoEstimada: 600))
        #expect(!FrequenciaCardiaca.usaZona(Passo(.recuperacao, .tempo(240), .facil), duracaoEstimada: 240))
        #expect(!FrequenciaCardiaca.usaZona(Passo(.trabalho, .distancia(200), .repeticoes), duracaoEstimada: 600))
        #expect(FrequenciaCardiaca.usaZona(Passo(.trabalho, .distancia(1000), .intervalado), duracaoEstimada: 230))
    }
}
