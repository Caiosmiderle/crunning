import Charts
import CrunningCore
import SwiftData
import SwiftUI

/// Volume por semana ou por mês: o que foi corrido (barra verde) e o que o plano pede (barra cinza
/// larga, atrás), do passado até o fim do plano. Arrasta para os lados ou anda com as setas; segurar
/// o dedo numa barra mostra os números dela no topo do gráfico. Aberto pelo cartão "Esta semana" do
/// Hoje. Sem simulações nem corridas de exemplo.
struct VolumeSemanalView: View {
    enum Modo: String, CaseIterable, Identifiable {
        case semanas, meses
        var id: String { rawValue }
        var titulo: String { self == .semanas ? L("Semanas", "Weeks") : L("Meses", "Months") }
    }

    @Query(sort: \Corrida.inicio) var corridas: [Corrida]
    @Query var ativos: [PlanoAtivo]
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @State var modo: Modo = .semanas
    @State var selecionada: Date?
    /// Começo da parte visível do gráfico (rolagem).
    @State var inicioVisivel: Date = Self.inicioPadrao(.semanas)

    /// Quantas barras cabem na tela em cada modo.
    static func visiveis(_ modo: Modo) -> Int { modo == .semanas ? 8 : 6 }

    /// Ao abrir: a semana (ou o mês) atual perto da direita, com um pouco do plano à frente.
    static func inicioPadrao(_ modo: Modo, calendario: Calendar = CalendarioTreino.padrao()) -> Date {
        let hoje = Date.now
        switch modo {
        case .semanas:
            let atual = CalendarioTreino.inicioDaSemana(hoje, calendario: calendario)
            return calendario.date(byAdding: .weekOfYear, value: -5, to: atual) ?? atual
        case .meses:
            let atual = calendario.dateInterval(of: .month, for: hoje)?.start ?? hoje
            return calendario.date(byAdding: .month, value: -3, to: atual) ?? atual
        }
    }

