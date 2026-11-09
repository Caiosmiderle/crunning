import CrunningCore
import SwiftUI

// MARK: - Textos de treino

enum TextoTreino {
    /// "10 min", "1 min 30 s", "400 m", "1,5 km".
    static func medida(_ medida: Medida, unidade: UnidadeDistancia = .quilometros) -> String {
        switch medida {
        case let .tempo(t):
            let total = Int(t.rounded())
            let h = total / 3600, m = (total % 3600) / 60, s = total % 60
            var partes: [String] = []
            if h > 0 { partes.append("\(h) h") }
            if m > 0 { partes.append("\(m) min") }
            if s > 0 || partes.isEmpty { partes.append("\(s) s") }
            return partes.joined(separator: " ")
        case let .distancia(d):
            if unidade == .quilometros, d < 1000 { return "\(Int(d.rounded())) m" }
            let valor = Formatador.distanciaNaUnidade(d, unidade: unidade)
            let casas = abs(valor - valor.rounded()) < 0.005 ? 0 : (abs(valor * 10 - (valor * 10).rounded()) < 0.05 ? 1 : 2)
            return Formatador.numero(valor, casas: casas) + " " + unidade.sigla
        }
    }

    /// Faixa de ritmo "4:05–4:15 /km", ou o esforço quando não há ritmos de referência.
    static func alvo(_ passo: Passo, zonas: Zonas?, unidade: UnidadeDistancia) -> String {
        if passo.intensidade == .caminhada { return "Caminhada" }
        if let zonas {
            let distanciaProva: Double?
            if case let .distancia(d) = passo.medida { distanciaProva = d } else { distanciaProva = nil }
            return faixa(zonas.faixa(passo.intensidade, distanciaProva: distanciaProva), unidade: unidade)
        }
        let e = passo.intensidade.esforco
        return "\(passo.intensidade.nome) · esforço \(e.lowerBound) a \(e.upperBound)"
    }

    static func faixa(_ f: FaixaRitmo, unidade: UnidadeDistancia) -> String {
        Formatador.ritmo(segundosPorKm: f.rapido, unidade: unidade) + "–" + Formatador.ritmo(segundosPorKm: f.lento, unidade: unidade) + " " + unidade.siglaRitmo
    }

    /// "≈ 7,2 km · 42 min".
    static func totais(_ treino: Treino, zonas: Zonas?, unidade: UnidadeDistancia) -> String {
        let z = zonas ?? Zonas.estimativaSemReferencia(.intermediario)
        let d = treino.distanciaEstimada(zonas: z)
        let t = treino.duracaoEstimada(zonas: z)
        return "≈ " + Formatador.distancia(d, unidade: unidade, casas: 1) + " · " + Formatador.duracao(t)
    }
}

// MARK: - Linha do tempo

/// Barra horizontal do treino: um segmento por passo (repetições abertas), largura pela duração
/// estimada, altura e cor pela intensidade. Toque num segmento devolve (bloco, passo da repetição).
struct LinhaDoTempoTreino: View {
    let blocos: [Bloco]
    var zonas: Zonas?
    var altura: CGFloat = 44
    var aoTocar: ((Int, Int?) -> Void)? = nil

    private struct Segmento: Identifiable {
        let id: Int
        let bloco: Int
        let passo: Int?
        let duracao: TimeInterval
        let cor: Color
        let fracaoAltura: CGFloat
        let inicioRepeticao: Int?
    }

    private var segmentos: [Segmento] {
        let z = zonas ?? Zonas.estimativaSemReferencia(.intermediario)
        var lista: [Segmento] = []
        for (b, bloco) in blocos.enumerated() {
            switch bloco {
            case let .passo(p):
                lista.append(Segmento(id: lista.count, bloco: b, passo: nil, duracao: p.estimativa(zonas: z).duracao,
                                      cor: p.tipoParaCor.cor, fracaoAltura: Self.fracaoAltura(p.intensidade), inicioRepeticao: nil))
            case let .repetir(vezes, passos):
                for k in 0..<max(1, vezes) {
                    for (i, p) in passos.enumerated() {
                        lista.append(Segmento(id: lista.count, bloco: b, passo: i, duracao: p.estimativa(zonas: z).duracao,
                                              cor: p.tipoParaCor.cor, fracaoAltura: Self.fracaoAltura(p.intensidade),
                                              inicioRepeticao: (k == 0 && i == 0) ? vezes : nil))
                    }
                }
            }
        }
        return lista
    }

    static func fracaoAltura(_ i: Intensidade) -> CGFloat {
        switch i {
        case .caminhada: 0.35
        case .facil: 0.5
        case .maratona: 0.65
        case .limiar: 0.78
        case .prova: 0.85
        case .intervalado: 0.92
        case .repeticoes: 1
        }
    }

    private var temRepeticao: Bool {
        blocos.contains { bloco in
            if case .repetir = bloco { return true }
            return false
        }
    }

