import ActivityKit
import CrunningCore
import SwiftUI
import WidgetKit

@main
struct CrunningWidgets: WidgetBundle {
    var body: some Widget {
        TreinoLiveActivity()
    }
}

/// Esqueleto da Live Activity. Entra agora para testar cedo a assinatura da
/// extensão no Sideloadly; o conteúdo completo vem na fase 6.
struct TreinoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TreinoAtividadeAtributos.self) { contexto in
            TelaDeBloqueioView(contexto: contexto)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { contexto in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(contexto.state.nomeBloco, systemImage: "figure.run")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Formatador.distancia(contexto.state.distanciaMetros))
                        .font(.headline)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let fim = contexto.state.fimDoBloco {
                        Text(timerInterval: Date.now...max(fim, Date.now), countsDown: true)
                            .font(.title2)
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.run")
                    .foregroundStyle(Color(red: 0.545, green: 0.882, blue: 0.02))
            } compactTrailing: {
                Text(Formatador.distancia(contexto.state.distanciaMetros, casas: 1))
                    .font(.caption)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.run")
            }
        }
    }
}

struct TelaDeBloqueioView: View {
    let contexto: ActivityViewContext<TreinoAtividadeAtributos>

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(contexto.attributes.tituloTreino)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(contexto.state.nomeBloco)
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatador.distancia(contexto.state.distanciaMetros))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                if let ritmo = contexto.state.ritmoSegundosPorKm {
                    Text(Formatador.ritmo(segundosPorKm: ritmo) + " /km")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }
}
