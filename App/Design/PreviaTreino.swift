import CrunningCore
import SwiftUI

/// Prévia de um treino ao segurar o dedo (menu de contexto): tipo, nome, totais, linha do tempo
/// e a planilha dos trechos, sem abrir a tela.
struct PreviaTreino: View {
    let treino: Treino
    var subtitulo: String? = nil
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros

    var body: some View {
        let zonas = ZonasDoUsuario.atuais()
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(treino.tipo.cor).frame(width: 10, height: 10)
                Text(treino.tipo.nome)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let subtitulo {
                    Text("· " + subtitulo)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Text(treino.nome)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(TextoTreino.totais(treino, zonas: zonas, unidade: unidade))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            LinhaDoTempoTreino(blocos: treino.blocos, zonas: zonas, espessura: 14)
            PlanilhaTreino(treino: treino, zonas: zonas, unidade: unidade)
        }
        .padding(20)
        .frame(width: 340, alignment: .leading)
        .background { FundoView() }
    }
}

extension View {
    /// Menu de contexto com a prévia do treino em cima (sem treino, só o menu).
    @ViewBuilder
    func menuComPrevia<Itens: View>(_ treino: Treino?, subtitulo: String? = nil, @ViewBuilder itens: () -> Itens) -> some View {
        let menu = itens()
        if let treino {
            contextMenu {
                menu
            } preview: {
                PreviaTreino(treino: treino, subtitulo: subtitulo)
            }
        } else {
            contextMenu { menu }
        }
    }
}
