import CrunningCore
import SwiftUI

/// Tela de corrida em tela cheia. Legibilidade vence estética: fundo opaco,
/// números enormes, contraste alto.
struct CorridaView: View {
    let gravador: GravadorCorrida
    @Environment(EstadoApp.self) var estadoApp
    @Environment(\.scenePhase) var fase
    @Environment(\.openURL) var abrirURL
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @State var avisoVisivel: AvisoCorrida?

    var body: some View {
        Group {
            if gravador.sessao.estado == .finalizada {
                ResumoCorridaView(gravador: gravador)
            } else {
                painel
            }
        }
        .onAppear { gravador.prepararGPS() }
        .onChange(of: fase) { _, novaFase in
            if novaFase != .active { gravador.salvarSessao(forcar: true) }
        }
        .onChange(of: gravador.ultimoAviso) { _, novo in avisoVisivel = novo }
        .task(id: avisoVisivel?.id) {
            guard avisoVisivel != nil else { return }
            try? await Task.sleep(for: .seconds(5))
            avisoVisivel = nil
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: gravador.sessao.estado)
        .sensoryFeedback(.success, trigger: gravador.sessao.parciaisKm.count)
    }

    private var painel: some View {
        let sessao = gravador.sessao
        let agora = gravador.agora
        return VStack(spacing: 18) {
            cabecalho(sessao.estado)

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Text(Formatador.numero(Formatador.distanciaNaUnidade(sessao.distancia, unidade: unidade), casas: 2))
                    .font(.system(size: 104, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text(unidade == .quilometros ? "quilômetros" : "milhas")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    Metrica(titulo: "Tempo", valor: Formatador.duracao(sessao.tempoEmMovimento(em: agora)), grande: true)
                    Metrica(titulo: "Ritmo atual", valor: ritmo(sessao.ritmoAtual(em: agora)), grande: true)
                }
                GridRow {
                    Metrica(titulo: "Ritmo médio", valor: ritmo(sessao.ritmoMedio(em: agora)), grande: true)
                    Metrica(titulo: "Tempo total", valor: Formatador.duracao(sessao.tempoTotal(em: agora)), grande: true)
                }
            }
            .padding(20)
            .cartaoVidro(raio: 26, opaco: true)

            avisoAtual
                .frame(height: 44)

            Spacer(minLength: 0)

            controles(sessao.estado)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }

    // MARK: Partes

    private func cabecalho(_ estado: EstadoCorrida) -> some View {
        HStack {
            Text(titulo(estado))
                .font(.headline)
                .foregroundStyle(estado == .correndo ? Paleta.verdeLogo : Color.primary)
            Spacer()
            IndicadorGPS(qualidade: gravador.qualidade)
        }
    }

    @ViewBuilder
    private var avisoAtual: some View {
        if let aviso = avisoVisivel {
            Label(aviso.texto, systemImage: aviso.icone)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Paleta.verdeLogo.opacity(0.2), in: Capsule())
                .transition(.scale.combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    @ViewBuilder
    private func controles(_ estado: EstadoCorrida) -> some View {
        switch estado {
        case .pronta:
            VStack(spacing: 14) {
                if gravador.permissaoNegada {
                    VStack(spacing: 8) {
                        Text("Sem permissão de localização, não dá para medir a corrida.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        Button("Abrir Ajustes do iPhone") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
                        }
                        .buttonStyle(.glass)
                    }
                } else {
                    if gravador.qualidade == .procurando || gravador.qualidade == .fraco {
                        Text("Espere o GPS firmar para medir melhor o começo.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    DeslizarParaConfirmar(rotulo: "Deslize para iniciar", icone: "figure.run") {
                        gravador.iniciar()
                    }
                }
                Button("Cancelar") {
                    gravador.descartar()
                    estadoApp.gravadorAtivo = nil
                }
                .font(.body.weight(.medium))
            }
        case .correndo, .pausadaAuto:
            botaoRedondo(icone: "pause.fill", rotulo: "Pausar", cor: Color.primary) {
                gravador.pausar()
            }
        case .pausadaManual:
            VStack(spacing: 16) {
                botaoRedondo(icone: "play.fill", rotulo: "Retomar", cor: Paleta.verdeLogo) {
                    gravador.retomar()
                }
                DeslizarParaConfirmar(rotulo: "Deslize para finalizar", icone: "flag.checkered") {
                    gravador.finalizar()
                }
            }
        case .finalizada:
            EmptyView()
        }
    }

    private func botaoRedondo(icone: String, rotulo: String, cor: Color, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Image(systemName: icone)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(cor == Color.primary ? Color(uiColor: .systemBackground) : Color.black)
                .frame(width: 92, height: 92)
                .background(cor, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rotulo)
    }

    private func titulo(_ estado: EstadoCorrida) -> String {
        let base: String = switch estado {
        case .pronta: "Pronto para começar"
        case .correndo: "Correndo"
        case .pausadaManual: "Pausado"
        case .pausadaAuto: "Pausa automática"
        case .finalizada: "Concluída"
        }
        return gravador.simulada ? base + " · simulação" : base
    }

    private func ritmo(_ segundosPorKm: Double?) -> String {
        guard let segundosPorKm else { return "--:--" }
        return Formatador.ritmo(segundosPorKm: segundosPorKm, unidade: unidade)
    }
}
