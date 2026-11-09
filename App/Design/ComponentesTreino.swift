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
            return pace(zonas.faixa(passo.intensidade, distanciaProva: distanciaProva), unidade: unidade)
        }
        let e = passo.intensidade.esforco
        return "\(passo.intensidade.nome) · esforço \(e.lowerBound) a \(e.upperBound)"
    }

    /// A outra medida estimada (tempo de um trecho por distância, distância de um por tempo) e,
    /// onde o batimento chega a se firmar, a zona: "≈ 1,6 km · tente ficar na Z2".
    static func complemento(_ passo: Passo, zonas: Zonas?, unidade: UnidadeDistancia) -> String? {
        var partes: [String] = []
        let z = zonas ?? Zonas.estimativaSemReferencia(.intermediario)
        let est = passo.estimativa(zonas: z)
        switch passo.medida {
        case .tempo:
            if est.distancia >= 50 {
                partes.append("≈ " + medida(.distancia((est.distancia / 50).rounded() * 50), unidade: unidade))
            }
        case .distancia:
            if est.duracao > 0 {
                partes.append("≈ " + (est.duracao < 600 ? Formatador.duracao((est.duracao / 5).rounded() * 5) : LinhaDoTempoTreino.tempoCurto(est.duracao)))
            }
        }
        if FrequenciaCardiaca.usaZona(passo, duracaoEstimada: est.duracao), let zona = ZonasDoUsuario.zonaFC(passo.intensidade) {
            partes.append("tente ficar na " + zona.rotulo)
        }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }

    /// "pace entre 3:55 e 4:05 /km".
    static func pace(_ f: FaixaRitmo, unidade: UnidadeDistancia) -> String {
        "pace entre " + Formatador.ritmo(segundosPorKm: f.rapido, unidade: unidade) + " e "
            + Formatador.ritmo(segundosPorKm: f.lento, unidade: unidade) + " " + unidade.siglaRitmo
    }

    static func faixa(_ f: FaixaRitmo, unidade: UnidadeDistancia) -> String {
        Formatador.ritmo(segundosPorKm: f.rapido, unidade: unidade) + "–" + Formatador.ritmo(segundosPorKm: f.lento, unidade: unidade) + " " + unidade.siglaRitmo
    }

    /// "≈ 7,2 km · 42 min".
    static func totais(_ treino: Treino, zonas: Zonas?, unidade: UnidadeDistancia) -> String {
        let z = zonas ?? Zonas.estimativaSemReferencia(.intermediario)
        let d = treino.distanciaEstimada(zonas: z)
        let t = treino.duracaoEstimada(zonas: z)
        // Estimativa: sem segundos ("≈ 7,1 km · 49 min").
        return "≈ " + Formatador.distancia(d, unidade: unidade, casas: 1) + " · " + LinhaDoTempoTreino.tempoCurto(t)
    }
}

// MARK: - Linha do tempo

/// Estrutura do treino em cápsulas (no estilo do StatusBar do beUI, MIT; só o desenho, sem código):
/// uma cápsula por passo, com as repetições abertas, todas da mesma espessura, com espaço entre
/// elas. A cor é a do tipo; recuperação fica neutra e os trechos leves ficam apagados quando há
/// trabalho forte. A largura cresce com a raiz quadrada da duração (aquecimento longo encolhe,
/// tiro curto não vira ponto). É a estrutura, não uma escala de tempo. Embaixo, uma legenda com o
/// tempo de cada tipo, para a cor não ser a única pista. Toque devolve (bloco, passo da repetição).
struct LinhaDoTempoTreino: View {
    let blocos: [Bloco]
    var zonas: Zonas?
    /// Espessura das cápsulas.
    var espessura: CGFloat = 12
    /// Altura da área de toque (no construtor, 44); sem ela, a da cápsula.
    var alturaToque: CGFloat? = nil
    var legenda = true
    var aoTocar: ((Int, Int?) -> Void)? = nil

    private enum Papel { case trabalho, recuperacao, leve }

    private struct Segmento: Identifiable {
        let id: Int
        let bloco: Int
        let passo: Int?
        let duracao: TimeInterval
        let tipo: TipoTreino
        let papel: Papel
    }

    private struct ItemLegenda: Identifiable {
        let id: String
        let cor: Color
        let texto: String
    }

    private var segmentos: [Segmento] {
        let z = zonas ?? Zonas.estimativaSemReferencia(.intermediario)
        var lista: [Segmento] = []
        func adicionar(_ p: Passo, bloco: Int, passo: Int?) {
            let papel: Papel = p.funcao == .recuperacao ? .recuperacao
                : (p.intensidade == .facil || p.intensidade == .caminhada ? .leve : .trabalho)
            lista.append(Segmento(
                id: lista.count, bloco: bloco, passo: passo, duracao: p.estimativa(zonas: z).duracao,
                tipo: p.tipoParaCor, papel: papel
            ))
        }
        for (b, bloco) in blocos.enumerated() {
            switch bloco {
            case let .passo(p):
                adicionar(p, bloco: b, passo: nil)
            case let .repetir(vezes, passos):
                for _ in 0..<max(1, vezes) {
                    for (i, p) in passos.enumerated() { adicionar(p, bloco: b, passo: i) }
                }
            }
        }
        return lista
    }

