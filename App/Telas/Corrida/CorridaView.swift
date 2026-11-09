import CrunningCore
import SwiftUI

/// Tela de corrida em tela cheia. Legibilidade vence estética: fundo opaco,
/// números enormes, contraste alto. Com treino por blocos, mostra a etapa atual,
/// o medidor de ritmo e as próximas etapas.
struct CorridaView: View {
    let gravador: GravadorCorrida
    @Environment(EstadoApp.self) var estadoApp
    @Environment(\.openURL) var abrirURL
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @State var avisoVisivel: AvisoCorrida?
    @State var confirmandoPulo = false

    var body: some View {
        Group {
            if gravador.sessao.estado == .finalizada {
                ResumoCorridaView(gravador: gravador)
            } else if let execucao = gravador.execucao {
                painelTreino(execucao)
            } else {
                painel
            }
        }
        .onAppear {
            gravador.prepararGPS()
            avisoVisivel = gravador.ultimoAviso
        }
        .onChange(of: gravador.ultimoAviso) { _, novo in avisoVisivel = novo }
        .task(id: avisoVisivel?.id) {
            guard avisoVisivel != nil else { return }
            try? await Task.sleep(for: .seconds(5))
            avisoVisivel = nil
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: gravador.sessao.estado)
        .sensoryFeedback(.success, trigger: gravador.sessao.parciaisKm.count)
        .sensoryFeedback(.impact(weight: .light), trigger: gravador.contagemVisivel) { _, novo in novo != nil }
        .confirmationDialog("Pular esta etapa?", isPresented: $confirmandoPulo, titleVisibility: .visible) {
            Button("Pular etapa") { gravador.pularEtapa() }
        } message: {
            Text("Ela fica marcada como pulada no resumo.")
        }
    }

    // MARK: Corrida livre

    private var painel: some View {
        let sessao = gravador.sessao
        let agora = gravador.agora
        return VStack(spacing: 18) {
            cabecalho(sessao.estado, titulo: nil)

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Text(gravador.esteira ? Formatador.duracao(sessao.tempoEmMovimento(em: agora))
                     : Formatador.numero(Formatador.distanciaNaUnidade(sessao.distancia, unidade: unidade), casas: 2))
                    .font(.system(size: 104, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text(gravador.esteira ? "na esteira (distância no fim)" : unidade == .quilometros ? "quilômetros" : "milhas")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            if !gravador.esteira {
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
            }

            avisoAtual
                .frame(height: 44)

            Spacer(minLength: 0)

            controles(sessao.estado, comTreino: false)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }

    // MARK: Treino por blocos

    private func painelTreino(_ execucao: ExecucaoTreino) -> some View {
        let sessao = gravador.sessao
        let agora = gravador.agora
        let leitura = gravador.leitura()
        let progresso = execucao.progresso(leitura)
        return ZStack {
            VStack(spacing: 14) {
                cabecalho(sessao.estado, titulo: execucao.treino.nome)
                BarraSegmentos(execucao: execucao, progressoAtual: progresso)

                ScrollView {
                    VStack(spacing: 14) {
                        if sessao.estado == .pronta {
                            visaoGeral(execucao)
                        } else if let etapa = execucao.etapaAtual {
                            Group {
                                if let exercicio = etapa.exercicio {
                                    CartaoExercicio(exercicio: exercicio, restante: execucao.restante(leitura), progresso: progresso) {
                                        gravador.pularEtapa()
                                    }
                                } else {
                                    CartaoEtapaAtual(etapa: etapa, restante: execucao.restante(leitura), progresso: progresso,
                                                     unidade: unidade, zonas: nil)
                                }
                            }
                            .padding(20)
                            .cartaoVidro(raio: 26, opaco: true)
                            .id(etapa.id)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))

                            if let faixa = etapa.faixa, !gravador.esteira, etapa.exercicio == nil {
                                MedidorRitmo(faixa: faixa, ritmo: sessao.ritmoAtual(em: agora),
                                             temPiso: etapa.passo?.intensidade.ehQualidade ?? false, unidade: unidade)
                                    .padding(18)
                                    .cartaoVidro(raio: 24, opaco: true)
                            }
                        } else {
                            Label("Treino concluído", systemImage: "checkmark.seal.fill")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Paleta.verdeLogo)
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .cartaoVidro(raio: 26, opaco: true)
                        }

                        metricasTreino(sessao: sessao, agora: agora)
                            .padding(16)
                            .cartaoVidro(raio: 22, opaco: true)

                        if sessao.estado != .pronta {
                            ListaEtapasExecucao(execucao: execucao, unidade: unidade)
                                .padding(16)
                                .cartaoVidro(raio: 22, opaco: true)
                        }
                    }
                    .animation(.smooth(duration: 0.4), value: gravador.transicoes)
                }
                .scrollIndicators(.hidden)

                avisoAtual
                    .frame(height: 40)

                controles(sessao.estado, comTreino: true, terminou: execucao.terminou)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if let n = gravador.contagemVisivel {
                Text("\(n)")
                    .font(.system(size: 180, weight: .heavy, design: .rounded))
                    .foregroundStyle(Paleta.verdeLogo)
                    .shadow(color: .black.opacity(0.4), radius: 12)
                    .id(n)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(.snappy(duration: 0.25), value: gravador.contagemVisivel)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }

    private func visaoGeral(_ execucao: ExecucaoTreino) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("≈ " + Formatador.distancia(execucao.distanciaEstimada, unidade: unidade, casas: 1) + " · " + Formatador.duracao(execucao.duracaoEstimada))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            let exercicios = execucao.etapas.filter { $0.exercicio != nil }
            if !exercicios.isEmpty {
                Label("Com aquecimento guiado: \(exercicios.count) exercícios depois do trote", systemImage: "figure.flexibility")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ListaBlocos(blocos: execucao.treino.blocos, zonas: ZonasDoUsuario.atuais(), unidade: unidade)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro(raio: 26, opaco: true)
    }

    private func metricasTreino(sessao: SessaoCorrida, agora: Date) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Metrica(titulo: gravador.esteira ? "Esteira" : "Distância",
                        valor: gravador.esteira ? "—" : Formatador.distancia(sessao.distancia, unidade: unidade))
                Metrica(titulo: "Tempo", valor: Formatador.duracao(sessao.tempoEmMovimento(em: agora)))
                Metrica(titulo: "Ritmo médio", valor: ritmo(sessao.ritmoMedio(em: agora)))
            }
        }
    }

