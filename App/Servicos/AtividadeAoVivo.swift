import ActivityKit
import CrunningCore
import Foundation

/// Live Activity da corrida: começa com a corrida, atualiza com moderação (troca de bloco,
/// pausa, ou a cada 10 s) e termina ao finalizar ou descartar. Sem push: quem atualiza é o
/// próprio app, que continua vivo em segundo plano pela localização.
@MainActor
final class AtividadeAoVivo {
    static let intervaloMinimo: TimeInterval = 10

    /// Só o id: o objeto `Activity` não é Sendable, então cada tarefa o busca de novo pelo id.
    private var atividadeID: String?
    private var ultimoEnvio = Date.distantPast
    private var ultimaChave = ""

    var ativa: Bool { atividadeID != nil }

    func iniciar(titulo: String, esteira: Bool, estado: TreinoAtividadeAtributos.ContentState) {
        guard atividadeID == nil else { return }
        if let existente = Activity<TreinoAtividadeAtributos>.activities.first?.id {
            atividadeID = existente
            atualizar(estado, forcar: true)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            let nova = try Activity.request(
                attributes: TreinoAtividadeAtributos(tituloTreino: titulo, esteira: esteira),
                content: ActivityContent(state: estado, staleDate: nil)
            )
            atividadeID = nova.id
            ultimoEnvio = .now
            ultimaChave = Self.chave(estado)
        } catch {
            // Live Activities desligadas nos Ajustes ou limite do sistema: a corrida segue sem ela.
        }
    }

    func atualizar(_ estado: TreinoAtividadeAtributos.ContentState, forcar: Bool = false) {
        guard let id = atividadeID else { return }
        let chave = Self.chave(estado)
        let agora = Date.now
        guard forcar || chave != ultimaChave || agora.timeIntervalSince(ultimoEnvio) >= Self.intervaloMinimo else { return }
        ultimoEnvio = agora
        ultimaChave = chave
        Task.detached {
            for a in Activity<TreinoAtividadeAtributos>.activities where a.id == id {
                await a.update(ActivityContent(state: estado, staleDate: nil))
            }
        }
    }

    func encerrar() {
        atividadeID = nil
        Task.detached {
            for a in Activity<TreinoAtividadeAtributos>.activities {
                await a.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Mudanças que justificam atualizar na hora: bloco, pausa e o texto do que falta.
    private static func chave(_ e: TreinoAtividadeAtributos.ContentState) -> String {
        "\(e.nomeBloco)|\(e.detalhe ?? "")|\(e.pausada)"
    }
}
