import Foundation
import Testing
@testable import CrunningCore

@Suite("Execução por blocos")
struct ExecucaoTests {
    static let zero = Date(timeIntervalSince1970: 1_000_000)
    static let zonas = Zonas(vdot: 50)!

    /// Corredor constante: `v` m/s, um segundo por leitura, sem pausas.
    static func leitura(_ t: Double, v: Double, ritmo: Double? = nil, movimento: Double? = nil, pausada: Bool = false) -> LeituraExecucao {
        LeituraExecucao(
            instante: zero.addingTimeInterval(t), distancia: v * (movimento ?? t), tempoMovimento: movimento ?? t,
            ritmoAtual: ritmo ?? 1000 / v, pausadaManual: pausada
        )
    }

    static func rodar(_ e: inout ExecucaoTreino, ate fim: Int, v: Double) -> [(Int, EventoExecucao)] {
        var eventos: [(Int, EventoExecucao)] = e.iniciar(leitura(0, v: v)).map { (0, $0) }
        for t in 1...fim {
            eventos += e.atualizar(leitura(Double(t), v: v)).map { (t, $0) }
        }
        return eventos
    }

    static let tiros = Treino(nome: "2 × 400 m", tipo: .intervalado, blocos: [
        .repetir(vezes: 2, passos: [Passo(.trabalho, .distancia(400), .intervalado), Passo(.recuperacao, .tempo(90), .facil)]),
    ])

    @Test func avancaPorDistanciaEPorTempo() {
        var e = ExecucaoTreino(treino: Self.tiros, zonas: Self.zonas, aquecimentoGuiado: false, esteira: false)
        #expect(e.etapas.count == 4)
        let eventos = Self.rodar(&e, ate: 400, v: 4)
        let comecos = eventos.compactMap { t, ev -> (Int, Int)? in
            if case let .comecouEtapa(i) = ev { return (t, i) }
            return nil
        }
        // 400 m a 4 m/s = 100 s; recuperação de 90 s.
        #expect(comecos.map(\.0) == [0, 100, 190, 290])
        #expect(comecos.map(\.1) == [0, 1, 2, 3])
        #expect(eventos.contains { $0.0 == 380 && $0.1 == .terminouTreino })
        #expect(e.terminou)
        let r = e.resultados
        #expect(r.allSatisfy { $0.situacao == .feita })
        #expect(abs((r[0].ritmo ?? 0) - 250) < 0.01)
        #expect(r[1].duracao == 90)
        #expect(r[0].repeticao == 1 && r[2].repeticao == 2 && r[2].totalRepeticoes == 2)
    }

    @Test func contagemRegressiva() {
        var e = ExecucaoTreino(treino: Self.tiros, zonas: Self.zonas, aquecimentoGuiado: false, esteira: false)
        let eventos = Self.rodar(&e, ate: 191, v: 4)
        let tiro = eventos.filter { $0.0 >= 96 && $0.0 <= 100 }.map(\.1)
        #expect(tiro == [.contagem(3), .contagem(2), .contagem(1), .comecouEtapa(1)])
        let pausa = eventos.filter { $0.0 >= 185 && $0.0 <= 190 }.map(\.1)
        #expect(pausa == [.contagem(3), .contagem(2), .contagem(1), .comecouEtapa(2)])
    }

    @Test func fimDoTiroInterpolado() {
        // 3,7 m/s: os 400 m caem entre duas leituras; o tempo do tiro sai do metro exato.
        var e = ExecucaoTreino(treino: Self.tiros, zonas: Self.zonas, aquecimentoGuiado: false, esteira: false)
        _ = Self.rodar(&e, ate: 200, v: 3.7)
        let tiro = e.etapas[0]
        #expect(abs((tiro.fim?.distancia ?? 0) - 400) < 0.001)
        #expect(abs((tiro.fim?.tempoMovimento ?? 0) - 400 / 3.7) < 0.001)
    }

    @Test func avisoDeRitmoComAtrasoEIntervalo() throws {
        let treino = Treino(nome: "Limiar", tipo: .limiar, blocos: [.passo(Passo(.trabalho, .tempo(300), .limiar))])
        var e = ExecucaoTreino(treino: treino, zonas: Self.zonas, aquecimentoGuiado: false, esteira: false)
        let faixa = try #require(e.etapas[0].faixa)
        let lento = faixa.lento * 1.10
        _ = e.iniciar(Self.leitura(0, v: 1000 / lento))
        var avisos: [(Int, AvisoRitmo)] = []
        for t in 1...299 {
            let ritmo = t < 200 ? lento : faixa.alvo
            for ev in e.atualizar(Self.leitura(Double(t), v: 1000 / ritmo, ritmo: ritmo)) {
                if case let .ritmo(a) = ev { avisos.append((t, a)) }
            }
        }
        // Rampa de 20 s, 15 s fora antes do primeiro aviso, depois no máximo um por minuto.
        #expect(avisos.map(\.0) == [35, 95, 155, 200])
        #expect(avisos.map(\.1) == [.acelerar, .acelerar, .acelerar, .voltouAoRitmo])
    }

