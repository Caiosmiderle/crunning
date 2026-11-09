import Foundation
import Testing
@testable import CrunningCore

/// Centenas de planos e mudanças aleatórias (com semente fixa, para repetir igual)
/// sempre respeitam as travas de docs/CIENCIA.md.
@Suite("Propriedades do plano")
struct PlanoPropriedadesTests {
    static func entradaAleatoria(_ g: inout GeradorAleatorio) -> EntradaPlano {
        let objetivos: [Objetivo] = [.cincoK, .dezK, .meia, .maratona, .condicionamento, .comecarACorrer, .prova(distanciaMetros: 15_000)]
        var dias = Set<Int>()
        let quantidade = Int.random(in: 1...7, using: &g)
        while dias.count < quantidade { dias.insert(Int.random(in: 0...6, using: &g)) }
        return EntradaPlano(
            objetivo: objetivos[Int.random(in: 0..<objetivos.count, using: &g)],
            semanas: Int.random(in: 1...24, using: &g),
            nivel: Nivel.allCases[Int.random(in: 0..<Nivel.allCases.count, using: &g)],
            diasDisponiveis: dias,
            diaLongao: Int.random(in: 0...7, using: &g),
            volumeAtual: Double.random(in: 0...110_000, using: &g),
            longaoAtual: Double.random(in: 0...36_000, using: &g),
            vdot: Bool.random(using: &g) ? Double.random(in: 22...75, using: &g) : nil,
            tetoProgressao: Double.random(in: 0...0.3, using: &g)
        )
    }

    @Test(arguments: 0..<8)
    func planosAleatoriosRespeitamAsTravas(lote: Int) {
        var g = GeradorAleatorio(semente: UInt64(1000 + lote))
        for _ in 0..<50 {
            let e = Self.entradaAleatoria(&g)
            let plano = GeradorPlano.gerar(e)
            let erros = ValidadorPlano.validar(plano)
            #expect(erros.isEmpty, "\(plano.entrada): \(erros.map(\.description))")
            #expect(plano.semanas.count == GeradorPlano.normalizar(e).semanas)
            if let distancia = plano.entrada.objetivo.distanciaProva {
                let prova = plano.semanas.last?.sessoes.first(where: \.ehProva)
                #expect(abs((prova?.treino.dose ?? 0) - distancia) < 0.01)
            }
        }
    }

    @Test(arguments: 0..<6)
    func mudancasAleatoriasMantemAsTravas(lote: Int) {
        var g = GeradorAleatorio(semente: UInt64(5000 + lote))
        for _ in 0..<25 {
            var plano = GeradorPlano.gerar(Self.entradaAleatoria(&g))
            for _ in 0..<6 {
                let semana = Int.random(in: 1...plano.semanas.count, using: &g)
                let operacao = Int.random(in: 0..<6, using: &g)
                do {
                    let novo: Plano
                    switch operacao {
                    case 0:
                        novo = try OperacoesPlano.mover(plano, semana: semana, de: Int.random(in: 0...6, using: &g), para: Int.random(in: 0...6, using: &g))
                    case 1:
                        novo = try OperacoesPlano.trocarPorEquivalente(plano, semana: semana, dia: Int.random(in: 0...6, using: &g))
                    case 2:
                        novo = try OperacoesPlano.reduzirCarga(plano, semana: semana, fator: Double.random(in: 0.5...0.95, using: &g))
                    case 3:
                        novo = try OperacoesPlano.inserirAlivio(plano, semana: semana)
                    case 4:
                        novo = try OperacoesPlano.reajustar(plano, aPartirDaSemana: semana, semanasRestantes: Int.random(in: 1...16, using: &g))
                    default:
                        novo = try OperacoesPlano.retomarAposPausa(plano, aPartirDaSemana: semana, diasParado: Int.random(in: 0...60, using: &g))
                    }
                    let erros = ValidadorPlano.validar(novo)
                    #expect(erros.isEmpty, "operação \(operacao): \(erros.map(\.description))")
                    plano = novo
                } catch let ErroOperacao.violaria(erros) {
                    // Mover e trocar podem ser recusados; as operações que refazem semanas
                    // com o gerador nunca deveriam produzir um plano inválido.
                    #expect(operacao <= 1, "operação \(operacao) refez semanas inválidas: \(erros.map(\.description))")
                } catch {
                    // Recusas legítimas: semana sem treino, sem equivalente, não se aplica.
                }
            }
        }
    }

    @Test func zonasSempreOrdenadas() throws {
        var g = GeradorAleatorio(semente: 77)
        for _ in 0..<200 {
            let z = try #require(Zonas(vdot: Double.random(in: 15...90, using: &g)))
            #expect(z.faixa(.facil).alvo > z.faixa(.limiar).alvo)
            #expect(z.faixa(.limiar).alvo > z.faixa(.intervalado).alvo)
            #expect(z.faixa(.intervalado).alvo > z.faixa(.repeticoes).alvo)
        }
    }
}
