import CrunningCore
import SwiftUI

// MARK: - Barra segmentada

/// Uma faixa por etapa, na cor da etapa: as feitas cheias, a atual com o progresso, as próximas apagadas.
struct BarraSegmentos: View {
    let execucao: ExecucaoTreino
    let progressoAtual: Double

    var body: some View {
        GeometryReader { geo in
            let etapas = execucao.etapas
            let espaco: CGFloat = etapas.count > 30 ? 1.5 : 3
            let disponivel = max(geo.size.width - espaco * CGFloat(max(etapas.count - 1, 0)), 1)
            let total = max(etapas.reduce(0) { $0 + $1.duracaoEstimada }, 1)
            let brutas = etapas.map { max(4, CGFloat($0.duracaoEstimada / total) * disponivel) }
            let escala = min(1, disponivel / max(brutas.reduce(0, +), 1))
            HStack(alignment: .center, spacing: espaco) {
                ForEach(etapas) { etapa in
                    let atual = etapa.id == execucao.atual
                    let feita = etapa.id < execucao.atual
                    ZStack(alignment: .leading) {
                        Capsule().fill(etapa.tipo.cor.opacity(feita ? 1 : 0.3))
                        if atual {
                            Capsule()
                                .fill(etapa.tipo.cor)
                                .frame(width: brutas[etapa.id] * escala * progressoAtual)
                        }
                    }
                    .frame(width: brutas[etapa.id] * escala, height: atual ? 16 : 8)
                    .overlay {
                        if atual { Capsule().stroke(Color.primary, lineWidth: 1.5) }
                    }
                }
            }
            .frame(width: geo.size.width, height: 18)
        }
        .frame(height: 18)
        .animation(.smooth(duration: 0.3), value: execucao.atual)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progresso do treino")
        .accessibilityValue("Etapa \(min(execucao.atual + 1, execucao.etapas.count)) de \(execucao.etapas.count)")
    }
}

// MARK: - Etapa atual

struct CartaoEtapaAtual: View {
    let etapa: EtapaExecucao
    let restante: Double?
    let progresso: Double
    let unidade: UnidadeDistancia
    let zonas: Zonas?
    /// Batimento de agora, se a pulseira estiver transmitindo.
    var bpm: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(etapa.nome, systemImage: icone)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(etapa.tipo.cor)
                Spacer()
                if let k = etapa.repeticao, let n = etapa.totalRepeticoes, n > 1 {
                    Text("Repetição \(k) de \(n)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Text(textoRestante)
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(countsDown: true))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Falta \(textoRestante)")
            ProgressView(value: progresso)
                .tint(etapa.tipo.cor)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            Text(textoAlvo)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if let passo = etapa.passo, FrequenciaCardiaca.usaZona(passo, duracaoEstimada: etapa.duracaoEstimada),
               let zona = ZonasDoUsuario.zonaFC(passo.intensidade) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(corBatimento(zona))
                    Text(L("Tente ficar na \(zona.rotulo) (\(zona.minimo.map { "\($0)–" } ?? "até ")\(zona.maximo) bpm)", "Try to stay in \(zona.rotulo) (\(zona.minimo.map { "\($0)–" } ?? "up to ")\(zona.maximo) bpm)") + (bpm.map { L(" · agora \($0)", " · now \($0)") } ?? ""))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// Verde dentro da zona, laranja acima, cinza abaixo ou sem leitura da pulseira.
    private func corBatimento(_ zona: ZonaFC) -> Color {
        guard let bpm else { return .secondary }
        if zona.contem(bpm) { return Paleta.dentroDaFaixa }
        return bpm > zona.maximo ? Paleta.foraForte : .secondary
    }

    private var icone: String {
        guard let p = etapa.passo else { return "figure.flexibility" }
        switch p.funcao {
        case .aquecimento: return "flame"
        case .desaquecimento: return "wind"
        case .recuperacao: return p.intensidade == .caminhada ? "figure.walk" : "arrow.down.heart"
        case .trabalho: return p.intensidade.ehQualidade ? "bolt.fill" : "figure.run"
        }
    }

    private var textoRestante: String {
        let resta = max(0, restante ?? 0)
        switch etapa.medida {
        case .tempo: return Formatador.duracao(resta.rounded(.up))
        case .distancia:
            if unidade == .quilometros, resta < 1000 { return "\(Int(resta.rounded())) m" }
            return Formatador.distancia(resta, unidade: unidade, casas: 2)
        }
    }

    private var textoAlvo: String {
        guard let p = etapa.passo else { return "" }
        var texto = ""
        if case let .distancia(d) = etapa.planejado, case .tempo = etapa.medida {
            texto = "≈ " + TextoTreino.medida(.distancia(d), unidade: unidade) + L(" na esteira · ", " on the treadmill · ")
        }
        if let faixa = etapa.faixa { return texto + TextoTreino.pace(faixa, unidade: unidade).capitalizandoPrimeira }
        return texto + p.intensidade.testeDaFala
    }
}

// MARK: - Medidor de ritmo

/// Faixa-alvo marcada numa barra, com o ritmo atual como marcador (mais rápido à direita).
struct MedidorRitmo: View {
    let faixa: FaixaRitmo
    let ritmo: Double?
    /// Nos trechos de qualidade, devagar demais também é aviso; no fácil, não.
    let temPiso: Bool
    let unidade: UnidadeDistancia