    // MARK: Partes

    private func cabecalho(_ estado: EstadoCorrida, titulo nomeTreino: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let nomeTreino {
                    Text(nomeTreino)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(titulo(estado))
                    .font(nomeTreino == nil ? .headline : .subheadline)
                    .foregroundStyle(estado == .correndo ? Paleta.verdeLogo : Color.secondary)
            }
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
    private func controles(_ estado: EstadoCorrida, comTreino: Bool, terminou: Bool = false) -> some View {
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
                    if !gravador.esteira, gravador.qualidade == .procurando || gravador.qualidade == .fraco {
                        Text("Espere o GPS firmar para medir melhor o começo.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    DeslizarParaConfirmar(rotulo: comTreino ? "Deslize para começar o treino" : "Deslize para iniciar", icone: "figure.run") {
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
            if comTreino && terminou {
                VStack(spacing: 12) {
                    botaoRedondo(icone: "pause.fill", rotulo: "Pausar", cor: Color.primary, tamanho: 64) { gravador.pausar() }
                    DeslizarParaConfirmar(rotulo: "Deslize para finalizar", icone: "flag.checkered") { gravador.finalizar() }
                }
            } else if comTreino {
                HStack(spacing: 28) {
                    botaoPequeno(icone: "flag.2.crossed", rotulo: "Volta") { gravador.marcarVolta() }
                    botaoRedondo(icone: "pause.fill", rotulo: "Pausar", cor: Color.primary) { gravador.pausar() }
                    botaoPequeno(icone: "forward.end.fill", rotulo: "Pular") {
                        if gravador.execucao?.etapaAtual?.exercicio != nil { gravador.pularEtapa() } else { confirmandoPulo = true }
                    }
                }
            } else {
                botaoRedondo(icone: "pause.fill", rotulo: "Pausar", cor: Color.primary) { gravador.pausar() }
            }
        case .pausadaManual:
            VStack(spacing: 16) {
                botaoRedondo(icone: "play.fill", rotulo: "Retomar", cor: Paleta.verdeLogo) { gravador.retomar() }
                DeslizarParaConfirmar(rotulo: "Deslize para finalizar", icone: "flag.checkered") { gravador.finalizar() }
            }
        case .finalizada:
            EmptyView()
        }
    }

    private func botaoRedondo(icone: String, rotulo: String, cor: Color, tamanho: CGFloat = 92, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Image(systemName: icone)
                .font(.system(size: tamanho * 0.37, weight: .bold))
                .foregroundStyle(cor == Color.primary ? Color(uiColor: .systemBackground) : Color.black)
                .frame(width: tamanho, height: tamanho)
                .background(cor, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rotulo)
    }

    private func botaoPequeno(icone: String, rotulo: String, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            VStack(spacing: 4) {
                Image(systemName: icone)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 60, height: 60)
                    .background(Color.primary.opacity(0.1), in: Circle())
                Text(rotulo).font(.caption.weight(.semibold))
            }
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
        if gravador.esteira { return base + " · esteira" }
        return gravador.simulada ? base + " · simulação" : base
    }

    private func ritmo(_ segundosPorKm: Double?) -> String {
        guard let segundosPorKm else { return "--:--" }
        return Formatador.ritmo(segundosPorKm: segundosPorKm, unidade: unidade)
    }
}
