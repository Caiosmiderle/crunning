import Foundation
import Testing
@testable import CrunningCore

@Suite("Calor e prova secundária")
struct CalorEProvaTests {
    @Test func wbgtSimplificado() {
        #expect(abs(Calor.pressaoVapor(temperatura: 25, umidade: 50) - 15.79) < 0.1)
        #expect(Calor.avaliar(wbgt: Calor.wbgtSimplificado(temperatura: 5, umidade: 50)) == .semAjuste)
        #expect(Calor.avaliar(wbgt: Calor.wbgtSimplificado(temperatura: 15, umidade: 60)) == .ajuste(0.016))
        #expect(Calor.avaliar(wbgt: Calor.wbgtSimplificado(temperatura: 25, umidade: 50)) == .ajuste(0.028))
        #expect(Calor.avaliar(wbgt: Calor.wbgtSimplificado(temperatura: 32, umidade: 70)) == .foraDaFaixa)
        // Mais quente nunca deixa o ajuste menor.
        var anterior = 0.0
        for t in stride(from: 0.0, through: 40, by: 1) {
            let f = Calor.fracao(Calor.avaliar(wbgt: Calor.wbgtSimplificado(temperatura: t, umidade: 60)))
            #expect(f >= anterior)
            anterior = f
        }
    }

    @Test func faixasMaisLentasNoCalor() throws {
        let treino = Treino(nome: "Limiar", tipo: .limiar, blocos: [.passo(Passo(.trabalho, .tempo(1200), .limiar))])
        let zonas = try #require(Zonas(vdot: 50))
        let normal = ExecucaoTreino(treino: treino, zonas: zonas, aquecimentoGuiado: false, esteira: false)
        let quente = ExecucaoTreino(treino: treino, zonas: zonas, aquecimentoGuiado: false, esteira: false, ajusteCalor: 0.016)
        let a = try #require(normal.etapas[0].faixa), b = try #require(quente.etapas[0].faixa)
        #expect(abs(b.alvo - a.alvo * 1.016) < 0.001)
        #expect(normal.ajusteCalor == nil && quente.ajusteCalor == 0.016)
    }

    static let dezK = GeradorPlano.gerar(EntradaPlano(
        objetivo: .dezK, semanas: 12, nivel: .intermediario, diasDisponiveis: [1, 3, 5, 6], diaLongao: 6,
        volumeAtual: 30_000, longaoAtual: 10_000, vdot: 45
    ))

    @Test func provaSecundariaCabeERespeitaAsTravas() throws {
        let novo = try CorrecaoPlano.provaSecundaria(semana: 6, dia: 5, distancia: 5000).aplicar(Self.dezK)
        #expect(ValidadorPlano.validar(novo) == [])
        let semana = novo.semanas[5]
        #expect(semana.dias[5]?.ehProva == true)
        #expect(semana.dias[4]?.ehForte != true && semana.dias[6]?.ehForte != true)
        #expect(novo.semanas.last?.temProva == true)
    }

    @Test func provaSecundariaRecusada() {
        let ultima = Self.dezK.semanas.count
        #expect(throws: ErroCorrecao.self) { try CorrecaoPlano.provaSecundaria(semana: ultima, dia: 2, distancia: 5000).aplicar(Self.dezK) }
        #expect(throws: ErroCorrecao.self) { try CorrecaoPlano.provaSecundaria(semana: 4, dia: 5, distancia: 21_097.5).aplicar(Self.dezK) }
    }
}