    var body: some View {
        let situacao = SituacaoRitmo.avaliar(ritmo, faixa: faixa)
        let trecho = SituacaoRitmo.faixaNoMedidor(faixa)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ritmo atual")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(ritmo.map { Formatador.ritmo(segundosPorKm: $0, unidade: unidade) + " " + unidade.siglaRitmo } ?? "--:--")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                let largura = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule()
                        .fill(Paleta.dentroDaFaixa.opacity(0.85))
                        .frame(width: max(8, largura * (trecho.upperBound - trecho.lowerBound)))
                        .offset(x: largura * trecho.lowerBound)
                    if let ritmo {
                        Circle()
                            .fill(cor(situacao))
                            .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 3))
                            .frame(width: 26, height: 26)
                            .offset(x: largura * SituacaoRitmo.posicao(ritmo, faixa: faixa) - 13)
                            .animation(.smooth(duration: 0.6), value: ritmo)
                    }
                }
            }
            .frame(height: 26)
            HStack {
                Text("mais devagar").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text(texto(situacao))
                    .font(.headline)
                    .foregroundStyle(cor(situacao))
                Spacer()
                Text("mais rápido").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func texto(_ s: SituacaoRitmo) -> String {
        switch s {
        case .semDados: L("Medindo...", "Measuring...")
        case .dentro: L("No ritmo", "On pace")
        case let .lento(forte): temPiso ? (forte ? L("Acelere", "Speed up") : L("Acelere um pouco", "Speed up a little")) : L("Tranquilo", "All good")
        case let .rapido(forte): forte ? L("Reduza", "Slow down") : L("Reduza um pouco", "Ease off a little")
        }
    }

    private func cor(_ s: SituacaoRitmo) -> Color {
        switch s {
        case .semDados: Color.secondary
        case .dentro: Paleta.dentroDaFaixa
        case let .lento(forte): temPiso ? (forte ? Paleta.foraForte : Paleta.foraLeve) : Color.secondary
        case let .rapido(forte): forte ? Paleta.foraForte : Paleta.foraLeve
        }
    }
}

// MARK: - Exercício do aquecimento guiado

struct CartaoExercicio: View {
    let exercicio: ExercicioAquecimento
    let restante: Double?
    let progresso: Double
    var aoAvancar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Aquecimento guiado", systemImage: "figure.flexibility")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(exercicio.nome)
                .font(.title.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(Fala.medidaExercicio(exercicio.medida).capitalizandoPrimeira)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Paleta.verdeLogo)
            Text(exercicio.comoFazer)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .center) {
                Text(Formatador.duracao(max(0, restante ?? 0).rounded(.up)))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Spacer()
                Button(action: aoAvancar) {
                    Label("Próximo", systemImage: "forward.fill")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.glass)
            }
            ProgressView(value: progresso).tint(Paleta.verdeLogo)
        }
    }
}

extension String {
    var capitalizandoPrimeira: String {
        prefix(1).uppercased() + dropFirst()
    }
}

// MARK: - Próximas e feitas

struct ListaEtapasExecucao: View {
    let execucao: ExecucaoTreino
    let unidade: UnidadeDistancia

    var body: some View {
        let feitas = execucao.resultados.prefix(execucao.atual).suffix(2)
        let proximas = execucao.etapas.dropFirst(execucao.atual + 1).prefix(3)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(feitas)) { r in
                HStack(spacing: 10) {
                    Image(systemName: r.situacao == .pulada ? "forward.circle" : "checkmark.circle.fill")
                        .foregroundStyle(r.situacao == .pulada ? Color.secondary : Paleta.dentroDaFaixa)
                    Text(r.nome + (r.repeticao.map { " \($0)" } ?? ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let ritmo = r.ritmo {
                        Text(Formatador.ritmo(segundosPorKm: ritmo, unidade: unidade) + " " + unidade.siglaRitmo)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text(Formatador.duracao(r.duracao))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(Array(proximas.enumerated()), id: \.element.id) { i, etapa in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(etapa.tipo.cor)
                        .frame(width: 6, height: i == 0 ? 30 : 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text((i == 0 ? L("A seguir: ", "Next: ") : "") + etapa.nome)
                            .font(i == 0 ? .headline : .subheadline)
                        if i == 0, let faixa = etapa.faixa {
                            Text(TextoTreino.faixa(faixa, unidade: unidade))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(TextoTreino.medida(etapa.planejado, unidade: unidade))
                        .font(.subheadline.monospacedDigit())
                }
                .opacity(i == 0 ? 1 : 0.7)
            }
        }
    }
}
