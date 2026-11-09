import Foundation
import Testing
@testable import CrunningCore

func entrada(
    _ objetivo: Objetivo = .dezK,
    semanas: Int = 12,
    nivel: Nivel = .intermediario,
    dias: Set<Int> = [1, 3, 5, 6],
    longao: Int = 6,
    volume: Double = 30_000,
    maior: Double = 10_000,
    vdot: Double? = 45
) -> EntradaPlano {
    EntradaPlano(objetivo: objetivo, semanas: semanas, nivel: nivel, diasDisponiveis: dias, diaLongao: longao,
                 volumeAtual: volume, longaoAtual: maior, vdot: vdot)
}

@Suite("Gerador de plano")
struct PlanoTests {
    @Test func planoDe10kPassaNasTravas() throws {
        let p = GeradorPlano.gerar(entrada())
        #expect(ValidadorPlano.validar(p) == [])
        #expect(p.semanas.count == 12)
        let ultima = try #require(p.semanas.last)
        #expect(ultima.fase == .polimento)
        #expect(ultima.dias[6]?.tipo == .prova)
        #expect(abs((ultima.dias[6]?.treino.dose ?? 0) - 10_000) < 0.01)
    }

    @Test func fasesEmOrdem() {
        for objetivo in [Objetivo.cincoK, .dezK, .meia, .maratona, .condicionamento] {
            let fases = GeradorPlano.fasesDoPlano(GeradorPlano.normalizar(entrada(objetivo, semanas: 16)))
            let indices = fases.map { Fase.allCases.firstIndex(of: $0)! }
            #expect(indices == indices.sorted(), "\(objetivo)")
            #expect(fases.count == 16)
        }
    }

    @Test func deterministico() {
        #expect(GeradorPlano.gerar(entrada()) == GeradorPlano.gerar(entrada()))
    }

    @Test func maratonaComTresSemanasDePolimento() {
        let p = GeradorPlano.gerar(entrada(.maratona, semanas: 18, dias: [0, 2, 3, 5, 6], volume: 45_000, maior: 18_000))
        #expect(ValidadorPlano.validar(p) == [])
        #expect(p.semanas.suffix(3).allSatisfy { $0.fase == .polimento })
        #expect(p.semanas.filter { $0.fase == .polimento }.count == 3)
    }

    @Test func alivioPeriodicoEMaisLeve() {
        let p = GeradorPlano.gerar(entrada(.meia, semanas: 16, volume: 35_000, maior: 12_000))
        let alivios = p.semanas.filter(\.alivio)
        #expect(!alivios.isEmpty)
        #expect(alivios.allSatisfy { $0.fase != .polimento })
        for s in alivios where s.numero > 1 {
            #expect(s.volumeTreino < p.semanas[s.numero - 2].volumeTreino)
        }
    }