    var body: some View {
        let lista = segmentos
        GeometryReader { geo in
            let espaco: CGFloat = lista.count > 40 ? 1 : 2
            let disponivel = max(geo.size.width - espaco * CGFloat(max(lista.count - 1, 0)), 1)
            let total = max(lista.reduce(0) { $0 + $1.duracao }, 1)
            let brutas = lista.map { max(3, CGFloat($0.duracao / total) * disponivel) }
            let escala = min(1, disponivel / max(brutas.reduce(0, +), 1))
            HStack(alignment: .bottom, spacing: espaco) {
                ForEach(lista) { s in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(s.cor)
                        .frame(width: brutas[s.id] * escala, height: max(6, altura * s.fracaoAltura))
                        .overlay(alignment: .topLeading) {
                            if let vezes = s.inicioRepeticao, vezes > 1 {
                                Text("×\(vezes)")
                                    .font(.caption2.weight(.bold))
                                    .fixedSize()
                                    .offset(y: -16)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { aoTocar?(s.bloco, s.passo) }
                }
            }
            .frame(width: geo.size.width, height: altura, alignment: .bottomLeading)
        }
        .frame(height: altura)
        .padding(.top, temRepeticao ? 16 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Linha do tempo do treino")
        .accessibilityValue(TextoRapido.texto(blocos))
    }
}

// MARK: - Linha de um passo

struct LinhaPasso: View {
    let passo: Passo
    var zonas: Zonas?
    var unidade: UnidadeDistancia = .quilometros

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(passo.tipoParaCor.cor)
                .frame(width: 6, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(EtapaExecucao.nome(passo))
                    .font(.body.weight(.medium))
                Text(TextoTreino.alvo(passo, zonas: zonas, unidade: unidade))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(TextoTreino.medida(passo.medida, unidade: unidade))
                .font(.body.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}

/// Lista dos blocos de um treino (detalhe e construtor).
struct ListaBlocos: View {
    let blocos: [Bloco]
    var zonas: Zonas?
    var unidade: UnidadeDistancia = .quilometros

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocos.enumerated()), id: \.offset) { _, bloco in
                switch bloco {
                case let .passo(p):
                    LinhaPasso(passo: p, zonas: zonas, unidade: unidade)
                case let .repetir(vezes, passos):
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(vezes) vezes", systemImage: "repeat")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(passos.enumerated()), id: \.offset) { _, p in
                            LinhaPasso(passo: p, zonas: zonas, unidade: unidade)
                        }
                    }
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.primary.opacity(0.15)).frame(width: 2)
                    }
                }
            }
        }
    }
}

// MARK: - Resultado por bloco

/// Planejado x realizado de cada etapa. Os exercícios do aquecimento guiado viram uma linha só.
struct TabelaBlocos: View {
    let resultados: [ResultadoEtapa]
    var unidade: UnidadeDistancia = .quilometros

    private enum Linha: Identifiable {
        case etapa(ResultadoEtapa)
        case aquecimento(id: Int, feitos: Int, total: Int, duracao: TimeInterval)

        var id: Int {
            switch self {
            case let .etapa(r): r.id
            case let .aquecimento(id, _, _, _): -1 - id
            }
        }
    }

    private var linhas: [Linha] {
        var lista: [Linha] = []
        var grupo: [ResultadoEtapa] = []
        func fechar() {
            guard let primeiro = grupo.first else { return }
            let feitos = grupo.filter { $0.situacao == .feita }.count
            lista.append(.aquecimento(id: primeiro.id, feitos: feitos, total: grupo.count, duracao: grupo.reduce(0) { $0 + $1.duracao }))
            grupo = []
        }
        for r in resultados {
            if r.ehExercicio {
                grupo.append(r)
            } else {
                fechar()
                lista.append(.etapa(r))
            }
        }
        fechar()
        return lista
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Por bloco: planejado x feito")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(linhas) { linha in
                switch linha {
                case let .etapa(r): linhaEtapa(r)
                case let .aquecimento(_, feitos, total, duracao):
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(TipoTreino.caminhada.cor)
                            .frame(width: 6, height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aquecimento guiado").font(.subheadline.weight(.medium))
                            Text("\(feitos) de \(total) exercícios").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Formatador.duracao(duracao)).font(.subheadline.monospacedDigit())
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func linhaEtapa(_ r: ResultadoEtapa) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(r.tipo.cor.opacity(r.situacao == .feita ? 1 : 0.4))
                .frame(width: 6, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.nome + (r.repeticao.map { k in r.totalRepeticoes.map { " \(k)/\($0)" } ?? "" } ?? ""))
                    .font(.subheadline.weight(.medium))
                Text(planejado(r))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(feito(r))
                    .font(.subheadline.monospacedDigit())
                if let ritmo = r.ritmo {
                    HStack(spacing: 4) {
                        Text(Formatador.ritmo(segundosPorKm: ritmo, unidade: unidade) + " " + unidade.siglaRitmo)
                        if let noRitmo = r.noRitmo {
                            Image(systemName: noRitmo ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(noRitmo ? Paleta.dentroDaFaixa : Paleta.foraLeve)
                        }
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func planejado(_ r: ResultadoEtapa) -> String {
        var texto = TextoTreino.medida(r.planejado, unidade: unidade)
        if let faixa = r.faixa { texto += " · " + TextoTreino.faixa(faixa, unidade: unidade) }
        return texto
    }

    private func feito(_ r: ResultadoEtapa) -> String {
        switch r.situacao {
        case .naoFeita: return "não feito"
        case .pulada: return "pulado"
        case .feita, .parcial:
            var texto = Formatador.duracao(r.duracao)
            if r.distancia >= 50 { texto += " · " + TextoTreino.medida(.distancia(r.distancia), unidade: unidade) }
            return r.situacao == .parcial ? texto + " (parcial)" : texto
        }
    }
}