    private func cor(_ s: Segmento, comTrabalho: Bool) -> Color {
        switch s.papel {
        case .trabalho: s.tipo.cor
        case .recuperacao: comTrabalho ? Color.primary.opacity(0.2) : s.tipo.cor
        case .leve: comTrabalho ? s.tipo.cor.opacity(0.38) : s.tipo.cor
        }
    }

    /// Tempo por tipo, na ordem: trabalho, recuperação, leve.
    private func itensLegenda(_ lista: [Segmento], comTrabalho: Bool) -> [ItemLegenda] {
        var itens: [ItemLegenda] = []
        for papel in [Papel.trabalho, .recuperacao, .leve] {
            var ordem: [String] = []
            var total: [String: TimeInterval] = [:]
            var exemplo: [String: Segmento] = [:]
            for s in lista where s.papel == papel {
                let chave = papel == .recuperacao ? "recuperacao" : s.tipo.rawValue
                if total[chave] == nil {
                    ordem.append(chave)
                    exemplo[chave] = s
                }
                total[chave, default: 0] += s.duracao
            }
            for chave in ordem {
                guard let s = exemplo[chave] else { continue }
                let nome = papel == .recuperacao ? "Recuperação" : s.tipo.nome
                itens.append(ItemLegenda(id: chave, cor: cor(s, comTrabalho: comTrabalho),
                                         texto: nome + " " + Self.tempoCurto(total[chave] ?? 0)))
            }
        }
        return itens
    }

    /// "9 min", "1h05" (estimativa, sem segundos).
    static func tempoCurto(_ segundos: TimeInterval) -> String {
        let m = max(1, Int((segundos / 60).rounded()))
        if m < 60 { return "\(m) min" }
        return "\(m / 60)h" + (m % 60 == 0 ? "" : String(format: "%02d", m % 60))
    }

    private func filaLegenda(_ itens: [ItemLegenda]) -> some View {
        HStack(spacing: 14) {
            ForEach(itens) { item in
                HStack(spacing: 6) {
                    Capsule(style: .continuous)
                        .fill(item.cor)
                        .frame(width: 6, height: 12)
                    Text(item.texto)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
    }

    /// Larguras pela raiz quadrada da duração, com um mínimo para nada sumir. Quem fica abaixo do
    /// mínimo trava nele e o resto divide o espaço que sobra; sem espaço, todas iguais.
    static func larguras(_ duracoes: [TimeInterval], disponivel: CGFloat, minimo: CGFloat = 4) -> [CGFloat] {
        guard !duracoes.isEmpty else { return [] }
        let n = CGFloat(duracoes.count)
        guard disponivel > minimo * n else { return duracoes.map { _ in max(disponivel, 0) / n } }
        let pesos = duracoes.map { CGFloat(max($0, 1)).squareRoot() }
        var travados = Set<Int>()
        while true {
            let livre = disponivel - minimo * CGFloat(travados.count)
            let somaPesos = pesos.indices.filter { !travados.contains($0) }.reduce(CGFloat(0)) { $0 + pesos[$1] }
            var novos = travados
            for i in pesos.indices where !travados.contains(i) && pesos[i] / somaPesos * livre < minimo {
                novos.insert(i)
            }
            if novos == travados {
                return pesos.indices.map { travados.contains($0) ? minimo : pesos[$0] / somaPesos * livre }
            }
            travados = novos
        }
    }

    var body: some View {
        let lista = segmentos
        let comTrabalho = lista.contains { $0.papel == .trabalho }
        let area = max(alturaToque ?? espessura, espessura)
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let espaco: CGFloat = lista.count > 48 ? 1 : (lista.count > 24 ? 2 : 3)
                let disponivel = max(geo.size.width - espaco * CGFloat(max(lista.count - 1, 0)), 1)
                let larguras = Self.larguras(lista.map(\.duracao), disponivel: disponivel, minimo: min(10, espessura))
                HStack(spacing: espaco) {
                    ForEach(lista) { s in
                        Capsule(style: .continuous)
                            .fill(cor(s, comTrabalho: comTrabalho))
                            .frame(width: larguras[s.id], height: espessura)
                            // Toque na área inteira, não só na cápsula.
                            .frame(height: area)
                            .contentShape(Rectangle())
                            .onTapGesture { aoTocar?(s.bloco, s.passo) }
                    }
                }
                .frame(width: geo.size.width, height: area, alignment: .leading)
            }
            .frame(height: area)

            if legenda {
                let itens = itensLegenda(lista, comTrabalho: comTrabalho)
                ViewThatFits(in: .horizontal) {
                    filaLegenda(itens)
                    filaLegenda(Array(itens.prefix(2)))
                    filaLegenda(Array(itens.prefix(1)))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estrutura do treino")
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
                if let complemento {
                    Text(complemento)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(TextoTreino.medida(passo.medida, unidade: unidade))
                .font(.body.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }

    private var complemento: String? {
        TextoTreino.complemento(passo, zonas: zonas, unidade: unidade)
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
