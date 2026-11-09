import Foundation
import Testing
@testable import CrunningCore

@Suite("Zonas e previsão de prova")
struct ZonasTests {
    @Test func vdot50NasTabelasDeDaniels() throws {
        // Tabela de Daniels: 5 km em 19:57 e maratona em 3:10:49 valem VDOT 50.
        let cincoK = try #require(Daniels.vdot(distanciaMetros: 5000, tempoSegundos: 19 * 60 + 57))
        let maratona = try #require(Daniels.vdot(distanciaMetros: 42_195, tempoSegundos: 3 * 3600 + 10 * 60 + 49))
        #expect(abs(cincoK - 50) < 0.1)
        #expect(abs(maratona - 50) < 0.1)
    }

    @Test func previsaoBateComATabela() throws {
        let z = try #require(Zonas(vdot: 50))
        #expect(abs(z.tempoPrevisto(distanciaMetros: 5000) - (19 * 60 + 57)) <= 3)
        #expect(abs(z.tempoPrevisto(distanciaMetros: 42_195) - (3 * 3600 + 10 * 60 + 49)) <= 15)
    }

    @Test func limiarDeVDOT50() throws {
        // Tabela publicada: limiar de 4:15/km (6:51/milha) para VDOT 50.
        let alvo = try #require(Zonas(vdot: 50)).faixa(.limiar).alvo
        #expect(abs(alvo - 255) <= 2)
    }

