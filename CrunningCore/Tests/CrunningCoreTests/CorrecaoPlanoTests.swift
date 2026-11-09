import Foundation
import Testing
@testable import CrunningCore

@Suite("Correções do plano depois da análise")
struct CorrecaoPlanoTests {
    static let dezK = GeradorPlano.gerar(EntradaPlano(
        objetivo: .dezK, semanas: 12, nivel: .intermediario, diasDisponiveis: [1, 3, 5, 6], diaLongao: 6,
        volumeAtual: 30_000, longaoAtual: 10_000, vdot: 45
    ))

    @Test func aliviarSemana() throws {
        let antes = Self.dezK
        let depois = try CorrecaoPlano.aliviarSemana(semana: 5).aplicar(antes)
        #expect(ValidadorPlano.validar(depois) == [])
        #expect(depois.semanas[4].alivio)
        #expect(depois.semanas[4].volumeTreino < antes.semanas[4].volumeTreino)
        let comparacao = ComparacaoPlano(antes: antes, depois: depois)
        #expect(comparacao.mudouAlgo)
        #expect(comparacao.linhas.contains { $0.semana == 5 })
        #expect(comparacao.linhas.allSatisfy { $0.semana >= 5 })
    }

    @Test func reduzirSemana() throws {
        let antes = Self.dezK
        let depois = try CorrecaoPlano.reduzirSemana(semana: 4, fator: 0.9).aplicar(antes)
        #expect(ValidadorPlano.validar(depois) == [])
        #expect(depois.semanas[3].volumeTreino < antes.semanas[3].volumeTreino)
    }

    @Test func refazComOutrasEntradas() throws {
        let maisSemanas = try CorrecaoPlano.mudarSemanas(16).aplicar(Self.dezK)
        #expect(maisSemanas.semanas.count == 16)
        #expect(ValidadorPlano.validar(maisSemanas) == [])

        let menosDias = try CorrecaoPlano.mudarDias([1, 3, 6], longao: 6).aplicar(Self.dezK)
        #expect(menosDias.entrada.diasDisponiveis == [1, 3, 6])
        for semana in menosDias.semanas {
            for (dia, sessao) in semana.dias.enumerated() where sessao != nil {
                #expect([1, 3, 6].contains(dia), "semana \(semana.numero)")
            }
        }

        let tetoMenor = try CorrecaoPlano.mudarTeto(0.07).aplicar(Self.dezK)
        #expect(tetoMenor.entrada.tetoProgressao == 0.07)
        #expect(ValidadorPlano.validar(tetoMenor) == [])
    }

    @Test func recusaOQueNaoCabe() {
        do {
            _ = try CorrecaoPlano.mudarSemanas(2).aplicar(Self.dezK)
            Issue.record("Aceitou 2 semanas para 10 km")
        } catch let ErroCorrecao.inviavel(motivo) {
            #expect(!motivo.isEmpty)
        } catch {
            Issue.record("Erro inesperado: \(error)")
        }
        #expect(throws: ErroCorrecao.self) { try CorrecaoPlano.reduzirSemana(semana: 3, fator: 0.3).aplicar(Self.dezK) }
        #expect(throws: ErroCorrecao.self) { try CorrecaoPlano.mudarDias([2], longao: 2).aplicar(Self.dezK) }
        #expect(throws: ErroCorrecao.self) { try CorrecaoPlano.aliviarSemana(semana: 40).aplicar(Self.dezK) }
        #expect(throws: ErroCorrecao.self) { try CorrecaoPlano.mudarTeto(0.5).aplicar(Self.dezK) }
    }

    /// Qualquer troca de dias ou de treino ou devolve um plano que passa nas travas, ou é recusada.
    @Test func nuncaDevolvePlanoInvalido() {
        for semana in 1...4 {
            for de in 0..<7 {
                for para in 0..<7 where para != de {
                    if let novo = try? CorrecaoPlano.moverTreino(semana: semana, de: de, para: para).aplicar(Self.dezK) {
                        #expect(ValidadorPlano.validar(novo) == [], "semana \(semana): \(de) -> \(para)")
                    }
                }
                if let novo = try? CorrecaoPlano.trocarTreino(semana: semana, dia: de).aplicar(Self.dezK) {
                    #expect(ValidadorPlano.validar(novo) == [], "semana \(semana): trocar \(de)")
                }
            }
        }
    }

    @Test func semMudancaNaoTemLinhas() {
        let c = ComparacaoPlano(antes: Self.dezK, depois: Self.dezK)
        #expect(!c.mudouAlgo)
        #expect(c.linhas.isEmpty)
    }

    @Test func descricoes() {
        #expect(CorrecaoPlano.aliviarSemana(semana: 5).descricao == "Fazer da semana 5 uma semana de alívio")
        #expect(CorrecaoPlano.reduzirSemana(semana: 3, fator: 0.85).descricao == "Reduzir a semana 3 para 85% do volume")
        #expect(CorrecaoPlano.moverTreino(semana: 2, de: 1, para: 2).descricao == "Semana 2: trocar terça com quarta")
    }
}
