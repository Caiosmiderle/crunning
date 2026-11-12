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
    var diagnostico: DiagnosticoGPS?
    var resultados: [ResultadoEtapa]
    var esteira: Bool
    var fcMedia: Int?
    var fcMaxima: Int?

    init(_ corrida: Corrida) {
        titulo = corrida.titulo
        inicio = corrida.inicio
        distancia = corrida.distanciaMetros
        duracaoEmMovimento = corrida.duracaoEmMovimento
        duracaoTotal = corrida.duracaoTotal
        subida = corrida.subidaMetros
        esforco = corrida.esforcoPercebido
        simulada = corrida.simulada
        diagnostico = corrida.carregarDiagnostico()
        resultados = corrida.carregarResultados()
        esteira = corrida.esteira
        fcMedia = corrida.fcMedia
        fcMaxima = corrida.fcMaxima
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
    @State var fc: [AmostraFC] = []
    @State var serieFC: [FrequenciaCardiaca.PontoGrafico] = []
    @State var arquivoGPX: URL?
    @State var arquivoTCX: URL?
    @State var carregou = false
    @State var confirmandoApagar = false
    @State var enviandoStrava = false
    @State var compartilhando = false
    @Query(filter: #Predicate<Tenis> { !$0.aposentado }, sort: \Tenis.criadoEm) var tenisAtivos: [Tenis]

    init(corrida: Corrida) {
        self.corrida = corrida
        _dados = State(initialValue: DadosCorrida(corrida))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(dados.inicio.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let nome = tenisAtivos.first(where: { $0.codigo == corrida.tenis })?.nome {
                    Text(L("Tênis: ", "Shoes: ") + nome)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Grid(horizontalSpacing: 16, verticalSpacing: 14) {
                    GridRow {
                        Metrica(titulo: L("Distância", "Distance"), valor: Formatador.distancia(dados.distancia, unidade: unidade))
                        Metrica(titulo: L("Tempo em movimento", "Moving time"), valor: Formatador.duracao(dados.duracaoEmMovimento))
                    }
                    GridRow {
                        Metrica(titulo: L("Ritmo médio", "Avg pace"), valor: ritmoMedio)
                        Metrica(titulo: L("Tempo total", "Total time"), valor: Formatador.duracao(dados.duracaoTotal))
                    }
                    GridRow {
                        Metrica(titulo: L("Subida", "Elevation gain"), valor: "\(Int(dados.subida.rounded())) m")
                        Metrica(titulo: L("Esforço", "Effort"), valor: dados.esforco.map { L("\($0) de 10", "\($0) of 10") } ?? "—")
                    }
                    if let media = dados.fcMedia, let maxima = dados.fcMaxima {
                        GridRow {
                            Metrica(titulo: L("FC média", "Avg HR"), valor: "\(media) bpm")
                            Metrica(titulo: L("FC máxima", "Max HR"), valor: "\(maxima) bpm")
                        }
                    }
                    if let energia = Exportacao.calorias(distancia: dados.distancia, duracaoEmMovimento: dados.duracaoEmMovimento) {
                        GridRow {
                            Metrica(titulo: L("Energia (estimada)", "Energy (estimated)"), valor: "\(Int(energia.rounded())) kcal")
                            Color.clear.frame(height: 1)
                        }
                    }
                }
                .padding(20)
                .cartaoVidro()

                if dados.distancia > 0 {
                    Button {
                        compartilhando = true
                    } label: {
                        Label(L("Compartilhar a corrida", "Share the run"), systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glass)
                    .disabled(!carregou)
                }

                if !dados.resultados.isEmpty {
                    TabelaBlocos(resultados: dados.resultados, unidade: unidade, fc: fc, inicioCorrida: dados.inicio)
                        .padding(20)
                        .cartaoVidro()
                }

                if dados.distancia > 0 || !dados.resultados.isEmpty {
                    CartaoAnaliseTreino(corrida: corrida)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cartaoVidro()
                }

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
                    graficoFC
                    if !serieAltitude.isEmpty {
                        GraficoAltitude(serie: serieAltitude, unidade: unidade)
                            .padding(20)
                            .cartaoVidro()
                    }
                } else if carregou {
                    graficoFC
                    Text(dados.esteira ? L("Corrida na esteira: sem rota.", "Treadmill run: no route.") : L("Esta corrida não tem rota gravada.", "This run has no recorded route."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cartaoVidro()
                }

                if !dados.simulada, Strava.conectado || corrida.stravaAtividade != nil {
                    cartaoStrava
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cartaoVidro()
                }

                if let diagnostico = dados.diagnostico {
                    CartaoDiagnosticoGPS(diagnostico: diagnostico)
                        .padding(20)
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
                    if let arquivoTCX {
                        ShareLink(item: arquivoTCX) {
                            Label("Exportar TCX (para o Saúde)", systemImage: "square.and.arrow.up")
                        }
                    }
                    if let arquivoGPX {
                        ShareLink(item: arquivoGPX) {
                            Label("Exportar GPX", systemImage: "map")
                        }
                    }
                    if !tenisAtivos.isEmpty {
                        Picker(selection: Binding(get: { corrida.tenis }, set: { novo in
                            corrida.tenis = novo
                            try? contexto.save()
                        })) {
                            Text("Nenhum").tag(String?.none)
                            ForEach(tenisAtivos) { t in Text(t.nome).tag(Optional(t.codigo)) }
                        } label: {
                            Label("Tênis desta corrida", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .pickerStyle(.menu)
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
        .sheet(isPresented: $compartilhando) {
            CompartilharCorridaView(corrida: dados, amostras: amostras)
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

    @ViewBuilder
    private var cartaoStrava: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Strava")
                .font(.headline)
            if let id = corrida.stravaAtividade, let url = URL(string: "https://www.strava.com/activities/\(id)") {
                Link(destination: url) {
                    Label("Ver no Strava", systemImage: "arrow.up.right.square")
                }
            } else if enviandoStrava || (corrida.stravaPendente && corrida.stravaErro == nil) {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(enviandoStrava ? L("Enviando ao Strava…", "Sending to Strava…") : L("Na fila: vai sozinha quando houver internet.", "Queued: it will go on its own when there is internet."))
                        .font(.subheadline)
                }
            } else {
                if let erro = corrida.stravaErro {
                    Text(corrida.stravaPendente ? erro + L(" Vai tentar de novo sozinho.", " It will retry on its own.") : erro)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(corrida.stravaErro == nil ? L("Enviar ao Strava", "Send to Strava") : L("Tentar de novo", "Try again"), systemImage: "arrow.up.circle") {
                    enviandoStrava = true
                    Task {
                        await EnvioStrava.enfileirar(corrida)
                        enviandoStrava = false
                    }
                }
                .buttonStyle(.glass)
            }
        }
    }

    @ViewBuilder
    private var graficoFC: some View {
        if serieFC.count >= 2 {
            GraficoFC(serie: serieFC, media: dados.fcMedia, maxima: dados.fcMaxima)
                .padding(20)
                .cartaoVidro()
        }
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
        fc = corrida.carregarFC()
        serieFC = FrequenciaCardiaca.serieGrafico(fc)
        let arquivos = Exportacao.arquivos(de: corrida, amostras: amostras)
        arquivoTCX = arquivos.tcx
        arquivoGPX = arquivos.gpx
        carregou = true
    }
}

/// Como o GPS se comportou: prova (ou não) que a gravação seguiu com a tela bloqueada.
struct CartaoDiagnosticoGPS: View {
    let diagnostico: DiagnosticoGPS
    @State var aberto = false

    var body: some View {
        DisclosureGroup(isExpanded: $aberto) {
            VStack(alignment: .leading, spacing: 10) {
                linha(L("Pontos com o app na tela", "Points with the app on screen"), "\(diagnostico.pontosPrimeiroPlano)")
                linha(L("Pontos com a tela bloqueada ou o app em segundo plano", "Points with the screen locked or the app in the background"), "\(diagnostico.pontosSegundoPlano)")
                linha(L("Maior intervalo sem ponto", "Longest gap without a point"), maiorIntervalo)
                linha(L("Intervalos de \(Int(DiagnosticoGPS.intervaloLongo)) s ou mais", "Gaps of \(Int(DiagnosticoGPS.intervaloLongo)) s or more"), "\(diagnostico.intervalosLongos)")
                linha(L("Vezes que o iOS fechou o app", "Times iOS closed the app"), "\(diagnostico.quantas(.reaberto))")
                if !diagnostico.eventos.isEmpty {
                    Divider()
                    ForEach(Array(diagnostico.eventos.suffix(30).enumerated()), id: \.offset) { _, evento in
                        HStack(alignment: .firstTextBaseline) {
                            Text(evento.instante.formatted(.dateTime.hour().minute().second()))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Text(evento.tipo.descricao)
                                .foregroundStyle(evento.tipo.ehProblema ? Paleta.foraForte : Color.primary)
                        }
                        .font(.footnote)
                    }
                    if diagnostico.eventos.count > 30 || diagnostico.eventosDescartados > 0 {
                        Text("Mostrando os 30 últimos avisos.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: diagnostico.temProblema ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .foregroundStyle(diagnostico.temProblema ? Paleta.foraLeve : Paleta.verdeLogo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sinal do GPS")
                        .font(.headline)
                    Text(resumo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
        .accessibilityElement(children: .contain)
    }

    private var resumo: String {
        if diagnostico.quantas(.reaberto) > 0 { return L("O iOS fechou o app no meio; a corrida foi retomada.", "iOS closed the app midway; the run was resumed.") }
        if diagnostico.maiorIntervalo >= DiagnosticoGPS.intervaloLongo { return L("Ficou \(maiorIntervalo) sem ponto.", "Went \(maiorIntervalo) without a point.") }
        if diagnostico.eventos.contains(where: { $0.tipo.ehProblema }) { return L("O iOS avisou de problemas no GPS.", "iOS reported GPS problems.") }
        return L("Gravou sem falhas.", "Recorded without gaps.")
    }

    private var maiorIntervalo: String {
        let segundos = diagnostico.maiorIntervalo
        guard segundos >= 1 else { return L("menos de 1 s", "less than 1 s") }
        return segundos < 60 ? "\(Int(segundos.rounded())) s" : Formatador.duracao(segundos)
    }

    private func linha(_ titulo: String, _ valor: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(valor)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
