import Charts
import CrunningCore
import SwiftData
import SwiftUI

/// Volume por semana: o que foi corrido (barra verde) e o que o plano pedia (barra cinza larga,
/// atrás). Aberto pelo cartão "Esta semana" do Hoje. Sem simulações nem corridas de exemplo.
struct VolumeSemanalView: View {
    @Query(sort: \Corrida.inicio) var corridas: [Corrida]
    @Query var ativos: [PlanoAtivo]
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @State var selecionada: Date?

    /// Verde da marca escurecido para gráfico (validado: faixa de luminosidade e contraste com o
    /// fundo nos dois temas). O planejado é neutro de propósito: é referência, não série.
    static let verde = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0x62 / 255, green: 0xA6 / 255, blue: 0, alpha: 1)
        : UIColor(red: 0x4F / 255, green: 0x93 / 255, blue: 0, alpha: 1) })

    private var semanas: [VolumeSemana] {
        let feitas = corridas.filter { !$0.simulada && !$0.exemplo }.map { (inicio: $0.inicio, distancia: $0.distanciaMetros) }
        var plano: [(inicio: Date, distancia: Double)] = []
        if let agenda = ativos.first?.agenda {
            for semana in agenda.plano.semanas {
                plano.append((agenda.data(semana: semana.numero, dia: 0), semana.volumeTreino))
            }
        }
        return VolumeSemanal.calcular(corridas: feitas, plano: plano, hoje: .now)
    }

    var body: some View {
        let lista = semanas
        let atual = CalendarioTreino.inicioDaSemana(.now)
        let estaSemana = lista.first { $0.inicio == atual }
        let passada = lista.last { $0.inicio < atual }
        let variacao = VolumeSemanal.variacao(lista, hoje: .now)
        let media = VolumeSemanal.media(lista, ultimas: 4, hoje: .now)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        bloco("Esta semana", km(estaSemana?.feito ?? 0),
                              estaSemana?.planejado.map { "de " + km($0) + " planejados" })
                        bloco("Semana passada", km(passada?.feito ?? 0),
                              variacao.map { ($0 >= 0 ? "+" : "−") + "\(Int((abs($0) * 100).rounded()))% sobre a anterior" })
                    }
                    GridRow {
                        bloco("Média de 4 semanas", km(media), nil)
                        Color.clear.frame(height: 1)
                    }
                }
                .padding(18)
                .cartaoVidro(raio: 24)

                VStack(alignment: .leading, spacing: 12) {
                    grafico(lista, atual: atual)
                        .frame(height: 220)
                    legenda(comPlano: lista.contains { $0.planejado != nil })
                }
                .padding(18)
                .cartaoVidro(raio: 24)

                tabela(lista.reversed(), atual: atual)
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
    }

    // MARK: Gráfico

    private func grafico(_ lista: [VolumeSemana], atual: Date) -> some View {
        let escolhida = semana(de: selecionada, em: lista)
        return Chart {
            ForEach(lista) { s in
                if let p = s.planejado {
                    // Sem empilhar: o planejado fica atrás do feito, na mesma coluna.
                    BarMark(x: .value("Semana", s.inicio, unit: .weekOfYear), y: .value("Planejado", valor(p)),
                            width: .ratio(0.8), stacking: .unstacked)
                        .foregroundStyle(Color.primary.opacity(0.14))
                        .cornerRadius(4)
                }
            }
            ForEach(lista) { s in
                BarMark(x: .value("Semana", s.inicio, unit: .weekOfYear), y: .value("Feito", valor(s.feito)),
                        width: .ratio(0.45), stacking: .unstacked)
                    .foregroundStyle(Self.verde.opacity(s.inicio > atual ? 0 : (s.inicio == atual ? 1 : 0.85)))
                    .cornerRadius(4)
                    .annotation(position: .top, spacing: 4) {
                        // Rótulo só na semana atual (rótulos seletivos); os outros vêm no toque.
                        if s.inicio == atual, escolhida == nil, s.feito > 0 {
                            Text(numero(s.feito))
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
            }
            if let escolhida {
                RuleMark(x: .value("Semana", escolhida.inicio, unit: .weekOfYear))
                    .foregroundStyle(Color.primary.opacity(0.25))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        balao(escolhida)
                    }
            }
        }
        .chartXSelection(value: $selecionada)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                AxisValueLabel()
            }
        }
        .chartYAxisLabel(unidade.sigla)
        .accessibilityLabel("Volume por semana")
        .accessibilityValue(lista.suffix(4).map { intervalo($0.inicio) + ": " + km($0.feito) }.joined(separator: "; "))
    }

    private func balao(_ s: VolumeSemana) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(intervalo(s.inicio)).font(.caption.weight(.semibold))
            Text(km(s.feito) + (s.planejado.map { " de " + km($0) } ?? "")).font(.caption).monospacedDigit()
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            Text("Toque numa semana para ver").font(.caption).foregroundStyle(.tertiary)
        }
    }

    // MARK: Tabela (a mesma informação sem depender do gráfico)

    private func tabela(_ lista: [VolumeSemana], atual: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Semana a semana").font(.headline)
            ForEach(lista.filter { $0.inicio <= atual }) { s in
                HStack {
                    Text(intervalo(s.inicio) + (s.inicio == atual ? " (esta)" : ""))
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

    private func semana(de data: Date?, em lista: [VolumeSemana]) -> VolumeSemana? {
        guard let data else { return nil }
        return lista.last { $0.inicio <= data }
    }

    private func valor(_ metros: Double) -> Double { Formatador.distanciaNaUnidade(metros, unidade: unidade) }

    private func numero(_ metros: Double) -> String { Formatador.numero(valor(metros), casas: 1) }

    private func km(_ metros: Double) -> String { numero(metros) + " " + unidade.sigla }

    private func intervalo(_ inicio: Date) -> String {
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