    @Test func facilNaoTemPiso() throws {
        let treino = Treino(nome: "Fácil", tipo: .facil, blocos: [.passo(Passo(.trabalho, .tempo(300), .facil))])
        var devagar = ExecucaoTreino(treino: treino, zonas: Self.zonas, aquecimentoGuiado: false, esteira: false)
        var rapido = devagar
        let faixa = try #require(devagar.etapas[0].faixa)
        _ = devagar.iniciar(Self.leitura(0, v: 2))
        _ = rapido.iniciar(Self.leitura(0, v: 2))
        var avisosDevagar: [EventoExecucao] = []
        var avisosRapido: [EventoExecucao] = []
        for t in 1...120 {
            avisosDevagar += devagar.atualizar(Self.leitura(Double(t), v: 2, ritmo: faixa.lento * 1.3))
            avisosRapido += rapido.atualizar(Self.leitura(Double(t), v: 2, ritmo: faixa.rapido * 0.85))
        }
        #expect(!avisosDevagar.contains(.ritmo(.acelerar)))
        #expect(avisosRapido.contains(.ritmo(.reduzir)))
    }

    @Test func pausaAutomaticaNaoCongelaARecuperacao() {
        let treino = Treino(nome: "x", tipo: .intervalado, blocos: [
            .passo(Passo(.trabalho, .tempo(60), .intervalado)),
            .passo(Passo(.recuperacao, .tempo(60), .facil)),
            .passo(Passo(.trabalho, .tempo(60), .intervalado)),
        ])
        var e = ExecucaoTreino(treino: treino, zonas: Self.zonas, aquecimentoGuiado: false, esteira: false)
        _ = e.iniciar(Self.leitura(0, v: 4))
        // Tiro: a pausa automática (movimento parado entre 30 s e 50 s) segura o relógio do tiro.
        for t in 1...80 {
            let movimento = t < 30 ? Double(t) : (t < 50 ? 30 : Double(t - 20))
            _ = e.atualizar(Self.leitura(Double(t), v: 4, movimento: movimento))
            if t == 60 { #expect(e.atual == 0) }
        }
        #expect(e.atual == 1)
        // Recuperação: parado em pé (movimento congelado), o relógio corre igual.
        var t = 81
        while e.atual == 1, t < 200 {
            _ = e.atualizar(Self.leitura(Double(t), v: 4, movimento: 60))
            t += 1
        }
        #expect(t - 1 == 140)
        // Pausa manual para tudo, inclusive a recuperação.
        var e2 = ExecucaoTreino(treino: treino, zonas: Self.zonas, aquecimentoGuiado: false, esteira: false)
        _ = e2.iniciar(Self.leitura(0, v: 4))
        for s in 1...60 { _ = e2.atualizar(Self.leitura(Double(s), v: 4)) }
        #expect(e2.atual == 1)
        for s in 61...200 { _ = e2.atualizar(Self.leitura(Double(s), v: 4, movimento: 60, pausada: true)) }
        #expect(e2.atual == 1)
    }

    @Test func aquecimentoGuiadoDepoisDoTrote() throws {
        let treino = Modelos.intervalado800.treino(dose: 4000)
        let e = ExecucaoTreino(treino: treino, zonas: Self.zonas, aquecimentoGuiado: true, esteira: false)
        let exercicios = Aquecimento.completa.etapas.flatMap(\.exercicios).filter { $0.id != "trote" }
        #expect(e.etapas[0].passo?.funcao == .aquecimento)
        #expect(e.etapas[1...exercicios.count].map { $0.exercicio?.id ?? "" } == exercicios.map(\.id))
        #expect(e.etapas[exercicios.count + 1].passo?.funcao == .trabalho)
        // Sem o aquecimento guiado, só os passos do treino.
        let sem = ExecucaoTreino(treino: treino, zonas: Self.zonas, aquecimentoGuiado: false, esteira: false)
        #expect(sem.etapas.allSatisfy { $0.exercicio == nil })
    }

    @Test func aquecimentoGuiadoAntesDaProva() throws {
        let e = ExecucaoTreino(treino: Modelos.prova.treino(dose: 10_000), zonas: Self.zonas, aquecimentoGuiado: true, esteira: false)
        let todos = Aquecimento.completa.etapas.flatMap(\.exercicios)
        #expect(e.etapas.count == todos.count + 1)
        #expect(e.etapas[0].passo == Passo(.aquecimento, .tempo(600), .facil))
        #expect(e.etapas.last?.passo?.intensidade == .prova)
    }

    @Test func semAquecimentoGuiadoQuandoOTreinoComecaLeve() {
        #expect(ExecucaoTreino.rotinaIndicada(para: Modelos.progressivo.treino(dose: 9000)) == nil)
        #expect(ExecucaoTreino.rotinaIndicada(para: Modelos.facil.treino(dose: 8000)) == nil)
        #expect(ExecucaoTreino.rotinaIndicada(para: Modelos.fartlek.treino(dose: 12)) == Aquecimento.curta)
        #expect(ExecucaoTreino.rotinaIndicada(para: Modelos.repeticoes400.treino(dose: 3200)) == Aquecimento.completa)
    }

    @Test func exercicioAvancaPeloRelogio() throws {
        let e0 = ExecucaoTreino(treino: Modelos.prova.treino(dose: 5000), zonas: Self.zonas, aquecimentoGuiado: true, esteira: false)
        var e = e0
        _ = e.iniciar(Self.leitura(0, v: 3))
        // Trote de 10 min, depois o primeiro exercício (parado: o movimento não anda).
        for t in 1...600 { _ = e.atualizar(Self.leitura(Double(t), v: 3)) }
        #expect(e.atual == 1)
        let primeiro = try #require(e.etapas[1].exercicio)
        let duracao = Int(primeiro.duracaoEstimada.rounded(.up))
        for t in 601...(600 + duracao) { _ = e.atualizar(Self.leitura(Double(t), v: 3, movimento: 600)) }
        #expect(e.atual == 2)
    }

    @Test func esteiraTrocaDistanciaPorTempo() throws {
        var e = ExecucaoTreino(treino: Modelos.limiarContinuo.treino(dose: 3000), zonas: Self.zonas, aquecimentoGuiado: false, esteira: true)
        let trabalho = try #require(e.etapas.first { $0.passo?.funcao == .trabalho })
        guard case let .tempo(t) = trabalho.medida else { Issue.record("na esteira devia ser por tempo"); return }
        let esperado = 3 * Self.zonas.faixa(.limiar).alvo
        #expect(abs(t - esperado) <= 5)
        #expect(trabalho.planejado == .distancia(3000))
        _ = e.iniciar(LeituraExecucao(instante: Self.zero, distancia: 0, tempoMovimento: 0, ritmoAtual: nil))
        var eventos: [EventoExecucao] = []
        for s in 1...3000 {
            eventos += e.atualizar(LeituraExecucao(instante: Self.zero.addingTimeInterval(Double(s)), distancia: 0, tempoMovimento: Double(s), ritmoAtual: nil))
        }
        #expect(!eventos.contains { if case .ritmo = $0 { return true } else { return false } })
        #expect(e.terminou)
        #expect(e.resultadoTeste == nil)
    }

    @Test func pularVoltaEEncerrar() {
        var e = ExecucaoTreino(treino: Self.tiros, zonas: Self.zonas, aquecimentoGuiado: false, esteira: false)
        _ = e.iniciar(Self.leitura(0, v: 4))
        for t in 1...50 { _ = e.atualizar(Self.leitura(Double(t), v: 4)) }
        let volta1 = e.marcarVolta(Self.leitura(50, v: 4))
        #expect(volta1 == [.volta(numero: 1, duracao: 50, distancia: 200)])
        for t in 51...80 { _ = e.atualizar(Self.leitura(Double(t), v: 4)) }
        let volta2 = e.marcarVolta(Self.leitura(80, v: 4))
        #expect(volta2 == [.volta(numero: 2, duracao: 30, distancia: 120)])
        let pulo = e.pular(Self.leitura(80, v: 4))
        #expect(pulo == [.comecouEtapa(1)])
        for t in 81...100 { _ = e.atualizar(Self.leitura(Double(t), v: 4)) }
        e.encerrar(Self.leitura(100, v: 4))
        let r = e.resultados
        #expect(r.map(\.situacao) == [.pulada, .parcial, .naoFeita, .naoFeita])
        let depois = e.atualizar(Self.leitura(101, v: 4))
        #expect(depois.isEmpty)
    }

    @Test func resultadoDoTeste() throws {
        var e = ExecucaoTreino(treino: Modelos.teste(3000), zonas: nil, aquecimentoGuiado: false, esteira: false)
        // Sem ritmos de referência, não há faixa: vale o esforço.
        #expect(e.etapas.allSatisfy { $0.faixa == nil })
        _ = Self.rodar(&e, ate: 2000, v: 3.7)
        let teste = try #require(e.resultadoTeste)
        #expect(teste.distancia == 3000)
        #expect(abs(teste.tempo - 3000 / 3.7) < 0.01)
    }

    @Test func salvaEVoltaIgual() throws {
        var e = ExecucaoTreino(treino: Modelos.intervalado800.treino(dose: 4000), zonas: Self.zonas, aquecimentoGuiado: true, esteira: false)
        _ = Self.rodar(&e, ate: 900, v: 3.5)
        let dados = try JSONEncoder().encode(e)
        let volta = try JSONDecoder().decode(ExecucaoTreino.self, from: dados)
        #expect(volta.etapas == e.etapas)
        #expect(volta.atual == e.atual)
        var a = e, b = volta
        let eventosA = a.atualizar(Self.leitura(901, v: 3.5))
        let eventosB = b.atualizar(Self.leitura(901, v: 3.5))
        #expect(eventosA == eventosB)
    }

    @Test func medidorDeRitmo() {
        let faixa = FaixaRitmo(lento: 300, rapido: 280, alvo: 290)
        #expect(SituacaoRitmo.avaliar(290, faixa: faixa) == .dentro)
        #expect(SituacaoRitmo.avaliar(310, faixa: faixa) == .lento(forte: false))
        #expect(SituacaoRitmo.avaliar(320, faixa: faixa) == .lento(forte: true))
        #expect(SituacaoRitmo.avaliar(270, faixa: faixa) == .rapido(forte: false))
        #expect(SituacaoRitmo.avaliar(260, faixa: faixa) == .rapido(forte: true))
        #expect(SituacaoRitmo.avaliar(nil, faixa: faixa) == .semDados)
        let trecho = SituacaoRitmo.faixaNoMedidor(faixa)
        #expect(trecho.lowerBound > 0 && trecho.upperBound < 1)
        #expect(SituacaoRitmo.posicao(250, faixa: faixa) == 1)
        #expect(SituacaoRitmo.posicao(400, faixa: faixa) == 0)
        #expect(SituacaoRitmo.posicao(285, faixa: faixa) > SituacaoRitmo.posicao(295, faixa: faixa))
    }

    @Test func modelosProntosExecutam() {
        for pronto in ModelosProntos.todos {
            let e = ExecucaoTreino(treino: pronto.treino, zonas: Self.zonas, aquecimentoGuiado: true, esteira: false)
            #expect(!e.etapas.isEmpty, "\(pronto.id)")
            #expect(e.duracaoEstimada > 0, "\(pronto.id)")
        }
    }
}

@Suite("Falas dos avisos de voz")
struct FalasTests {
    @Test func duracoes() {
        #expect(Fala.duracao(90) == "1 minuto e 30 segundos")
        #expect(Fala.duracao(3600) == "1 hora")
        #expect(Fala.duracao(3725) == "1 hora, 2 minutos e 5 segundos")
        #expect(Fala.duracao(20) == "20 segundos")
        #expect(Fala.duracao(600) == "10 minutos")
    }