    /// Verde da marca escurecido para gráfico (validado: faixa de luminosidade e contraste com o
    /// fundo nos dois temas). O planejado é neutro de propósito: é referência, não série.
    static let verde = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0x62 / 255, green: 0xA6 / 255, blue: 0, alpha: 1)
        : UIColor(red: 0x4F / 255, green: 0x93 / 255, blue: 0, alpha: 1) })

    private var calendario: Calendar { CalendarioTreino.padrao() }

    private var feitas: [(inicio: Date, distancia: Double)] {
        corridas.filter { !$0.simulada && !$0.exemplo }.map { (inicio: $0.inicio, distancia: $0.distanciaMetros) }
    }

    private var plano: [(inicio: Date, distancia: Double)] {
        guard let agenda = ativos.first?.agenda else { return [] }
        return agenda.plano.semanas.map { (agenda.data(semana: $0.numero, dia: 0), $0.volumeTreino) }
    }

    private func semanas(_ feitas: [(inicio: Date, distancia: Double)]) -> [VolumeSemana] {
        // Do começo do histórico (no mínimo 11 semanas, no máximo 2 anos) até o fim do plano.
        let primeira = feitas.map(\.inicio).min() ?? .now
        let passadas = calendario.dateComponents([.weekOfYear], from: CalendarioTreino.inicioDaSemana(primeira, calendario: calendario),
                                                 to: CalendarioTreino.inicioDaSemana(.now, calendario: calendario)).weekOfYear ?? 0
        return VolumeSemanal.calcular(corridas: feitas, plano: plano, hoje: .now, passadas: min(104, max(11, passadas)), futuras: 104)
    }

    private func meses(_ feitas: [(inicio: Date, distancia: Double)]) -> [VolumeSemana] {
        let primeira = feitas.map(\.inicio).min() ?? .now
        let passados = calendario.dateComponents([.month], from: primeira, to: .now).month ?? 0
        return VolumeSemanal.porMes(corridas: feitas, plano: plano, hoje: .now, passados: min(24, max(5, passados + 1)))
    }

    var body: some View {
        let corridasFeitas = self.feitas
        let listaSemanas = semanas(corridasFeitas)
        let lista = modo == .semanas ? listaSemanas : meses(corridasFeitas)
        let atual = CalendarioTreino.inicioDaSemana(.now)
        let estaSemana = listaSemanas.first { $0.inicio == atual }
        let passada = listaSemanas.last { $0.inicio < atual }
        let variacao = VolumeSemanal.variacao(listaSemanas, hoje: .now)
        let media = VolumeSemanal.media(listaSemanas, ultimas: 4, hoje: .now)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        bloco(L("Esta semana", "This week"), km(estaSemana?.feito ?? 0),
                              estaSemana?.planejado.map { L("de ", "of ") + km($0) + L(" planejados", " planned") })
                        bloco(L("Semana passada", "Last week"), km(passada?.feito ?? 0),
                              variacao.map { ($0 >= 0 ? "+" : "−") + L("\(Int((abs($0) * 100).rounded()))% sobre a anterior", "\(Int((abs($0) * 100).rounded()))% vs. the week before") })
                    }
                    GridRow {
                        bloco(L("Média de 4 semanas", "4-week average"), km(media), nil)
                        Color.clear.frame(height: 1)
                    }
                }
                .padding(18)
                .cartaoVidro(raio: 24)

                VStack(alignment: .leading, spacing: 12) {
                    Picker(L("Ver por", "View by"), selection: $modo) {
                        ForEach(Modo.allCases) { Text($0.titulo).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    navegacao(lista)
                    leitura(lista)
                    grafico(lista)
                        .frame(height: 220)
                    legenda(comPlano: lista.contains { $0.planejado != nil })
                }
                .padding(18)
                .cartaoVidro(raio: 24)

                tabela(lista.reversed())
                    .padding(18)
                    .cartaoVidro(raio: 24)

                Text("Distância das corridas gravadas, de segunda a domingo (sem simulações). O planejado é o volume de treino do plano, sem a prova. Aumentos grandes de uma semana para outra pedem atenção: o plano limita a 10% por padrão.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { FundoView() }
        .navigationTitle("Volume por semana")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: modo) { _, novo in
            selecionada = nil
            inicioVisivel = Self.inicioPadrao(novo, calendario: calendario)
        }
    }

    // MARK: Navegação

    private var unidadeTempo: Calendar.Component { modo == .semanas ? .weekOfYear : .month }

    /// Primeiro início possível da janela e o último (para a janela não passar do fim dos dados).
    private func limites(_ lista: [VolumeSemana]) -> (min: Date, max: Date)? {
        guard let primeiro = lista.first?.inicio, let ultimo = lista.last?.inicio else { return nil }
        let maximo = calendario.date(byAdding: unidadeTempo, value: -(Self.visiveis(modo) - 1), to: ultimo) ?? ultimo
        return (primeiro, max(primeiro, maximo))
    }

    private func andar(_ passo: Int, _ lista: [VolumeSemana]) {
        guard let limites = limites(lista) else { return }
        // Alinha no começo da semana/mês antes de andar (a rolagem com o dedo para em qualquer ponto).
        let base = calendario.dateInterval(of: unidadeTempo, for: inicioVisivel)?.start ?? inicioVisivel
        let alvo = calendario.date(byAdding: unidadeTempo, value: passo, to: base) ?? base
        selecionada = nil
        withAnimation(.snappy) { inicioVisivel = min(max(alvo, limites.min), limites.max) }
    }

    private func navegacao(_ lista: [VolumeSemana]) -> some View {
        let limites = limites(lista)
        let fim = calendario.date(byAdding: unidadeTempo, value: Self.visiveis(modo), to: inicioVisivel)?.addingTimeInterval(-86_400) ?? inicioVisivel
        return HStack {
            Button { andar(-1, lista) } label: {
                Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 36)
            }
            .disabled(limites.map { inicioVisivel <= $0.min } ?? true)
            .accessibilityLabel(modo == .semanas ? L("Semana anterior", "Previous week") : L("Mês anterior", "Previous month"))
            Spacer()
            Text(modo == .semanas
                 ? inicioVisivel.formatted(.dateTime.day().month(.abbreviated)) + " – " + fim.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits))
                 : inicioVisivel.formatted(.dateTime.month(.abbreviated)) + " – " + fim.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Spacer()
            Button { andar(1, lista) } label: {
                Image(systemName: "chevron.right").font(.headline).frame(width: 44, height: 36)
            }
            .disabled(limites.map { inicioVisivel >= $0.max } ?? true)
            .accessibilityLabel(modo == .semanas ? L("Próxima semana", "Next week") : L("Próximo mês", "Next month"))
        }
        .buttonStyle(.borderless)
    }

    /// Os números da barra sob o dedo, numa linha fixa acima do gráfico (o dedo não cobre).
    private func leitura(_ lista: [VolumeSemana]) -> some View {
        let escolhida = item(de: selecionada, em: lista)
        return HStack(alignment: .firstTextBaseline) {
            if let s = escolhida {
                Text(rotulo(s.inicio)).font(.subheadline.weight(.semibold))
                Spacer()
                Text(s.inicio > agoraNaUnidade
                     ? (s.planejado.map { km($0) + L(" planejados", " planned") } ?? "—")
                     : km(s.feito) + (s.planejado.map { L(" de ", " of ") + km($0) } ?? ""))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            } else {
                Text(L("Segure o dedo numa barra para ver os números", "Press and hold a bar to see its numbers"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(minHeight: 22)
        .animation(nil, value: selecionada)
    }

    private var agoraNaUnidade: Date {
        modo == .semanas ? CalendarioTreino.inicioDaSemana(.now) : (calendario.dateInterval(of: .month, for: .now)?.start ?? .now)
    }

    // MARK: Gráfico

    private func grafico(_ lista: [VolumeSemana]) -> some View {
        let atual = agoraNaUnidade
        let escolhida = item(de: selecionada, em: lista)
        let maximo = lista.map { valor(max($0.feito, $0.planejado ?? 0)) }.max() ?? 0
        let unidadeX: Calendar.Component = unidadeTempo
        let duracaoVisivel = Double(Self.visiveis(modo)) * (modo == .semanas ? 7 : 30.44) * 86_400
        return Chart {
            ForEach(lista) { s in
                if let p = s.planejado {
                    // Sem empilhar: o planejado fica atrás do feito, na mesma coluna.
                    BarMark(x: .value("Período", s.inicio, unit: unidadeX), y: .value("Planejado", valor(p)),
                            width: .ratio(0.8), stacking: .unstacked)
                        .foregroundStyle(Color.primary.opacity(escolhida?.inicio == s.inicio ? 0.24 : 0.14))
                        .cornerRadius(4)
                }
            }
            ForEach(lista) { s in
                BarMark(x: .value("Período", s.inicio, unit: unidadeX), y: .value("Feito", valor(s.feito)),
                        width: .ratio(0.45), stacking: .unstacked)
                    .foregroundStyle(Self.verde.opacity(s.inicio > atual ? 0 : (s.inicio == atual || escolhida?.inicio == s.inicio ? 1 : 0.8)))
                    .cornerRadius(4)
                    .annotation(position: .top, spacing: 4) {
                        // Rótulo só no período atual (rótulos seletivos); os outros vêm no toque.
                        if s.inicio == atual, escolhida == nil, s.feito > 0 {
                            Text(numero(s.feito))
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
            }
            if let escolhida {
                RuleMark(x: .value("Período", escolhida.inicio, unit: unidadeX))
                    .foregroundStyle(Color.primary.opacity(0.25))
            }
        }
        .chartXSelection(value: $selecionada)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: duracaoVisivel)
        .chartScrollPosition(x: $inicioVisivel)
        .chartYScale(domain: 0...max(1, maximo * 1.12))
        .chartXAxis {
            if modo == .semanas {
                AxisMarks(values: .stride(by: .weekOfYear, count: 1)) { _ in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.05))
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits), centered: true)
                }
            } else {
                AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                AxisValueLabel()
            }
        }
        .chartYAxisLabel(unidade.sigla)
        .accessibilityLabel(modo == .semanas ? L("Volume por semana", "Weekly volume") : L("Volume por mês", "Monthly volume"))
        .accessibilityValue(lista.filter { $0.inicio <= atual }.suffix(4).map { rotulo($0.inicio) + ": " + km($0.feito) }.joined(separator: "; "))
    }

    private func legenda(comPlano: Bool) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Self.verde).frame(width: 10, height: 12)
                Text("Feito").font(.caption).foregroundStyle(.secondary)
            }
            if comPlano {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.14)).frame(width: 14, height: 12)
                    Text("Planejado").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(L("Arraste para os lados", "Swipe sideways")).font(.caption).foregroundStyle(.tertiary)
        }
    }

    // MARK: Tabela (a mesma informação sem depender do gráfico)

    private func tabela(_ lista: [VolumeSemana]) -> some View {
        let atual = agoraNaUnidade
        return VStack(alignment: .leading, spacing: 10) {
            Text(modo == .semanas ? L("Semana a semana", "Week by week") : L("Mês a mês", "Month by month")).font(.headline)
            ForEach(lista.filter { $0.inicio <= atual }) { s in
                HStack {
                    Text(rotulo(s.inicio) + (s.inicio == atual ? (modo == .semanas ? L(" (esta)", " (this week)") : L(" (este)", " (this month)")) : ""))
                        .font(.subheadline)
                    Spacer()
                    Text(km(s.feito)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    if let p = s.planejado {
                        Text("/ " + km(p)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Ajudas

    private func item(de data: Date?, em lista: [VolumeSemana]) -> VolumeSemana? {
        guard let data else { return nil }
        return lista.last { $0.inicio <= data }
    }

    private func valor(_ metros: Double) -> Double { Formatador.distanciaNaUnidade(metros, unidade: unidade) }

    private func numero(_ metros: Double) -> String { Formatador.numero(valor(metros), casas: 1) }

    private func km(_ metros: Double) -> String { numero(metros) + " " + unidade.sigla }

    private func rotulo(_ inicio: Date) -> String {
        guard modo == .semanas else { return inicio.formatted(.dateTime.month(.wide).year()) }
        let fim = inicio.addingTimeInterval(6 * 86_400)
        return inicio.formatted(.dateTime.day().month(.abbreviated)) + "–" + fim.formatted(.dateTime.day().month(.abbreviated))
    }

    private func bloco(_ titulo: String, _ valor: String, _ detalhe: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.caption).foregroundStyle(.secondary)
            Text(valor).font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit()
            if let detalhe {
                Text(detalhe).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
