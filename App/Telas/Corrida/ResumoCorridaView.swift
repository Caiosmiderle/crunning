import CrunningCore
import SwiftData
import SwiftUI

/// Fim da corrida: números, mapa, parciais, planejado x feito por bloco, esforço percebido,
/// e salvar ou descartar. Na esteira, pede a distância; no teste, oferece atualizar os ritmos.
struct ResumoCorridaView: View {
    let gravador: GravadorCorrida
    @Environment(EstadoApp.self) var estadoApp
    @Environment(\.modelContext) var contexto
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage(Preferencias.provaDistancia) var distanciaReferencia: Double = 5000
    @AppStorage(Preferencias.provaTempo) var tempoReferencia: Double = 0
    @State var esforco: Int?
    @State var confirmandoDescarte = false
    @State var textoDistanciaEsteira = ""
    @State var ritmosAtualizados = false

    var body: some View {
        let sessao = gravador.sessao
        let fim = sessao.fim ?? gravador.agora
        let execucao = gravador.execucao
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Selo(texto: selo, icone: "checkmark.circle.fill")
                    Text(execucao.map { $0.treino.nome } ?? "Corrida concluída")
                        .font(.system(.largeTitle, design: .default, weight: .light))
                        .tracking(-0.8)

                    if gravador.esteira {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Distância na esteira")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            HStack {
                                TextField("Ex.: 5,2", text: $textoDistanciaEsteira)
                                    .keyboardType(.decimalPad)
                                    .font(.title2.weight(.semibold))
                                    .monospacedDigit()
                                Text(unidade.sigla).font(.title3).foregroundStyle(.secondary)
                            }
                            Text("O que o painel da esteira mostrou. Sem GPS, o app mede só o tempo.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .cartaoVidro()
                    }

                    Grid(horizontalSpacing: 16, verticalSpacing: 14) {
                        GridRow {
                            Metrica(titulo: "Distância", valor: Formatador.distancia(distanciaFinal(sessao), unidade: unidade))
                            Metrica(titulo: "Tempo em movimento", valor: Formatador.duracao(sessao.tempoEmMovimento(em: fim)))
                        }
                        GridRow {
                            Metrica(titulo: "Ritmo médio", valor: ritmoMedio(sessao, fim: fim))
                            Metrica(titulo: "Subida", valor: gravador.esteira ? "—" : "\(Int(sessao.subida.rounded())) m")
                        }
                    }
                    .padding(20)
                    .cartaoVidro()

                    if let execucao, execucao.comecou {
                        TabelaBlocos(resultados: execucao.resultados, unidade: unidade)
                            .padding(20)
                            .cartaoVidro()
                    }

                    if let teste = execucao?.resultadoTeste {
                        cartaoTeste(distancia: teste.distancia, tempo: teste.tempo)
                    }

                    if sessao.amostras.count >= 2 {
                        MapaTrilha(amostras: sessao.amostras)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    let parciais = Parciais.calcular(sessao.amostras, comprimento: unidade.metros)
                    if !parciais.isEmpty {
                        ListaParciais(parciais: parciais, unidade: unidade)
                            .padding(20)
                            .cartaoVidro()
                    }

                    SeletorEsforco(valor: $esforco)
                        .padding(20)
                        .cartaoVidro()

                    Button {
                        gravador.salvar(em: contexto, esforco: esforco, distanciaEsteira: gravador.esteira ? distanciaEsteiraMetros : nil)
                        estadoApp.gravadorAtivo = nil
                    } label: {
                        Text("Salvar corrida")
                            .font(.headline)
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Paleta.verdeLogo, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Button("Descartar", role: .destructive) {
                        confirmandoDescarte = true
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background { FundoView() }
            .confirmationDialog("Descartar esta corrida?", isPresented: $confirmandoDescarte, titleVisibility: .visible) {
                Button("Descartar corrida", role: .destructive) {
                    gravador.descartar()
                    estadoApp.gravadorAtivo = nil
                }
            } message: {
                Text("Ela não vai para o histórico e não dá para desfazer.")
            }
        }
    }

    private var selo: String {
        if gravador.execucao != nil { return "Treino concluído" }
        if gravador.esteira { return "Esteira" }
        return gravador.simulada ? "Simulação" : "Corrida livre"
    }

    /// Distância digitada (na unidade escolhida), em metros.
    private var distanciaEsteiraMetros: Double? {
        let texto = textoDistanciaEsteira.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let valor = Double(texto), valor > 0, valor < 200 else { return nil }
        return valor * unidade.metros
    }

    private func distanciaFinal(_ sessao: SessaoCorrida) -> Double {
        gravador.esteira ? (distanciaEsteiraMetros ?? 0) : sessao.distancia
    }

    private func ritmoMedio(_ sessao: SessaoCorrida, fim: Date) -> String {
        let distancia = distanciaFinal(sessao)
        guard distancia >= 50 else { return "--:--" }
        let ritmo = sessao.tempoEmMovimento(em: fim) / distancia * 1000
        return Formatador.ritmo(segundosPorKm: ritmo, unidade: unidade) + " " + unidade.siglaRitmo
    }

    private func cartaoTeste(distancia: Double, tempo: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Resultado do teste", systemImage: "stopwatch")
                .font(.headline)
            Text("\(TextoTreino.medida(.distancia(distancia))) em \(Formatador.duracao(tempo))")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            if let zonas = Zonas(distanciaMetros: distancia, tempoSegundos: tempo) {
                Text("Ritmos novos: fácil \(TextoTreino.faixa(zonas.faixa(.facil), unidade: unidade)), limiar \(TextoTreino.faixa(zonas.faixa(.limiar), unidade: unidade)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if ritmosAtualizados {
                    Label("Meus ritmos atualizados", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Paleta.verdeLogo)
                } else {
                    Button("Usar como prova de referência") {
                        distanciaReferencia = distancia
                        tempoReferencia = tempo.rounded()
                        ritmosAtualizados = true
                    }
                    .buttonStyle(.glass)
                }
            } else {
                Text("Esse tempo ficou fora da faixa em que o cálculo dos ritmos funciona.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }
}
