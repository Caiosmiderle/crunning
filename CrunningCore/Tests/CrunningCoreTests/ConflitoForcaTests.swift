import Foundation
import Testing
@testable import CrunningCore

@Suite("Perna pesada no Anilha perto de treino forte")
struct ConflitoForcaTests {
    typealias A = AgendaPlanoTests

    /// Um dia de treino forte na semana 2 (com dia anterior na mesma semana) e a data dele.
    static func diaForte(_ agenda: AgendaPlano) throws -> (dia: Int, data: Date) {
        let d = try #require((1...6).first { d in
            agenda.sessao(semana: 2, dia: d).map { ConflitoForca.forte($0.tipo) } ?? false
        })
        return (d, agenda.data(semana: 2, dia: d, calendario: A.calendario))
    }

    static func estado(feitaEm data: Date, pernas: Bool = true, series: Int = 9) -> EstadoForcaAnilha {
        var e = EstadoForcaAnilha()
        let chave = EstadoForcaAnilha.chave(data, calendario: A.calendario)
        e.feitas["f1"] = SessaoForcaAnilha(origemID: "f1", atualizadoEm: "2026-11-01T10:00:00.000Z", dataLocal: chave,
                                           pernas: pernas, seriesPernas: series, nome: "Pernas A")
        return e
    }

    @Test func pernaPesadaNaVesperaGeraAviso() throws {
        let agenda = AgendaPlano(plano: A.plano, inicio: A.segunda, calendario: A.calendario)
        let alvo = try Self.diaForte(agenda)
        let vespera = A.calendario.date(byAdding: .day, value: -1, to: alvo.data)!
        let avisos = ConflitoForca.avisos(agenda: agenda, forca: Self.estado(feitaEm: vespera), hoje: alvo.data, calendario: A.calendario)
        let aviso = try #require(avisos.first { $0.semana == 2 && $0.dia == alvo.dia })
        #expect(aviso.diasAntes == 1)
        #expect(!aviso.prevista)
        #expect(aviso.seriesPernas == 9)
        #expect(aviso.motivo.contains("Pernas A"))
        #expect(aviso.motivo.contains("48 h"))
        // A troca, quando existe, vai para depois, na mesma semana, num dia que não é forte.
        if case let .moverTreino(semana, de, para)? = aviso.sugestao {
            #expect(semana == 2 && de == alvo.dia && para > de)
            #expect(!(agenda.sessao(semana: 2, dia: para).map { ConflitoForca.forte($0.tipo) } ?? false))
            #expect((try? aviso.sugestao!.aplicar(agenda.plano)) != nil)
        }
    }

    @Test func doisDiasAntesAindaConta() throws {
        let agenda = AgendaPlano(plano: A.plano, inicio: A.segunda, calendario: A.calendario)
        let alvo = try Self.diaForte(agenda)
        let antes = A.calendario.date(byAdding: .day, value: -2, to: alvo.data)!
        let avisos = ConflitoForca.avisos(agenda: agenda, forca: Self.estado(feitaEm: antes), hoje: alvo.data, calendario: A.calendario)
        #expect(avisos.first { $0.dia == alvo.dia && $0.semana == 2 }?.diasAntes == 2)
    }

    @Test func leveOuSemPernaNaoAvisa() throws {
        let agenda = AgendaPlano(plano: A.plano, inicio: A.segunda, calendario: A.calendario)
        let alvo = try Self.diaForte(agenda)
        let vespera = A.calendario.date(byAdding: .day, value: -1, to: alvo.data)!
        let poucas = Self.estado(feitaEm: vespera, series: ConflitoForca.seriesPesada - 1)
        let semPerna = Self.estado(feitaEm: vespera, pernas: false, series: 0)
        let tresDias = Self.estado(feitaEm: A.calendario.date(byAdding: .day, value: -3, to: alvo.data)!)
        for estado in [poucas, semPerna, tresDias] {
            let avisos = ConflitoForca.avisos(agenda: agenda, forca: estado, hoje: alvo.data, calendario: A.calendario)
            #expect(!avisos.contains { $0.semana == 2 && $0.dia == alvo.dia })
        }
    }

    @Test func pernaPrevistaNaVesperaAvisaComoPrevisao() throws {
        let agenda = AgendaPlano(plano: A.plano, inicio: A.segunda, calendario: A.calendario)
        let alvo = try Self.diaForte(agenda)
        let vespera = EstadoForcaAnilha.chave(A.calendario.date(byAdding: .day, value: -1, to: alvo.data)!, calendario: A.calendario)
        var e = EstadoForcaAnilha()
        e.planejadas = [ForcaPlanejadaAnilha(dataLocal: vespera, nome: "Pernas B", pernas: true)]
        let aviso = try #require(ConflitoForca.avisos(agenda: agenda, forca: e, hoje: alvo.data, calendario: A.calendario)
            .first { $0.semana == 2 && $0.dia == alvo.dia })
        #expect(aviso.prevista)
        #expect(aviso.seriesPernas == nil)
        #expect(aviso.motivo.contains("prevê"))
    }

    @Test func treinoJaFeitoNaoAvisa() throws {
        var agenda = AgendaPlano(plano: A.plano, inicio: A.segunda, calendario: A.calendario)
        let alvo = try Self.diaForte(agenda)
        agenda.marcar(semana: 2, dia: alvo.dia, .feita, esforco: 6)
        let vespera = A.calendario.date(byAdding: .day, value: -1, to: alvo.data)!
        let avisos = ConflitoForca.avisos(agenda: agenda, forca: Self.estado(feitaEm: vespera), hoje: alvo.data, calendario: A.calendario)
        #expect(!avisos.contains { $0.semana == 2 && $0.dia == alvo.dia })
    }

    @Test func forcaParaCoachUltimosEProximos14Dias() throws {
        var e = Self.estado(feitaEm: A.dia(9))
        let chaveFutura = EstadoForcaAnilha.chave(A.dia(12), calendario: A.calendario)
        e.planejadas = [ForcaPlanejadaAnilha(dataLocal: chaveFutura, nome: "Costas", pernas: false)]
        let f = try #require(ConflitoForca.paraCoach(e, hoje: A.dia(10), calendario: A.calendario))
        #expect(f.feitas == [.init(diasAtras: 1, ficha: "Pernas A", perna: true, seriesPerna: 9, parcial: false)])
        // A.dia(12) é 14 de novembro, sábado (a segunda do teste é dia 2): índice 5.
        #expect(f.previstas == [.init(diasAFrente: 2, diaDaSemana: 5, ficha: "Costas", perna: false)])
        #expect(f.seriesPernaPesada == ConflitoForca.seriesPesada)
        // Fora da janela de 14 dias, nada vai.
        #expect(ConflitoForca.paraCoach(e, hoje: A.dia(40), calendario: A.calendario) == nil)
        // Nenhum campo de carga, horário ou identificador.
        let json = String(decoding: try JSONEncoder().encode(f), as: UTF8.self)
        #expect(!json.contains("origem") && !json.contains("inicio") && !json.contains("kg"))
    }

    @Test func resumoParaOCoachSoComAgregados() throws {
        let corrida = A.dia(10)
        let e = Self.estado(feitaEm: A.dia(9))
        let texto = try #require(ConflitoForca.resumoParaCoach(antesDe: corrida, forca: e, calendario: A.calendario))
        #expect(texto == "Pernas A (1 dia antes, perna: 9 séries)")
        #expect(ConflitoForca.resumoParaCoach(antesDe: A.dia(20), forca: e, calendario: A.calendario) == nil)
    }
}
