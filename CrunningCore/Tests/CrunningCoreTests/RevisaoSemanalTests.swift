import Foundation
import Testing
@testable import CrunningCore

@Suite("Revisão semanal só com desvio")
struct RevisaoSemanalTests {
    typealias A = AgendaPlanoTests

    static func diasComTreino(_ agenda: AgendaPlano, semana: Int) -> [Int] {
        (0..<7).filter { agenda.sessao(semana: semana, dia: $0) != nil }
    }

    @Test func qualSemanaRevisar() {
        let agenda = AgendaPlano(plano: A.plano, inicio: A.segunda, calendario: A.calendario)
        // Domingo da semana 1, à noite: revisa a semana 1. Segunda da semana 2: também a 1.
        let domingo = A.calendario.date(byAdding: .hour, value: 6, to: A.dia(6))!
        #expect(agenda.semanaParaRevisar(hoje: domingo, calendario: A.calendario) == 1)
        #expect(agenda.semanaParaRevisar(hoje: A.dia(7), calendario: A.calendario) == 1)
        #expect(agenda.semanaParaRevisar(hoje: A.dia(10), calendario: A.calendario) == 2)
        // Na primeira segunda do plano não há semana para revisar.
        #expect(agenda.semanaParaRevisar(hoje: A.segunda, calendario: A.calendario) == nil)
    }

    @Test func semanaDentroDoPlano() {
        var agenda = AgendaPlano(plano: A.plano, inicio: A.segunda, calendario: A.calendario)
        for dia in Self.diasComTreino(agenda, semana: 1) { agenda.marcar(semana: 1, dia: dia, .feita, esforco: 4) }
        let d = agenda.desvios(semana: 1, hoje: A.dia(7), corridasForaDoPlano: 0, ladosDoRitmo: [nil, nil], calendario: A.calendario)
        #expect(!d.temDesvio)
        #expect(d.motivos.isEmpty)
    }

    @Test func desviosContados() {
        var agenda = AgendaPlano(plano: A.plano, inicio: A.segunda, calendario: A.calendario)
        let dias = Self.diasComTreino(agenda, semana: 1)
        // A primeira sessão perdida, a segunda sem registro, o resto feito com esforço alto.
        agenda.marcar(semana: 1, dia: dias[0], .perdida)
        for dia in dias.dropFirst(2) { agenda.marcar(semana: 1, dia: dia, .feita, esforco: 8) }
        let d = agenda.desvios(semana: 1, hoje: A.dia(7), corridasForaDoPlano: 1, ladosDoRitmo: [true], calendario: A.calendario)
        #expect(d.perdidas == 2)
        #expect(d.foraDoPlano == 1)
        #expect(d.ritmoFora == 1)
        let faceisFeitas = dias.dropFirst(2).filter { agenda.sessao(semana: 1, dia: $0)?.ehForte == false }.count
        #expect(d.esforcoAltoEmFaceis == faceisFeitas)
        #expect(d.temDesvio)
        #expect(d.motivos.first == "2 treinos perdidos")
    }

    @Test func diaDeHojeNaoContaComoPerdido() {
        let agenda = AgendaPlano(plano: A.plano, inicio: A.segunda, calendario: A.calendario)
        let dias = Self.diasComTreino(agenda, semana: 1)
        guard let ultimo = dias.last else { return }
        // No próprio dia do último treino, ele ainda não conta como perdido.
        let d = agenda.desvios(semana: 1, hoje: A.dia(ultimo), corridasForaDoPlano: 0, ladosDoRitmo: [], calendario: A.calendario)
        #expect(d.perdidas == dias.count - 1)
    }
}
