import Foundation
import Testing
@testable import CrunningCore

/// O que a revisão de treinador dos relatórios pediu (docs/CIENCIA.md, "Progressão de carga e longão"
/// e "Treinos de qualidade"), conferido nos cenários do relatório.
@Suite("Revisão de treinador")
struct RevisaoTreinadorTests {
    static let planos = RelatorioPlanosTests.cenarios.map { ($0.0, GeradorPlano.gerar($0.1)) }

    @Test func cenariosPassamNasTravas() {
        for (nome, plano) in Self.planos { #expect(ValidadorPlano.validar(plano) == [], "\(nome)") }
    }

    @Test func usaOsDiasQueAPessoaDeu() throws {
        let (nome, plano) = try #require(Self.planos.first { $0.0.hasPrefix("Maratona em 16 semanas, avançado") })
        for semana in plano.semanas where semana.fase != .polimento {
            #expect(semana.corridas == 6, "\(nome), semana \(semana.numero)")
        }
    }

    @Test func recuperacaoCurta() {
        for (nome, plano) in Self.planos {
            for semana in plano.semanas {
                for s in semana.sessoes where s.tipo == .recuperacao {
                    #expect(s.duracao <= RegrasPlano.duracaoMaximaRecuperacao + 1, "\(nome), semana \(semana.numero)")
                }
            }
        }
    }

    @Test func semTreinoDeEnfeite() {
        for (nome, plano) in Self.planos {
            for semana in plano.semanas {
                for s in semana.sessoes {
                    guard let id = s.treino.modeloID, let modelo = Modelos.modelo(id: id), let dose = s.treino.dose,
                          modelo.tipoDose == .distanciaDeTrabalho else { continue }
                    #expect(dose >= GeradorPlano.doseMinima(modelo), "\(nome), semana \(semana.numero): \(id) \(dose)")
                }
            }
        }
    }

    @Test func picoNaoChegaNoComeco() throws {
        for prefixo in ["Maratona em 16 semanas, avançado", "Maratona em 18 semanas", "Meia em 14 semanas"] {
            let (nome, plano) = try #require(Self.planos.first { $0.0.hasPrefix(prefixo) })
            let antes = plano.semanas.filter { $0.fase != .polimento }
            let maior = antes.map(\.volumeTreino).max() ?? 0
            let primeira = try #require(antes.firstIndex { $0.volumeTreino >= 0.97 * maior })
            #expect(primeira + 1 >= antes.count / 2, "\(nome): pico na semana \(primeira + 1) de \(antes.count)")
        }
    }

    @Test func volumeNaoEstagnaNos10K() throws {
        let (nome, plano) = try #require(Self.planos.first { $0.0.hasPrefix("10 km em 12 semanas") })
        let volumes = plano.semanas.filter { $0.fase != .polimento }.map(\.volumeTreino)
        #expect((volumes.max() ?? 0) >= 45_000, "\(nome): \(volumes)")
    }
}
