import Foundation
import Testing
@testable import CrunningCore

@Suite("Semana de treino")
struct CalendarioTreinoTests {
    let utc = TimeZone(identifier: "UTC")!

    func data(_ ano: Int, _ mes: Int, _ dia: Int, _ hora: Int = 12) -> Date {
        var componentes = DateComponents()
        componentes.year = ano; componentes.month = mes; componentes.day = dia; componentes.hour = hora
        return CalendarioTreino.padrao(fuso: utc).date(from: componentes)!
    }

    @Test func semanaComecaNaSegunda() {
        let calendario = CalendarioTreino.padrao(fuso: utc)
        // 11/11/2026 é quarta; a semana começa na segunda 09/11.
        #expect(CalendarioTreino.inicioDaSemana(data(2026, 11, 11), calendario: calendario) == data(2026, 11, 9, 0))
    }

    @Test func domingoFechaASemana() {
        let calendario = CalendarioTreino.padrao(fuso: utc)
        // 15/11/2026 é domingo: ainda pertence à semana iniciada em 09/11.
        #expect(CalendarioTreino.inicioDaSemana(data(2026, 11, 15, 23), calendario: calendario) == data(2026, 11, 9, 0))
    }

    @Test func seteDiasConsecutivos() {
        let calendario = CalendarioTreino.padrao(fuso: utc)
        let dias = CalendarioTreino.diasDaSemana(contendo: data(2026, 12, 31), calendario: calendario)
        #expect(dias.count == 7)
        #expect(dias.first == data(2026, 12, 28, 0))
        #expect(dias.last == data(2027, 1, 3, 0))
        for (anterior, proximo) in zip(dias, dias.dropFirst()) {
            #expect(proximo.timeIntervalSince(anterior) == 86_400)
        }
    }
}
