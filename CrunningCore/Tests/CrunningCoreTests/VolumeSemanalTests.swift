import Foundation
import Testing
@testable import CrunningCore

@Suite("Volume semanal")
struct VolumeSemanalTests {
    typealias A = AgendaPlanoTests

    @Test func somaPorMesComPlanoDivididoPelosDias() throws {
        // Plano de 6 semanas a partir de 2/11/2026 com 7 km cada (1 km por dia, dados fictícios).
        let plano: [(inicio: Date, distancia: Double)] = (0..<6).map { (A.dia($0 * 7), 7000) }
        let corridas: [(inicio: Date, distancia: Double)] = [
            (A.dia(1), 6000), (A.dia(6), 10_000), (A.dia(8), 5000), (A.dia(9), 8000), // novembro: 29 km
            (A.dia(-14), 7000),                                                     // outubro
        ]
        let m = VolumeSemanal.porMes(corridas: corridas, plano: plano, hoje: A.dia(9), passados: 1, calendario: A.calendario)
        #expect(m.count == 3) // outubro, novembro e dezembro (último mês do plano)
        #expect(m[0].feito == 7000 && m[0].planejado == nil)
        #expect(m[1].feito == 29_000)
        // Novembro: 4 semanas inteiras + o dia 30 da 5ª semana; dezembro: o resto dela + a 6ª.
        #expect(abs((m[1].planejado ?? 0) - 29_000) < 0.01)
        #expect(m[2].feito == 0)
        #expect(abs((m[2].planejado ?? 0) - 13_000) < 0.01)
        #expect(A.calendario.component(.day, from: m[2].inicio) == 1)
    }

    @Test func somaPorDiaDaSemana() {
        // Hoje: quarta, 11/11/2026 (A.dia(9)). Duas corridas hoje, uma na terça e uma na semana passada.
        let corridas: [(inicio: Date, distancia: Double)] = [
            (A.dia(8), 5000), (A.dia(9), 8000), (A.dia(9).addingTimeInterval(3600), 2000), (A.dia(6), 10_000),
        ]
        let dias = VolumeSemanal.porDia(corridas: corridas, hoje: A.dia(9), calendario: A.calendario)
        #expect(dias == [0, 5000, 10_000, 0, 0, 0, 0])
    }

    @Test func somaPorSemanaComPlano() throws {
        // Hoje: quarta da semana de 9/11/2026 (A.dia(9)). Corridas nesta semana, na passada e há 3 semanas.
        let hoje = A.dia(9)
        let corridas: [(inicio: Date, distancia: Double)] = [
            (A.dia(8), 5000), (A.dia(9), 8000),       // esta semana: 13 km
            (A.dia(1), 6000), (A.dia(6), 10_000),     // semana passada: 16 km
            (A.dia(-14), 7000),                       // duas semanas antes dela
            (A.dia(3), 0),                            // sem distância (esteira sem o número): ignorada
        ]
        let plano: [(inicio: Date, distancia: Double)] = (0..<6).map { (A.dia($0 * 7), Double(20_000 + $0 * 1000)) }
        let s = VolumeSemanal.calcular(corridas: corridas, plano: plano, hoje: hoje, passadas: 3, futuras: 4, calendario: A.calendario)
        // 3 passadas + a atual + 4 futuras com plano (o plano vai até a semana +4).
        #expect(s.count == 8)
        let atual = try #require(s.first { A.calendario.isDate($0.inicio, inSameDayAs: A.dia(7)) })
        #expect(atual.feito == 13_000)
        #expect(atual.planejado == 21_000)
        let passada = try #require(s.first { A.calendario.isDate($0.inicio, inSameDayAs: A.segunda) })
        #expect(passada.feito == 16_000 && passada.planejado == 20_000)
        #expect(s.first?.planejado == nil)                 // antes do plano
        #expect(s.last.map { $0.feito == 0 && $0.planejado != nil } == true)
        #expect(s.map(\.inicio) == s.map(\.inicio).sorted())
    }

    @Test func semPlanoNaoHaSemanasFuturas() {
        let s = VolumeSemanal.calcular(corridas: [], plano: [], hoje: A.dia(9), passadas: 11, futuras: 4, calendario: A.calendario)
        #expect(s.count == 12)
        #expect(s.allSatisfy { $0.feito == 0 && $0.planejado == nil })
    }

    @Test func mediaEVariacao() {
        let hoje = A.dia(23)  // quarta, três semanas depois de A.segunda
        let corridas: [(inicio: Date, distancia: Double)] = [
            (A.dia(1), 20_000), (A.dia(8), 22_000), (A.dia(15), 25_000), (A.dia(22), 5000),
        ]
        let s = VolumeSemanal.calcular(corridas: corridas, plano: [], hoje: hoje, passadas: 3, futuras: 0, calendario: A.calendario)
        // Semanas completas: 20, 22 e 25 km (a atual, com 5 km, não entra).
        #expect(abs(VolumeSemanal.media(s, ultimas: 3, hoje: hoje, calendario: A.calendario) - 22_333.33) < 1)
        let v = VolumeSemanal.variacao(s, hoje: hoje, calendario: A.calendario)
        #expect(v.map { abs($0 - 3.0 / 22.0) < 1e-9 } == true)
    }
}
