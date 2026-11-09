import Foundation
import Testing
@testable import CrunningCore

/// Não testa nada: imprime planos de cenários típicos no log do CI (linhas "RELATORIO|"),
/// para a revisão de treinador de cada mudança no motor.
@Suite("Relatório de planos")
struct RelatorioPlanosTests {
    static let nomesDias = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sab", "Dom"]

    static let cenarios: [(String, EntradaPlano)] = [
        ("Maratona em 4 semanas, 30 km, maior 8 km", EntradaPlano(objetivo: .maratona, semanas: 4, nivel: .intermediario, diasDisponiveis: [1, 3, 5, 6], diaLongao: 6, volumeAtual: 30_000, longaoAtual: 8_000)),
        ("10 km em 12 semanas, 4 dias, 30 km, maior 10 km", EntradaPlano(objetivo: .dezK, semanas: 12, nivel: .intermediario, diasDisponiveis: [1, 3, 5, 6], diaLongao: 6, volumeAtual: 30_000, longaoAtual: 10_000, vdot: 45)),
        ("Meia em 14 semanas, 5 dias, 35 km, maior 12 km", EntradaPlano(objetivo: .meia, semanas: 14, nivel: .intermediario, diasDisponiveis: [0, 1, 3, 4, 6], diaLongao: 6, volumeAtual: 35_000, longaoAtual: 12_000, vdot: 45)),
        ("Maratona em 18 semanas, 5 dias, 45 km, maior 18 km", EntradaPlano(objetivo: .maratona, semanas: 18, nivel: .intermediario, diasDisponiveis: [0, 1, 3, 4, 6], diaLongao: 6, volumeAtual: 45_000, longaoAtual: 18_000, vdot: 45)),
        ("5 km em 8 semanas, iniciante, 3 dias, 15 km, maior 5 km", EntradaPlano(objetivo: .cincoK, semanas: 8, nivel: .iniciante, diasDisponiveis: [1, 3, 6], diaLongao: 6, volumeAtual: 15_000, longaoAtual: 5_000)),
        ("Sem prova, 10 semanas, avançado, 6 dias, 60 km, maior 16 km", EntradaPlano(objetivo: .condicionamento, semanas: 10, nivel: .avancado, diasDisponiveis: Set(0...5), diaLongao: 5, volumeAtual: 60_000, longaoAtual: 16_000, vdot: 55)),
        ("Maratona em 16 semanas, avançado, 6 dias, 70 km, maior 25 km", EntradaPlano(objetivo: .maratona, semanas: 16, nivel: .avancado, diasDisponiveis: [0, 1, 2, 3, 4, 6], diaLongao: 6, volumeAtual: 70_000, longaoAtual: 25_000, vdot: 55)),
        ("10 km em 6 semanas, 3 dias, 20 km, maior 6 km", EntradaPlano(objetivo: .dezK, semanas: 6, nivel: .intermediario, diasDisponiveis: [1, 3, 6], diaLongao: 6, volumeAtual: 20_000, longaoAtual: 6_000)),
        ("Começar a correr", EntradaPlano(objetivo: .comecarACorrer, semanas: 9, nivel: .iniciante, diasDisponiveis: Set(0...6), diaLongao: 6, volumeAtual: 0, longaoAtual: 0)),
    ]

    static func km(_ m: Double) -> String { String(format: "%.1f", m / 1000) }

    @Test func imprimirCenarios() {
        for (nome, entrada) in Self.cenarios {
            let plano = GeradorPlano.gerar(entrada)
            print("RELATORIO|=== \(nome)")
            for aviso in GeradorPlano.alertas(plano) { print("RELATORIO|  ALERTA: \(aviso)") }
            for semana in plano.semanas {
                let dias = semana.dias.enumerated().map { dia, sessao -> String in
                    guard let s = sessao else { return "\(Self.nomesDias[dia]) -" }
                    return "\(Self.nomesDias[dia]) \(s.treino.nome) \(Self.km(s.distancia))"
                }
                let prova = semana.temProva ? " + prova" : ""
                print("RELATORIO|S\(semana.numero) \(semana.fase.rawValue)\(semana.alivio ? "/alivio" : "") treino \(Self.km(semana.volumeTreino))\(prova) | " + dias.joined(separator: " | "))
            }
        }
    }
}
