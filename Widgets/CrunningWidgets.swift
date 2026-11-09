import ActivityKit
import CrunningCore
import SwiftUI
import WidgetKit

@main
struct CrunningWidgets: WidgetBundle {
    init() {
        // A extensão roda em outro processo: segue o idioma do iPhone como o app.
        Idioma.atual = Idioma.doSistema(Bundle.main.preferredLocalizations)
        Formatador.separadorDecimal = Idioma.atual == .ingles ? "." : ","
    }

    var body: some Widget {
        TreinoLiveActivity()
    }
}

private let verdeLogo = Color(red: 0x8B / 255, green: 0xE1 / 255, blue: 0x05 / 255)

private func cor(_ hex: UInt32) -> Color {
    Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
}

/// Live Activity da corrida: bloco atual, o que falta (cronômetro que roda sozinho ou distância),
/// distância e ritmo. Tela de bloqueio e Dynamic Island (compacta, expandida e mínima).
struct TreinoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TreinoAtividadeAtributos.self) { contexto in
            TelaDeBloqueioView(contexto: contexto)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { contexto in
            let estado = contexto.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(estado.nomeBloco, systemImage: estado.pausada ? "pause.fill" : "figure.run")
                            .font(.headline)
                            .foregroundStyle(cor(estado.corHex))
                            .lineLimit(1)
                        if let detalhe = estado.detalhe {
                            Text(detalhe).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if !contexto.attributes.esteira {
                            Text(Formatador.distancia(estado.distanciaMetros))
                                .font(.headline)
                                .monospacedDigit()
                        }
                        if let ritmo = estado.ritmoSegundosPorKm {
                            Text(Formatador.ritmo(segundosPorKm: ritmo) + " /km")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Restante(estado: estado)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        if estado.progresso > 0 {
                            ProgressView(value: min(max(estado.progresso, 0), 1))
                                .tint(cor(estado.corHex))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: estado.pausada ? "pause.fill" : "figure.run")
                    .foregroundStyle(cor(estado.corHex))
            } compactTrailing: {
                Restante(estado: estado)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: estado.pausada ? "pause.fill" : "figure.run")
                    .foregroundStyle(cor(estado.corHex))
            }
            .keylineTint(cor(estado.corHex))
        }
    }
}

/// O que falta no bloco: cronômetro para trás (bloco por tempo), distância (bloco por distância),
/// tempo em movimento (corrida livre) ou o tempo parado (pausa).
struct Restante: View {
    let estado: TreinoAtividadeAtributos.ContentState

    var body: some View {
        Group {
            if let fim = estado.fimDoBloco {
                Text(timerInterval: Date.now...max(fim, Date.now), countsDown: true)
            } else if let texto = estado.restanteTexto {
                Text(texto)
            } else if let inicio = estado.inicioCronometro {
                Text(timerInterval: inicio...Date.distantFuture, countsDown: false)
            } else if let parado = estado.tempoParado {
                Text(Formatador.duracao(parado))
            } else {
                Text("--:--")
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.center)
    }
}

struct TelaDeBloqueioView: View {
    let contexto: ActivityViewContext<TreinoAtividadeAtributos>

    var body: some View {
        let estado = contexto.state
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(contexto.attributes.tituloTreino)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if estado.pausada {
                    Label("Pausado", systemImage: "pause.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow)
                } else {
                    Image(systemName: "figure.run").foregroundStyle(verdeLogo)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(estado.nomeBloco)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(cor(estado.corHex))
                        .lineLimit(1)
                    if let detalhe = estado.detalhe {
                        Text(detalhe)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Restante(estado: estado)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .frame(maxWidth: 150, alignment: .trailing)
            }
            HStack {
                if !contexto.attributes.esteira {
                    Text(Formatador.distancia(estado.distanciaMetros))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
                if let ritmo = estado.ritmoSegundosPorKm {
                    Text(Formatador.ritmo(segundosPorKm: ritmo) + " /km")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
            if estado.progresso > 0 {
                ProgressView(value: min(max(estado.progresso, 0), 1))
                    .tint(cor(estado.corHex))
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}