    @Test func volumeCresceAteOPicoSemPular() {
        let p = GeradorPlano.gerar(entrada(.maratona, semanas: 20, volume: 30_000, maior: 12_000))
        let volumes = p.semanas.map(\.volumeTreino)
        #expect((volumes.max() ?? 0) > 30_000 * 1.3)
        for (a, b) in zip([30_000.0] + volumes, volumes) { #expect(b <= a * 1.25 + 1) }
    }

    @Test func comecarACorrer() throws {
        let p = GeradorPlano.gerar(EntradaPlano(
            objetivo: .comecarACorrer, semanas: 9, nivel: .iniciante, diasDisponiveis: Set(0...6),
            diaLongao: 6, volumeAtual: 0, longaoAtual: 0
        ))
        #expect(ValidadorPlano.validar(p) == [])
        #expect(p.semanas.count == 9)
        #expect(p.semanas.allSatisfy { $0.sessoes.count == 3 })
        let ultima = try #require(p.semanas.last?.sessoes.first)
        #expect(ValidadorPlano.minutosCorrendo(ultima) == 30)
    }

    @Test func entradaRuimViraValida() {
        let e = EntradaPlano(objetivo: .dezK, semanas: 99, nivel: .avancado, diasDisponiveis: [9, -1], diaLongao: 9,
                             volumeAtual: -5, longaoAtual: -1, vdot: 300, tetoProgressao: 0.9)
        let n = GeradorPlano.normalizar(e)
        #expect(n.semanas == 30)
        #expect(n.diasDisponiveis.count >= 2 && n.diasDisponiveis.allSatisfy { (0...6).contains($0) })
        #expect(n.diasDisponiveis.contains(n.diaLongao))
        #expect(n.vdot == nil)
        #expect(n.tetoProgressao == RegrasPlano.tetoProgressaoMaximo)
        #expect(ValidadorPlano.validar(GeradorPlano.gerar(e)) == [])
    }

    @Test func porQueEstePlano() {
        let comProva = GeradorPlano.gerar(entrada())
        #expect(comProva.regras.contains { $0.hasPrefix("Polimento") })
        let semReferencia = GeradorPlano.gerar(entrada(vdot: nil))
        #expect(semReferencia.regras.contains { $0.contains("esforço percebido") })
    }

    @Test func maratonaEmQuatroSemanasNaoEhViavel() {
        let e = entrada(.maratona, semanas: 4, volume: 30_000, maior: 8_000, vdot: nil)
        guard case let .curto(minimas, motivo) = GeradorPlano.viabilidade(e) else {
            Issue.record("maratona em 4 semanas deveria ser curta")
            return
        }
        #expect(minimas >= 12)
        #expect(motivo.contains("longão"))
        #expect(GeradorPlano.viabilidade(entrada(.maratona, semanas: minimas, volume: 30_000, maior: 8_000, vdot: nil)) == .viavel)
        #expect(GeradorPlano.viabilidade(entrada(.condicionamento, semanas: 4)) == .viavel)
    }

    @Test func longaoMuitoCurtoParaMaratonaNaoEhRecomendado() {
        if case .naoRecomendado = GeradorPlano.viabilidade(entrada(.maratona, semanas: 30, nivel: .iniciante, volume: 10_000, maior: 3_000)) {
        } else {
            Issue.record("maratona a partir de 3 km deveria não ser recomendada")
        }
    }

    @Test(arguments: [Objetivo.cincoK, .dezK, .meia, .maratona, .condicionamento])
    func longaoEhAMaiorCorrida(objetivo: Objetivo) {
        let p = GeradorPlano.gerar(entrada(objetivo, semanas: 16, dias: [0, 1, 3, 4, 6], volume: 40_000, maior: 14_000))
        #expect(ValidadorPlano.validar(p) == [])
        for semana in p.semanas {
            guard let longao = semana.sessoes.first(where: { $0.tipo == .longao }) else { continue }
            for s in semana.sessoes where s.tipo == .facil || s.tipo == .recuperacao {
                #expect(s.distancia <= longao.distancia * RegrasPlano.fracaoFacilDoLongao + 100, "semana \(semana.numero)")
            }
        }
    }

    @Test func volumeLimitadoPeloLongaoTemAlerta() {
        let p = GeradorPlano.gerar(entrada(.dezK, semanas: 12, volume: 30_000, maior: 5_000))
        #expect(GeradorPlano.alertas(p).contains { $0.hasPrefix("A primeira semana") })
        #expect((p.semanas.first?.volumeTreino ?? 0) < 30_000 * 0.8)
        let volumes = p.semanas.map(\.volumeTreino)
        #expect((volumes.max() ?? 0) > (volumes.first ?? 0) * 1.5)
    }

    @Test func meiaEMaratonaComLongaoDeVerdade() {
        let meia = GeradorPlano.gerar(entrada(.meia, semanas: 16, dias: [0, 1, 3, 4, 6], volume: 35_000, maior: 12_000))
        #expect((meia.semanas.map(\.maiorCorrida).max() ?? 0) >= 16_000)
        let maratona = GeradorPlano.gerar(entrada(.maratona, semanas: 18, dias: [0, 1, 3, 4, 6], volume: 45_000, maior: 18_000))
        #expect((maratona.semanas.map(\.maiorCorrida).max() ?? 0) >= 23_000)
        #expect(ValidadorPlano.validar(meia) == [])
        #expect(ValidadorPlano.validar(maratona) == [])
    }

    @Test func moverQualidadeParaPertoDoLongaoEhRecusado() throws {
        let p = GeradorPlano.gerar(entrada(semanas: 12))
        let semana = try #require(p.semanas.first { $0.fase == .construcao })
        let diaQualidade = try #require(semana.dias.indices.first { semana.dias[$0]?.ehQualidade ?? false })
        #expect(throws: ErroOperacao.self) {
            try OperacoesPlano.mover(p, semana: semana.numero, de: diaQualidade, para: 5)
        }
    }

    @Test func provaAdiantadaMantemOPolimento() throws {
        let p = GeradorPlano.gerar(entrada(.meia, semanas: 14, volume: 32_000, maior: 12_000))
        let novo = try OperacoesPlano.reajustar(p, aPartirDaSemana: 6, semanasRestantes: 3)
        #expect(novo.semanas.count == 8)
        #expect(novo.semanas.last?.temProva == true)
        #expect(novo.semanas.suffix(2).allSatisfy { $0.fase == .polimento })
        #expect(ValidadorPlano.validar(novo) == [])
    }

