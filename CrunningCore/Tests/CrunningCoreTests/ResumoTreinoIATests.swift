import Foundation
import Testing
@testable import CrunningCore

@Suite("Resumo da corrida para a análise por IA")
struct ResumoTreinoIATests {
    let inicio = Date(timeIntervalSince1970: 1_800_000_000)
    let faixaTiro = FaixaRitmo(lento: 260, rapido: 250, alvo: 255)

    /// Aquecimento, tiro 1/2, recuperação pulada, tiro 2/2 e desaquecimento não feito (dados fictícios).
    func resultados() -> [ResultadoEtapa] {
        func etapa(_ id: Int, _ nome: String, _ funcao: FuncaoPasso, rep: Int? = nil, _ planejado: Medida, faixa: FaixaRitmo? = nil,
                   d: Double, dur: TimeInterval, de t0: TimeInterval, _ situacao: ResultadoEtapa.Situacao = .feita) -> ResultadoEtapa {
            ResultadoEtapa(id: id, nome: nome, tipo: .intervalado, repeticao: rep, totalRepeticoes: rep.map { _ in 2 }, ehExercicio: false,
                           planejado: planejado, faixa: faixa, distancia: d, duracao: dur, situacao: situacao, funcao: funcao,
                           inicio: situacao == .naoFeita ? nil : inicio.addingTimeInterval(t0),
                           fim: situacao == .naoFeita ? nil : inicio.addingTimeInterval(t0 + dur))
        }
        return [
            etapa(0, "Aquecimento", .aquecimento, .tempo(600), faixa: FaixaRitmo(lento: 375, rapido: 340, alvo: 360), d: 1650, dur: 600, de: 0),
            etapa(1, "Tiro", .trabalho, rep: 1, .distancia(400), faixa: faixaTiro, d: 400, dur: 95, de: 600),
            etapa(2, "Recuperação", .recuperacao, .tempo(90), d: 120, dur: 50, de: 695, .pulada),
            etapa(3, "Tiro", .trabalho, rep: 2, .distancia(400), faixa: faixaTiro, d: 400, dur: 106, de: 745),
            etapa(4, "Desaquecimento", .desaquecimento, .tempo(600), d: 0, dur: 0, de: 851, .naoFeita),
        ]
    }

    func fc() -> [AmostraFC] {
        // 140 bpm no aquecimento, 170 no tiro 1, 160 na recuperação, 180 no tiro 2.
        (0..<851).map { t in
            let bpm = t < 600 ? 140 : t < 695 ? 170 : t < 745 ? 160 : 180
            return AmostraFC(t: Double(t), bpm: bpm)
        }
    }

    func resumo(resultados: [ResultadoEtapa]? = nil, fc: [AmostraFC]? = nil) -> ResumoTreinoIA {
        ResumoTreinoIA(
            treino: "2 × 400 m", plano: "Prova de 10 km, semana 3 de 10, fase Base", esteira: false,
            corredor: .init(idade: 30, fcMaxima: 190, fcMaximaMedida: false), esforco: 8,
            resultados: resultados ?? self.resultados(), fc: fc ?? self.fc(), inicioCorrida: inicio,
            parciais: [Parcial(numero: 1, distancia: 1000, duracao: 330, completa: true)],
            distancia: 2570, tempoEmMovimento: 851, tempoTotal: 860, subida: 12,
            anterior: .init(diasAtras: 7, nome: "2 × 400 m", trechosPrincipais: "1:42, 1:43", esforcoPercebido: 7)
        )
    }

    @Test func etapasComPlanejadoEFeito() {
        let r = resumo()
        #expect(r.etapas.count == 5)
        #expect(r.etapas[0].planejado == "10:00 (pace 5:40–6:15)")
        #expect(r.etapas[1].etapa == "Tiro 1/2")
        #expect(r.etapas[1].planejado == "400 m em 1:40–1:44 (pace 4:10–4:20)")
        #expect(r.etapas[1].feito.tempo == "1:35")
        #expect(r.etapas[1].feito.pace == "3:58")
        #expect(r.etapas[1].feito.distanciaM == 400)
        #expect(r.etapas[1].feito.observacao == nil)
    }

    @Test func batimentosPorEtapa() {
        let r = resumo()
        #expect(r.etapas[1].feito.fcMedia == 170)
        #expect(r.etapas[3].feito.fcMaxima == 180)
        // A FC no fim só vai nas recuperações.
        #expect(r.etapas[2].feito.fcNoFim != nil)
        #expect(r.etapas[1].feito.fcNoFim == nil)
        #expect(r.totais.fcMaxima == 180)
        // Sem pulseira, nenhum campo de batimento.
        let semFC = resumo(fc: [])
        #expect(semFC.etapas.allSatisfy { $0.feito.fcMedia == nil && $0.feito.fcNoFim == nil })
        #expect(semFC.totais.fcMedia == nil)
    }

    @Test func situacoesViramObservacao() {
        let r = resumo()
        #expect(r.etapas[2].feito.observacao?.contains("pulada") == true)
        #expect(r.etapas[2].feito.tempo == "0:50")
        #expect(r.etapas[4].feito.observacao == "não feita")
        #expect(r.etapas[4].feito.tempo == nil)
    }

    @Test func corridaLivreVaiPorParciais() {
        let comEtapas = resumo()
        #expect(comEtapas.parciais.isEmpty)
        let livre = resumo(resultados: [])
        #expect(livre.etapas.isEmpty)
        #expect(livre.parciais == [.init(km: 1, tempo: "5:30", pace: "5:30", completa: true)])
        #expect(livre.totais.distanciaKm == 2.57)
        #expect(livre.totais.subidaM == 12)
    }

    @Test func trechosPrincipaisDeUmTreinoAnterior() {
        #expect(ResumoTreinoIA.trechosPrincipais(resultados()) == "1:35, 1:46")
        #expect(ResumoTreinoIA.trechosPrincipais([]) == nil)
    }

    @Test func jsonSoComDadosAgregados() throws {
        let texto = try resumo().json()
        #expect(texto.contains("\"fcNoFim\""))
        #expect(texto.contains("\"ultimoTreinoParecido\""))
        // Nada de rota, coordenadas ou horário.
        for proibido in ["lat", "lon", "coordenada", "trilha", "1800000000", "inicio\""] {
            #expect(!texto.contains(proibido), "o JSON não deveria ter \(proibido)")
        }
        // Opcionais nulos ficam de fora.
        #expect(!texto.contains("null"))
    }
}
