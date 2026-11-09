import Foundation
import Testing
@testable import CrunningCore

@Suite("Frequência cardíaca da pulseira")
struct FrequenciaCardiacaTests {
    @Test func anuncioDaMiBand() {
        // Código da Xiaomi (0x0157, little-endian), três bytes quaisquer e o batimento.
        #expect(FrequenciaCardiaca.lerAnuncioMiBand([0x57, 0x01, 0x02, 0x00, 0x00, 142, 0x10]) == 142)
        #expect(FrequenciaCardiaca.lerAnuncioMiBand([0x4C, 0x00, 0x02, 0x00, 0x00, 142]) == nil) // outra empresa
        #expect(FrequenciaCardiaca.lerAnuncioMiBand([0x57, 0x01, 0x02, 0x00, 0x00, 0xFF]) == nil) // sem leitura
        #expect(FrequenciaCardiaca.lerAnuncioMiBand([0x57, 0x01, 0x02, 0x00, 0x00, 0]) == nil)
        #expect(FrequenciaCardiaca.lerAnuncioMiBand([0x57, 0x01, 0x02]) == nil) // curto demais
        #expect(FrequenciaCardiaca.ehXiaomi([0x57, 0x01]))
    }

    @Test func mediaPonderadaPeloTempo() throws {
        // 100 bpm por 4 s, depois 160 bpm por 1 s e a última leitura vale 1 s.
        let amostras = [AmostraFC(t: 0, bpm: 100), AmostraFC(t: 4, bpm: 160), AmostraFC(t: 5, bpm: 160)]
        let r = try #require(FrequenciaCardiaca.resumo(amostras))
        #expect(r.maxima == 160)
        #expect(r.media == 120) // (100·4 + 160·1 + 160·1) / 6 ≈ 120
        // Um buraco longo (sem leitura) pesa no máximo 5 s.
        let comBuraco = [AmostraFC(t: 0, bpm: 100), AmostraFC(t: 600, bpm: 150)]
        #expect(FrequenciaCardiaca.resumo(comBuraco)?.media == 108) // (100·5 + 150·1) / 6
        #expect(FrequenciaCardiaca.resumo([]) == nil)
        #expect(FrequenciaCardiaca.resumo([AmostraFC(t: 0, bpm: 250)]) == nil)
    }

    @Test func valorMaisProximo() {
        let amostras = (0..<10).map { AmostraFC(t: Double($0) * 3, bpm: 120 + $0) }
        #expect(FrequenciaCardiaca.valor(em: 0, amostras) == 120)
        #expect(FrequenciaCardiaca.valor(em: 7, amostras) == 122) // 6 s está mais perto que 9 s
        #expect(FrequenciaCardiaca.valor(em: 27, amostras) == 129)
        #expect(FrequenciaCardiaca.valor(em: 40, amostras) == nil) // longe demais da última
        #expect(FrequenciaCardiaca.valor(em: 5, []) == nil)
    }

    @Test func tcxComBatimentos() throws {
        let inicio = Date(timeIntervalSince1970: 1_800_000_000)
        let rota = (0..<5).map { i in
            AmostraTrilha(t: Double(i) * 10, lat: -20.3 + Double(i) * 0.0003, lon: -40.3, alt: nil, d: Double(i) * 33, mov: Double(i) * 10, seg: 0)
        }
        let fc = (0..<45).map { AmostraFC(t: Double($0), bpm: 140 + $0 % 5) }
        let xml = TCX.gerar(.init(nome: "Fácil", inicio: inicio, duracaoEmMovimento: 40, distancia: 132, calorias: 0), amostras: rota, fc: fc)
        let c = try TCXTests.ler(xml)
        #expect(c.elementos["HeartRateBpm"] == 5)
        #expect(c.elementos["AverageHeartRateBpm"] == 1)
        #expect(c.elementos["MaximumHeartRateBpm"] == 1)
        // Esquema TCX v2: média e máxima depois de Calories e antes de Intensity.
        let calorias = try #require(xml.range(of: "<Calories>"))
        let media = try #require(xml.range(of: "<AverageHeartRateBpm>"))
        let intensidade = try #require(xml.range(of: "<Intensity>"))
        #expect(calorias.lowerBound < media.lowerBound && media.lowerBound < intensidade.lowerBound)

        // Esteira com batimentos: só média e máxima, sem pontos.
        let esteira = TCX.gerar(.init(nome: "Esteira", inicio: inicio, duracaoEmMovimento: 45, distancia: 150, calorias: 0), amostras: [], fc: fc)
        let e = try TCXTests.ler(esteira)
        #expect(e.elementos["Track"] == nil)
        #expect(e.elementos["AverageHeartRateBpm"] == 1)
        // Sem batimentos, nada muda.
        let sem = try TCXTests.ler(TCX.gerar(.init(nome: "x", inicio: inicio, duracaoEmMovimento: 1, distancia: 1, calorias: 0), amostras: rota))
        #expect(sem.elementos["HeartRateBpm"] == nil && sem.elementos["AverageHeartRateBpm"] == nil)
    }
}
