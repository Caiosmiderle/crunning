import ActivityKit
import CrunningCore
import Foundation

/// Live Activity da corrida: começa com a corrida, atualiza com moderação (troca de bloco,
/// pausa, ou a cada 10 s) e termina ao finalizar ou descartar. Sem push: quem atualiza é o
/// próprio app, que continua vivo em segundo plano pela localização.
@MainActor
final class AtividadeAoVivo {
    static let intervaloMinimo: TimeInterval = 10

    private var atividade: Activity<TreinoAtividadeAtributos>?
    private var ultimoEnvio = Date.distantPast
    private var ultimaChave = ""

    var ativa: Bool { atividade != nil }

    func iniciar(titulo: String, esteira: Bool, estado: TreinoAtividadeAtributos.ContentState) {
        guard atividade == nil else { return }
        if let existente = Activity<TreinoAtividadeAtributos>.activities.first {
            atividade = existente
            atualizar(estado, forcar: true)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            atividade = try Activity.request(
                attributes: TreinoAtividadeAtributos(tituloTreino: titulo, esteira: esteira),
                content: ActivityContent(state: estado, staleDate: nil)
            )
            ultimoEnvio = .now
            ultimaChave = Self.chave(estado)
        } catch {
            // Live Activities desligadas nos Ajustes ou limite do sistema: a corrida segue sem ela.
        }
    }

    func atualizar(_ estado: TreinoAtividadeAtributos.ContentState, forcar: Bool = false) {
        guard let atividade else { return }
        let chave = Self.chave(estado)
        let agora = Date.now
        guard forcar || chave != ultimaChave || agora.timeIntervalSince(ultimoEnvio) >= Self.intervaloMinimo else { return }
        ultimoEnvio = agora
        ultimaChave = chave
        let conteudo = ActivityContent(state: estado, staleDate: nil)
        Task { await atividade.update(conteudo) }
    }

    func encerrar() {
        let todas = Activity<TreinoAtividadeAtributos>.activities
        atividade = nil
        for a in todas {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Mudanças que justificam atualizar na hora: bloco, pausa e o texto do que falta.
    private static func chave(_ e: TreinoAtividadeAtributos.ContentState) -> String {
        "\(e.nomeBloco)|\(e.detalhe ?? "")|\(e.pausada)"
    }
}
