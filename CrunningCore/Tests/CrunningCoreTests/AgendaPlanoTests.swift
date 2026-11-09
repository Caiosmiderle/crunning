import Foundation
import Testing
@testable import CrunningCore

@Suite("Plano no calendário, adaptação e recordes")
struct AgendaPlanoTests {
    static let calendario: Calendar = {
        var c = CalendarioTreino.padrao(fuso: TimeZone(identifier: "America/Sao_Paulo")!)
        c.locale = Locale(identifier: "pt_BR")
        return c
    }()

    /// Segunda-feira, 2 de novembro de 2026, ao meio-dia.
    static let segunda = calendario.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!

    static func dia(_ n: Int) -> Date { calendario.date(byAdding: .day, value: n, to: segunda)! }

    static let plano = GeradorPlano.gerar(EntradaPlano(
        objetivo: .dezK, semanas: 12, nivel: .intermediario, diasDisponiveis: [1, 3, 5, 6], diaLongao: 6,
        volumeAtual: 30_000, longaoAtual: 10_000, vdot: 45
    ))

    @Test func posicaoNoCalendario() throws {
        let agenda = AgendaPlano(plano: Self.plano, inicio: Self.dia(2), calendario: Self.calendario)
        // O começo vai para a segunda da semana.
        #expect(Self.calendario.isDate(agenda.inicio, inSameDayAs: Self.segunda))
        let p = try #require(agenda.posicao(de: Self.dia(8), calendario: Self.calendario))
        #expect(p.semana == 2 && p.dia == 1)
        #expect(agenda.posicao(de: Self.dia(-1), calendario: Self.calendario) == nil)
        #expect(agenda.posicao(de: Self.dia(12 * 7), calendario: Self.calendario) == nil)
        #expect(Self.calendario.isDate(agenda.data(semana: 2, dia: 1, calendario: Self.calendario), inSameDayAs: Self.dia(8)))
    }

    @Test func pendentesSoDeDiasPassadosComTreino() {
        var agenda = AgendaPlano(plano: Self.plano, inicio: Self.segunda, calendario: Self.calendario)
        // Hoje é segunda da semana 2: na semana 1 havia treino na terça, quinta, sábado e domingo.
        let pendentes = agenda.pendentes(hoje: Self.dia(7), calendario: Self.calendario)
        #expect(pendentes.map(\.dia) == [1, 3, 5, 6])
        agenda.marcar(semana: 1, dia: 1, .feita, esforco: 4)
        agenda.marcar(semana: 1, dia: 3, .perdida)
        #expect(agenda.pendentes(hoje: Self.dia(7), calendario: Self.calendario).map(\.dia) == [5, 6])
        #expect(agenda.status(semana: 1, dia: 1) == .feita)
    }

    @Test func esforcoAltoNasFaceis() {
        var agenda = AgendaPlano(plano: Self.plano, inicio: Self.segunda, calendario: Self.calendario)
        let faceis = (0..<7).filter { d in agenda.sessao(semana: 1, dia: d).map { !$0.ehForte } ?? false }
        for d in faceis { agenda.marcar(semana: 1, dia: d, .feita, esforco: 7) }
        let esforcos = agenda.esforcosRecentesEmFaceis(ate: Self.dia(6), calendario: Self.calendario)
        #expect(esforcos.count == faceis.count)
        if esforcos.count >= 2 {
            #expect(Adaptacao.avaliar(.esforcoAltoEmFaceis(seguidas: 2, esforco: esforcos[0])) != .seguir("Esforço dentro do esperado. Siga o plano."))
        }
    }

    @Test func retomarDepoisDePausaPeloMotor() throws {
        let novo = try CorrecaoPlano.retomarAposPausa(semana: 5, dias: 14).aplicar(Self.plano)
        #expect(ValidadorPlano.validar(novo) == [])
        #expect(novo.semanas[4].volumeTreino < Self.plano.semanas[4].volumeTreino)
        #expect(throws: ErroCorrecao.self) { try CorrecaoPlano.retomarAposPausa(semana: 5, dias: 3).aplicar(Self.plano) }
    }