    @Test func distancias() {
        #expect(Fala.distancia(400) == "400 metros")
        #expect(Fala.distancia(1000) == "1 quilômetro")
        #expect(Fala.distancia(5000) == "5 quilômetros")
        #expect(Fala.distancia(1600) == "1600 metros")
        #expect(Fala.distancia(12_500) == "12,5 quilômetros")
    }

    @Test func ritmos() {
        #expect(Fala.ritmo(255) == "4 e 15 por quilômetro")
        #expect(Fala.ritmo(300) == "5 minutos por quilômetro")
    }

    @Test func anuncioDeEtapa() {
        let treino = Treino(nome: "6 × 400 m", tipo: .intervalado, blocos: TextoRapidoTests.exemplo)
        let e = ExecucaoTreino(treino: treino, zonas: Zonas(vdot: 50), aquecimentoGuiado: false, esteira: false)
        #expect(Fala.etapa(e.etapas[1]).hasPrefix("Tiro 1 de 6. 400 metros, ritmo "))
        #expect(Fala.etapa(e.etapas[0]).hasPrefix("Aquecimento. 10 minutos, ritmo "))
        let semZonas = ExecucaoTreino(treino: treino, zonas: nil, aquecimentoGuiado: false, esteira: false)
        #expect(Fala.etapa(semZonas.etapas[2]) == "Recuperação 1 de 6. 1 minuto e 30 segundos. " + Intensidade.facil.testeDaFala)
    }
}
