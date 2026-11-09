import CrunningCore
import SwiftUI

/// A corrida minimizada: uma barra acima das abas (o acessório da TabView) com a etapa, o que
/// falta e o botão de pausa. A gravação, a voz e a Live Activity seguem iguais; tocar na barra
/// volta para a tela da corrida.
struct MiniCorridaView: View {
    let gravador: GravadorCorrida
    let estadoApp: EstadoApp
    @Environment(\.tabViewBottomAccessoryPlacement) var posicao
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(cor)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(titulo)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if posicao != .inline {
                        Text(detalhe)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Text(numero)
                    .font(.headline)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .contentShape(Rectangle())
            .onTapGesture { estadoApp.corridaMinimizada = false }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Abre a tela da corrida")
            .accessibilityAction { estadoApp.corridaMinimizada = false }

            switch gravador.sessao.estado {
            case .correndo, .pausadaAuto:
                botao("Pausar", icone: "pause.fill") { gravador.pausar() }
            case .pausadaManual:
                botao("Retomar", icone: "play.fill") { gravador.retomar() }
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
    }

    private func botao(_ rotulo: String, icone: String, acao: @escaping () -> Void) -> some View {
        Button(rotulo, systemImage: icone, action: acao)
            .labelStyle(.iconOnly)
            .font(.title3.weight(.semibold))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }

    private var nomeAtual: String {
        if let execucao = gravador.execucao {
            if let etapa = execucao.etapaAtual { return etapa.nome }
            if execucao.terminou { return "Treino concluído" }
            return execucao.treino.nome
        }
        return gravador.esteira ? "Esteira" : "Corrida livre"
    }

    private var titulo: String {
        switch gravador.sessao.estado {
        case .pronta: "Pronto · " + nomeAtual
        case .pausadaManual: "Pausado · " + nomeAtual
        case .pausadaAuto: "Pausa automática · " + nomeAtual
        default: nomeAtual
        }
    }

    /// O número grande: o que falta da etapa ou, sem etapa, o tempo em movimento.
    private var numero: String {
        let sessao = gravador.sessao
        guard sessao.estado != .pronta else { return "—" }
        if let execucao = gravador.execucao, let etapa = execucao.etapaAtual, let resta = execucao.restante(gravador.leitura()) {
            let r = max(0, resta)
            switch etapa.medida {
            case .tempo: return Formatador.duracao(r)
            case .distancia: return r < 1000 ? "\(Int(r.rounded())) m" : Formatador.distancia(r, unidade: unidade, casas: 2)
            }
        }
        return Formatador.duracao(sessao.tempoEmMovimento(em: gravador.agora))
    }

    private var detalhe: String {
        let sessao = gravador.sessao
        let agora = gravador.agora
        guard sessao.estado != .pronta else { return "Toque para abrir" }
        if gravador.esteira {
            return gravador.execucao == nil ? "na esteira" : "Tempo " + Formatador.duracao(sessao.tempoEmMovimento(em: agora))
        }
        var partes = [Formatador.distancia(sessao.distancia, unidade: unidade)]
        if let ritmo = sessao.ritmoAtual(em: agora) {
            partes.append(Formatador.ritmo(segundosPorKm: ritmo, unidade: unidade))
        }
        if let bpm = gravador.fcAtual { partes.append("♥ \(bpm)") }
        return partes.joined(separator: " · ")
    }

    private var cor: Color {
        gravador.execucao?.etapaAtual?.tipo.cor ?? Paleta.verdeLogo
    }
}

/// Liga a barra da corrida minimizada nas abas. O modificador que esconde o acessório
/// (`isEnabled`) só existe a partir do iOS 26.1; antes disso a corrida não minimiza.
struct AcessorioCorrida: ViewModifier {
    let estado: EstadoApp

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: estado.gravadorAtivo != nil && estado.corridaMinimizada) {
                if let gravador = estado.gravadorAtivo {
                    MiniCorridaView(gravador: gravador, estadoApp: estado)
                }
            }
        } else {
            content
        }
    }
}