    @Test func retomadaComecaMaisBaixoESobeAosPoucos() throws {
        let p = GeradorPlano.gerar(entrada(.maratona, semanas: 20, volume: 40_000, maior: 15_000))
        let novo = try OperacoesPlano.retomarAposPausa(p, aPartirDaSemana: 8, diasParado: 20)
        let antes = novo.semanas[6].volumeTreino
        #expect(novo.semanas[7].volumeTreino <= antes * 0.6)
        for i in 8..<novo.semanas.count where novo.semanas[i].fase != .polimento && !novo.semanas[i].alivio {
            #expect(novo.semanas[i].volumeTreino <= novo.semanas[i - 1].volumeTreino * 1.25 + 1)
        }
        #expect(ValidadorPlano.validar(novo) == [])
    }
}

@Suite("Adaptação do plano")
struct AdaptacaoTests {
    func tipo(_ r: Recomendacao) -> String {
        switch r {
        case .seguir: "seguir"
        case .retomar: "retomar"
        case let .parar(medico, _): medico ? "parar-medico" : "parar"
        case .opcionalLeve: "leve"
        case .reajustarPlano: "reajustar"
        case .perguntarAjusteDeRitmos: "ritmos"
        case .proporAlivio: "alivio"
        case .pararPorDor: "dor"
        }
    }

    @Test func regras() {
        #expect(tipo(Adaptacao.avaliar(.perdeuTreino)) == "seguir")
        #expect(tipo(Adaptacao.avaliar(.ausencia(dias: 3))) == "seguir")
        #expect(Adaptacao.avaliar(.ausencia(dias: 10)) == .retomar(fatorInicial: 0.75, ritmosPorEsforco: false,
                                                                       mensagem: Adaptacao.avaliar(.ausencia(dias: 10)).mensagem))
        if case let .retomar(fator, porEsforco, _) = Adaptacao.avaliar(.ausencia(dias: 40)) {
            #expect(fator == 0.33)
            #expect(porEsforco)
        } else {
            Issue.record("40 dias parado deveria retomar")
        }
        #expect(tipo(Adaptacao.avaliar(.doenca(febre: true, sintomasAbaixoDoPescoco: false))) == "parar-medico")
        #expect(tipo(Adaptacao.avaliar(.doenca(febre: false, sintomasAbaixoDoPescoco: true))) == "parar")
        #expect(tipo(Adaptacao.avaliar(.doenca(febre: false, sintomasAbaixoDoPescoco: false))) == "leve")
        #expect(tipo(Adaptacao.avaliar(.provaMudou(semanasAteProva: 8))) == "reajustar")
        #expect(tipo(Adaptacao.avaliar(.foraDoRitmo(treinosSeguidos: 2, maisRapido: true))) == "seguir")
        #expect(tipo(Adaptacao.avaliar(.foraDoRitmo(treinosSeguidos: 3, maisRapido: true))) == "ritmos")
        #expect(tipo(Adaptacao.avaliar(.esforcoAltoEmFaceis(seguidas: 2, esforco: 6))) == "alivio")
        #expect(tipo(Adaptacao.avaliar(.esforcoAltoEmFaceis(seguidas: 1, esforco: 9))) == "seguir")
        #expect(tipo(Adaptacao.avaliar(.esforcoAltoEmFaceis(seguidas: 3, esforco: 5))) == "seguir")
        #expect(tipo(Adaptacao.avaliar(.dor(mudaAPassada: true, persiste: false))) == "dor")
        #expect(tipo(Adaptacao.avaliar(.dor(mudaAPassada: false, persiste: true))) == "dor")
        #expect(tipo(Adaptacao.avaliar(.dor(mudaAPassada: false, persiste: false))) == "seguir")
    }

    @Test func fatoresDeRetomada() {
        #expect(Adaptacao.fatorRetomada(diasParado: 5) == 1.0)
        #expect(Adaptacao.fatorRetomada(diasParado: 6) == 0.75)
        #expect(Adaptacao.fatorRetomada(diasParado: 13) == 0.75)
        #expect(Adaptacao.fatorRetomada(diasParado: 14) == 0.50)
        #expect(Adaptacao.fatorRetomada(diasParado: 27) == 0.50)
        #expect(Adaptacao.fatorRetomada(diasParado: 28) == 0.33)
    }
}
