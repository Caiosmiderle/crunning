import CrunningCore
import SwiftData
import SwiftUI

/// Dados da corrida copiados para a tela, para ela continuar segura mesmo
/// depois que a corrida é apagada (o SwiftData invalida o objeto apagado).
struct DadosCorrida {
    var titulo: String
    var inicio: Date
    var distancia: Double
    var duracaoEmMovimento: TimeInterval
    var duracaoTotal: TimeInterval
    var subida: Double
    var esforco: Int?
    var simulada: Bool

    init(_ corrida: Corrida) {
        titulo = corrida.titulo
        inicio = corrida.inicio
        distancia = corrida.distanciaMetros
        duracaoEmMovimento = corrida.duracaoEmMovimento
        duracaoTotal = corrida.duracaoTotal
        subida = corrida.subidaMetros
        esforco = corrida.esforcoPercebido
        simulada = corrida.simulada
    }
}

struct DetalheCorridaView: View {
    let corrida: Corrida
    @Environment(\.modelContext) var contexto
    @Environment(\.dismiss) var fechar
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros

    @State var dados: DadosCorrida
    @State var amostras: [AmostraTrilha] = []
    @State var serieRitmo: [PontoSerie] = []
    @State var serieAltitude: [PontoSerie] = []
    @State var arquivoGPX: URL?
    @State var carregou = false
    @State var confirmandoApagar = false

    init(corrida: Corrida) {
        self.corrida = corrida
        _dados = State(initialValue: DadosCorrida(corrida))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(dados.inicio.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute().locale(.ptBR)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Grid(horizontalSpacing: 16, verticalSpacing: 14) {
                    GridRow {
                        Metrica(titulo: "Distância", valor: Formatador.distancia(dados.distancia, unidade: unidade))
                        Metrica(titulo: "Tempo em movimento", valor: Formatador.duracao(dados.duracaoEmMovimento))
                    }
                    GridRow {
                        Metrica(titulo: "Ritmo médio", valor: ritmoMedio)
                        Metrica(titulo: "Tempo total", valor: Formatador.duracao(dados.duracaoTotal))
                    }
                    GridRow {
                        Metrica(titulo: "Subida", valor: "\(Int(dados.subida.rounded())) m")
                        Metrica(titulo: "Esforço", valor: dados.esforco.map { "\($0) de 10" } ?? "—")
                    }
                }
                .padding(20)
                .cartaoVidro()

                if amostras.count >= 2 {
                    MapaTrilha(amostras: amostras)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    let parciais = Parciais.calcular(amostras, comprimento: unidade.metros)
                    if !parciais.isEmpty {
                        ListaParciais(parciais: parciais, unidade: unidade)
                            .padding(20)
                            .cartaoVidro()
                    }
                    if !serieRitmo.isEmpty {
                        GraficoRitmo(serie: serieRitmo, unidade: unidade)
                            .padding(20)
                            .cartaoVidro()
                    }
                    if !serieAltitude.isEmpty {
                        GraficoAltitude(serie: serieAltitude, unidade: unidade)
                            .padding(20)
                            .cartaoVidro()
                    }
                } else if carregou {
                    Text("Esta corrida não tem rota gravada.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cartaoVidro()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { FundoView() }
        .navigationTitle(dados.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let arquivoGPX {
                        ShareLink(item: arquivoGPX) {
                            Label("Exportar GPX", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("Apagar corrida", systemImage: "trash", role: .destructive) {
                        confirmandoApagar = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Mais opções")
            }
        }
        .confirmationDialog("Apagar esta corrida?", isPresented: $confirmandoApagar, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) {
                let alvo = corrida
                fechar()
                contexto.delete(alvo)
                try? contexto.save()
            }
        } message: {
            Text("Não dá para desfazer.")
        }
        .task { carregar() }
    }

    private var ritmoMedio: String {
        guard dados.distancia > 0 else { return "--:--" }
        return Formatador.ritmo(segundosPorKm: dados.duracaoEmMovimento / dados.distancia * 1000, unidade: unidade) + " " + unidade.siglaRitmo
    }

    private func carregar() {
        guard !carregou else { return }
        amostras = corrida.carregarAmostras()
        serieRitmo = Series.ritmo(amostras)
        serieAltitude = Series.altitude(amostras)
        if amostras.count >= 2 {
            let xml = GPX.gerar(nome: dados.titulo, inicio: dados.inicio, amostras: amostras)
            let nome = "crunning-" + dados.inicio.formatted(.iso8601.year().month().day().dateSeparator(.dash)) + ".gpx"
            let url = FileManager.default.temporaryDirectory.appending(path: nome)
            if (try? xml.write(to: url, atomically: true, encoding: .utf8)) != nil {
                arquivoGPX = url
            }
        }
        carregou = true
    }
}