    @Test func provaMudouDeData() throws {
        let novo = try CorrecaoPlano.reajustarProva(aPartirDaSemana: 4, semanasRestantes: 12).aplicar(Self.plano)
        #expect(novo.semanas.count == 15)
        #expect(ValidadorPlano.validar(novo) == [])
        #expect(novo.semanas.last?.temProva == true)
    }

    @Test func ladoDoRitmo() {
        let faixa = FaixaRitmo(lento: 250, rapido: 240, alvo: 245)
        func r(_ ritmo: Double) -> ResultadoEtapa {
            ResultadoEtapa(id: 0, nome: "Tiro", tipo: .intervalado, repeticao: nil, totalRepeticoes: nil, ehExercicio: false,
                           planejado: .distancia(1000), faixa: faixa, distancia: 1000, duracao: ritmo, situacao: .feita)
        }
        #expect(Adaptacao.ladoDoRitmo([r(230), r(232), r(245)]) == true)
        #expect(Adaptacao.ladoDoRitmo([r(260), r(262), r(245)]) == false)
        #expect(Adaptacao.ladoDoRitmo([r(245), r(244)]) == nil)
        let s = Adaptacao.foraDoRitmoSeguidos([true, true, true, false])
        #expect(s?.seguidos == 3 && s?.maisRapido == true)
        #expect(Adaptacao.foraDoRitmoSeguidos([nil, true]) == nil)
    }

    @Test func melhorTrechoDaCorrida() throws {
        // 6 km: o 2º e o 3º km mais rápidos (240 s/km), o resto a 300 s/km. Uma amostra a cada 10 m.
        var amostras: [AmostraTrilha] = []
        var mov = 0.0
        for i in 0...600 {
            let d = Double(i) * 10
            if i > 0 { mov += (d > 1000 && d <= 3000) ? 2.4 : 3.0 }
            amostras.append(AmostraTrilha(t: mov, lat: 0, lon: 0, alt: nil, d: d, mov: mov, seg: 0))
        }
        let km = try #require(Recordes.melhorTempo(amostras, distancia: 1000))
        #expect(abs(km - 240) < 0.01)
        let cinco = try #require(Recordes.melhorTempo(amostras, distancia: 5000))
        #expect(abs(cinco - (2 * 240 + 3 * 300)) < 0.01)
        #expect(Recordes.melhorTempo(amostras, distancia: 10_000) == nil)
    }

    @Test func proximaSegunda() {
        #expect(Self.calendario.isDate(AgendaPlano.proximaSegunda(Self.dia(2), calendario: Self.calendario), inSameDayAs: Self.dia(7)))
        #expect(Self.calendario.isDate(AgendaPlano.proximaSegunda(Self.segunda, calendario: Self.calendario), inSameDayAs: Self.segunda))
    }

    @Test func voltarAoAnterior() throws {
        var agenda = AgendaPlano(plano: Self.plano, inicio: Self.segunda, calendario: Self.calendario)
        let semAnterior = agenda.voltarAoAnterior()
        #expect(!semAnterior)
        let novo = try CorrecaoPlano.aliviarSemana(semana: 5).aplicar(Self.plano)
        agenda.trocarPlano(novo)
        #expect(agenda.plano == novo && agenda.anterior == Self.plano)
        let voltou = agenda.voltarAoAnterior()
        #expect(voltou)
        #expect(agenda.plano == Self.plano && agenda.anterior == nil)
    }

    @Test func salvaEVoltaIgual() throws {
        var agenda = AgendaPlano(plano: Self.plano, inicio: Self.segunda, calendario: Self.calendario)
        agenda.marcar(semana: 1, dia: 1, .feita, esforco: 5)
        let volta = try JSONDecoder().decode(AgendaPlano.self, from: JSONEncoder().encode(agenda))
        #expect(volta == agenda)
    }
}