    @Test(arguments: [25.0, 30, 40, 50, 60, 70, 80])
    func faixasEmOrdem(vdot: Double) throws {
        let z = try #require(Zonas(vdot: vdot))
        let ordem: [Intensidade] = [.facil, .maratona, .limiar, .intervalado, .repeticoes]
        let alvos = ordem.map { z.faixa($0).alvo }
        for (lento, rapido) in zip(alvos, alvos.dropFirst()) { #expect(lento > rapido) }
        for intensidade in Intensidade.allCases {
            let f = z.faixa(intensidade, distanciaProva: 10_000)
            #expect(f.lento >= f.alvo && f.alvo >= f.rapido)
            #expect(f.contem(f.alvo))
        }
    }

    @Test func previsaoInverteOVDOT() throws {
        for vdot in stride(from: 25.0, through: 80, by: 5) {
            for d in [1500.0, 5000, 10_000, 21_097.5, 42_195] {
                let t = Daniels.tempoPrevisto(distanciaMetros: d, vdot: vdot)
                let volta = try #require(Daniels.vdot(distanciaMetros: d, tempoSegundos: t))
                #expect(abs(volta - vdot) < 0.01)
            }
        }
    }

    @Test func velocidadeInverteOCusto() {
        for vo2 in [20.0, 35, 50, 70] {
            let v = Daniels.velocidade(paraVO2: vo2)
            #expect(abs(Daniels.custoOxigenio(metrosPorMinuto: v) - vo2) < 1e-9)
        }
    }

    @Test func foraDaFaixaNaoTemVDOT() {
        #expect(Daniels.vdot(distanciaMetros: 400, tempoSegundos: 60) == nil)
        #expect(Daniels.vdot(distanciaMetros: 5000, tempoSegundos: 60) == nil)
        #expect(Daniels.vdot(distanciaMetros: 5000, tempoSegundos: 7 * 3600) == nil)
        #expect(Zonas(vdot: 100) == nil)
        #expect(Zonas(vdot: 10) == nil)
    }

    @Test func riegel() {
        let t = Riegel.tempo(referenciaSegundos: 1200, distanciaReferencia: 5000, distanciaAlvo: 10_000)
        #expect(abs(t - 1200 * pow(2, 1.06)) < 1e-9)
        #expect(abs(t - 2502) < 1)
    }

    @Test func frequenciaCardiacaECarga() {
        #expect(FrequenciaCardiaca.maximaEstimada(idade: 40) == 180)
        #expect(CargaTreino.sessao(esforco: 6, minutos: 50) == 300)
        #expect(CargaTreino.sessao(esforco: 15, minutos: 10) == 100)
        #expect(CargaTreino.sessao(esforco: 5, minutos: -3) == 0)
    }

    @Test func semReferenciaVaiPeloEsforco() {
        for intensidade in Intensidade.allCases { #expect(!intensidade.testeDaFala.isEmpty) }
        #expect(Intensidade.facil.esforco.upperBound < Intensidade.limiar.esforco.lowerBound)
        #expect(Intensidade.limiar.esforco.upperBound < Intensidade.intervalado.esforco.lowerBound)
    }
}

@Suite("Calorias pelo Compêndio 2024")
struct CaloriasTests {
    @Test func linhasDaTabela() {
        #expect(Calorias.met(.corrida, velocidadeKmH: 9.9) == 9.3)
        #expect(Calorias.met(.corrida, velocidadeKmH: 11.3) == 11.0)
        #expect(Calorias.met(.caminhada, velocidadeKmH: 6.0) == 4.8)
    }

    @Test func interpolaEPrendeNasPontas() {
        let meio = Calorias.met(.corrida, velocidadeKmH: 10.35)
        #expect(meio > 9.3 && meio < 10.5)
        #expect(Calorias.met(.corrida, velocidadeKmH: 3) == 6.5)
        #expect(Calorias.met(.corrida, velocidadeKmH: 30) == 23.0)
    }

    @Test func naoDiminuiComAVelocidade() {
        for atividade in [Calorias.Atividade.corrida, .caminhada] {
            var anterior = 0.0
            for v in stride(from: 2.0, through: 24, by: 0.1) {
                let met = Calorias.met(atividade, velocidadeKmH: v)
                #expect(met >= anterior)
                anterior = met
            }
        }
    }

    @Test func quilocalorias() {
        #expect(abs(Calorias.estimar(.corrida, velocidadeKmH: 9.9, pesoKg: 70, duracaoSegundos: 3600) - 651) < 0.01)
        #expect(Calorias.estimar(.corrida, velocidadeKmH: 9.9, pesoKg: 0, duracaoSegundos: 3600) == 0)
    }
}

@Suite("Treinos e modelos")
struct TreinoTests {
    @Test func repeticoesAbrem() {
        let t = Modelos.intervalado800.treino(dose: 4000)
        #expect(t.passosExpandidos.count == 12)   // aquecimento + 5 x (tiro + trote) + desaquecimento
    }

    @Test func trabalhoBateComADose() throws {
        let z = try #require(Zonas(vdot: 45))
        for modelo in Modelos.todos where modelo.tipoDose == .distanciaDeTrabalho {
            let t = modelo.treino(dose: 4000)
            let trabalho = t.distanciaDeTrabalho(em: modelo.intensidadePrincipal, zonas: z)
            #expect(abs(trabalho - 4000) <= 601, "\(modelo.id): \(trabalho)")
        }
    }

    @Test func todosOsModelosTemPorqueEFonte() {
        #expect(Set(Modelos.todos.map(\.id)).count == Modelos.todos.count)
        for m in Modelos.todos {
            #expect(!m.porque.isEmpty)
            #expect(!m.fontes.isEmpty)
            let dose: Double = switch m.tipoDose {
            case .ciclos: 6
            case .minutosDeTrabalho: 12
            default: 5000
            }
            #expect(!m.treino(dose: dose).blocos.isEmpty)
        }
    }

    @Test func estimativas() throws {
        let z = try #require(Zonas(vdot: 50))
        let facil = Modelos.facil.treino(dose: 10_000)
        #expect(abs(facil.distanciaEstimada(zonas: z) - 10_000) < 0.01)
        #expect(abs(facil.duracaoEstimada(zonas: z) - 10 * z.faixa(.facil).alvo) < 0.01)
        let prova = Modelos.prova.treino(dose: 5000)
        #expect(abs(prova.duracaoEstimada(zonas: z) - z.tempoPrevisto(distanciaMetros: 5000)) < 0.5)
        #expect(prova.distanciaDeQualidade(zonas: z) == 0)
    }

    @Test func equivalentes() {
        #expect(Modelos.equivalentes(a: Modelos.cruise).map(\.id) == ["limiar-continuo"])
        let tiros = Set(Modelos.equivalentes(a: Modelos.intervalado800).map(\.id))
        #expect(tiros == ["intervalado-400", "intervalado-1000", "intervalado-1200", "escada"])
        #expect(Modelos.equivalentes(a: Modelos.prova).isEmpty)
    }

    @Test func caminhadaCorrida() {
        let t = Modelos.caminhadaCorrida(correrSegundos: 60, caminharSegundos: 90, ciclos: 8)
        let s = SessaoPlanejada(treino: t, zonas: Zonas.estimativaSemReferencia(.iniciante))
        #expect(ValidadorPlano.minutosCorrendo(s) == 8)
        let continua = Modelos.caminhadaCorrida(correrSegundos: 1800, caminharSegundos: 0, ciclos: 1)
        #expect(ValidadorPlano.minutosCorrendo(SessaoPlanejada(treino: continua, zonas: Zonas.estimativaSemReferencia(.iniciante))) == 30)
    }
}
