import Charts
import CrunningCore
import MapKit
import SwiftUI

// MARK: - Métrica

/// Número de corrida com legenda. `grande` para a tela de corrida (legível de relance).
struct Metrica: View {
    let titulo: String
    let valor: String
    var grande: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(grande ? .subheadline.weight(.semibold) : .caption)
                .foregroundStyle(.secondary)
            Text(valor)
                .font(.system(grande ? .largeTitle : .title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sinal do GPS

extension QualidadeGPS {
    var texto: String {
        switch self {
        case .procurando: L("Procurando GPS", "Searching for GPS")
        case .fraco: L("GPS fraco", "Weak GPS")
        case .bom: L("GPS bom", "Good GPS")
        case .otimo: L("GPS ótimo", "Great GPS")
        case .simulado: L("GPS simulado", "Simulated GPS")
        case .esteira: L("Esteira", "Treadmill")
        }
    }

    var cor: Color {
        switch self {
        case .procurando: .secondary
        case .fraco: Paleta.foraForte
        case .bom: Paleta.foraLeve
        case .otimo, .simulado, .esteira: Paleta.dentroDaFaixa
        }
    }
}

struct IndicadorGPS: View {
    let qualidade: QualidadeGPS

    var body: some View {
        Label(qualidade.texto, systemImage: qualidade == .esteira ? "figure.run.treadmill" : qualidade == .simulado ? "location.circle" : "location.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(qualidade.cor)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(qualidade.cor.opacity(0.15), in: Capsule())
    }
}

// MARK: - Mapa

/// Escala de cor do ritmo: lento em azul, médio no verde da marca, rápido em laranja.
struct EscalaRitmo {
    private let rapido: Double
    private let lento: Double
    private static let cores: [Color] = [
        Color(hex: 0xFF7A3D), Color(hex: 0xFFC53D), Paleta.verdeLogo, Color(hex: 0x3FC8B0), Color(hex: 0x4DA3FF),
    ]

    init(ritmos: [Double]) {
        let ordenados = ritmos.sorted()
        guard !ordenados.isEmpty else {
            rapido = 0
            lento = 1
            return
        }
        rapido = ordenados[Int(Double(ordenados.count - 1) * 0.1)]
        lento = ordenados[Int(Double(ordenados.count - 1) * 0.9)]
    }

    func cor(_ ritmo: Double?) -> Color {
        guard let ritmo, lento > rapido else { return Paleta.verdeLogo }
        let t = min(1, max(0, (ritmo - rapido) / (lento - rapido)))
        return Self.cores[Int((t * Double(Self.cores.count - 1)).rounded())]
    }
}

struct MapaTrilha: View {
    let trechos: [TrechoMapa]
    let escala: EscalaRitmo
    let inicio: CLLocationCoordinate2D?
    let fim: CLLocationCoordinate2D?

    init(amostras: [AmostraTrilha]) {
        trechos = Trechos.dividir(amostras)
        escala = EscalaRitmo(ritmos: trechos.compactMap(\.ritmo))
        inicio = amostras.first.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        fim = amostras.last.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            ForEach(trechos) { trecho in
                MapPolyline(coordinates: trecho.coordenadas.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) })
                    .stroke(escala.cor(trecho.ritmo), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            if let inicio {
                Annotation("Início", coordinate: inicio) {
                    Circle().fill(Paleta.verdeLogo).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
            if let fim {
                Annotation("Fim", coordinate: fim) {
                    Image(systemName: "flag.checkered.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.white, Color.black)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .accessibilityLabel("Mapa da rota, colorido pelo ritmo")
    }
}

// MARK: - Parciais

struct ListaParciais: View {
    let parciais: [Parcial]
    let unidade: UnidadeDistancia

    var body: some View {
        let maisRapido = parciais.filter(\.completa).map(\.ritmo).min() ?? parciais.map(\.ritmo).min() ?? 1
        VStack(alignment: .leading, spacing: 10) {
            Text("Parciais")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(parciais) { parcial in
                HStack(spacing: 12) {
                    Text(rotulo(parcial))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .frame(width: 64, alignment: .leading)
                    GeometryReader { geo in
                        Capsule()
                            .fill(TipoTreino.facil.cor.opacity(parcial.completa ? 0.9 : 0.45))
                            .frame(width: max(8, geo.size.width * min(1, maisRapido / max(parcial.ritmo, 1))))
                    }
                    .frame(height: 10)
                    Text(Formatador.ritmo(segundosPorKm: parcial.ritmo, unidade: unidade))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(rotulo(parcial)), ritmo \(Formatador.ritmo(segundosPorKm: parcial.ritmo, unidade: unidade)) por \(unidade.sigla)")
            }
        }
    }

    private func rotulo(_ parcial: Parcial) -> String {
        if parcial.completa { return "\(unidade.sigla.capitalized) \(parcial.numero)" }
        return Formatador.distancia(parcial.distancia, unidade: unidade)
    }
}

// MARK: - Gráficos

struct GraficoRitmo: View {
    let serie: [PontoSerie]
    let unidade: UnidadeDistancia
    @State private var selecao: Double?

    var body: some View {
        let ponto = PontoMaisPerto.serie(serie, x: selecao.map { $0 * unidade.metros })
        VStack(alignment: .leading, spacing: 10) {
            CabecalhoGrafico(titulo: L("Ritmo", "Pace"), leitura: ponto.map {
                Formatador.distancia($0.distancia, unidade: unidade, casas: 2) + " · "
                    + Formatador.ritmo(segundosPorKm: $0.valor, unidade: unidade) + " " + unidade.siglaRitmo
            } ?? L("Segure e arraste para ver", "Press and drag to see"))
            Chart {
                ForEach(serie) { p in
                    LineMark(
                        x: .value("dist", p.distancia / unidade.metros),
                        y: .value("ritmo", p.valor)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                if let ponto {
                    RuleMark(x: .value("dist", ponto.distancia / unidade.metros))
                        .foregroundStyle(Color.primary.opacity(0.3))
                    PointMark(x: .value("dist", ponto.distancia / unidade.metros), y: .value("ritmo", ponto.valor))
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(70)
                }
            }
            .chartXSelection(value: $selecao)
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .chartYAxis {
                AxisMarks(position: .leading) { valor in
                    AxisGridLine()
                    AxisValueLabel {
                        if let segundos = valor.as(Double.self) {
                            Text(Formatador.ritmo(segundosPorKm: segundos, unidade: unidade))
                        }
                    }
                }
            }
            .chartXAxisLabel(unidade.sigla)
            .frame(height: 180)
        }
        .accessibilityLabel(L("Gráfico do ritmo ao longo da corrida", "Pace chart over the run"))
    }
}

struct GraficoAltitude: View {
    let serie: [PontoSerie]
    let unidade: UnidadeDistancia
    @State private var selecao: Double?

    var body: some View {
        let minimo = serie.map(\.valor).min() ?? 0
        let ponto = PontoMaisPerto.serie(serie, x: selecao.map { $0 * unidade.metros })
        VStack(alignment: .leading, spacing: 10) {
            CabecalhoGrafico(titulo: L("Altitude", "Elevation"), leitura: ponto.map {
                Formatador.distancia($0.distancia, unidade: unidade, casas: 2) + " · \(Int($0.valor.rounded())) m"
            } ?? L("Segure e arraste para ver", "Press and drag to see"))
            Chart {
                ForEach(serie) { p in
                    AreaMark(
                        x: .value("dist", p.distancia / unidade.metros),
                        yStart: .value("base", minimo - 5),
                        yEnd: .value("alt", p.valor)
                    )
                    .foregroundStyle(LinearGradient(colors: [TipoTreino.longao.cor.opacity(0.5), TipoTreino.longao.cor.opacity(0.05)],
                                                    startPoint: .top, endPoint: .bottom))
                    LineMark(
                        x: .value("dist", p.distancia / unidade.metros),
                        y: .value("alt", p.valor)
                    )
                    .foregroundStyle(TipoTreino.longao.cor)
                }
                if let ponto {
                    RuleMark(x: .value("dist", ponto.distancia / unidade.metros))
                        .foregroundStyle(Color.primary.opacity(0.3))
                    PointMark(x: .value("dist", ponto.distancia / unidade.metros), y: .value("alt", ponto.valor))
                        .foregroundStyle(TipoTreino.longao.cor)
                        .symbolSize(70)
                }
            }
            .chartXSelection(value: $selecao)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel("m")
            .chartXAxisLabel(unidade.sigla)
            .frame(height: 140)
        }
        .accessibilityLabel(L("Gráfico da altitude ao longo da corrida", "Elevation chart over the run"))
    }
}

/// Batimentos ao longo da corrida (média de 10 s). Buracos sem leitura (pulseira sem sinal)
/// ficam em branco. Segurando o dedo, o topo mostra o batimento daquele instante.
struct GraficoFC: View {
    let serie: [FrequenciaCardiaca.PontoGrafico]
    let media: Int?
    let maxima: Int?
    @State private var selecao: Double?

    var body: some View {
        let ponto = PontoMaisPerto.fc(serie, t: selecao.map { $0 * 60 })
        let resumo = [media.map { L("média \($0)", "avg \($0)") }, maxima.map { L("máx \($0)", "max \($0)") }]
            .compactMap { $0 }.joined(separator: " · ")
        VStack(alignment: .leading, spacing: 10) {
            CabecalhoGrafico(titulo: L("Frequência cardíaca", "Heart rate"), leitura: ponto.map {
                Formatador.duracao($0.t) + " · \(Int($0.bpm.rounded())) bpm"
            } ?? (resumo.isEmpty ? L("Segure e arraste para ver", "Press and drag to see") : resumo + " bpm"))
            Chart {
                ForEach(serie) { p in
                    LineMark(
                        x: .value("min", p.t / 60),
                        y: .value("bpm", p.bpm),
                        series: .value("trecho", p.trecho)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Paleta.foraForte)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                if let media, ponto == nil {
                    RuleMark(y: .value("media", media))
                        .foregroundStyle(Color.primary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                if let ponto {
                    RuleMark(x: .value("min", ponto.t / 60))
                        .foregroundStyle(Color.primary.opacity(0.3))
                    PointMark(x: .value("min", ponto.t / 60), y: .value("bpm", ponto.bpm))
                        .foregroundStyle(Paleta.foraForte)
                        .symbolSize(70)
                }
            }
            .chartXSelection(value: $selecao)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxisLabel("bpm")
            .chartXAxisLabel("min")
            .frame(height: 180)
        }
        .accessibilityLabel(L("Gráfico da frequência cardíaca ao longo da corrida", "Heart rate chart over the run"))
    }
}

/// Título do gráfico à esquerda e, à direita, o valor do ponto sob o dedo (ou um resumo). Fica
/// fora do desenho para o dedo não cobrir o número.
struct CabecalhoGrafico: View {
    let titulo: String
    let leitura: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(leitura)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .animation(nil, value: leitura)
    }
}

/// O ponto da série mais perto do x sob o dedo.
enum PontoMaisPerto {
    static func serie(_ serie: [PontoSerie], x: Double?) -> PontoSerie? {
        guard let x else { return nil }
        return serie.min { abs($0.distancia - x) < abs($1.distancia - x) }
    }

    static func fc(_ serie: [FrequenciaCardiaca.PontoGrafico], t: Double?) -> FrequenciaCardiaca.PontoGrafico? {
        guard let t, let p = serie.min(by: { abs($0.t - t) < abs($1.t - t) }), abs(p.t - t) <= 30 else { return nil }
        return p
    }
}

// MARK: - Esforço percebido

/// Escala de 1 a 10 (CR10 de Borg adaptada): quão pesado foi o treino como um todo.
struct SeletorEsforco: View {
    @Binding var valor: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quão pesado foi? (1 a 10)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(1...10, id: \.self) { nota in
                    let selecionado = valor == nota
                    Button {
                        valor = selecionado ? nil : nota
                    } label: {
                        Text("\(nota)")
                            .font(.headline)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selecionado ? Color.black : Color.primary)
                            .background(selecionado ? Paleta.verdeLogo : Color.primary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Esforço \(nota)")
                    .accessibilityAddTraits(selecionado ? .isSelected : [])
                }
            }
            Text(descricao)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var descricao: String {
        guard let valor else { return L("Toque num número. 1 é muito leve, 10 é o máximo que você aguenta.", "Tap a number. 1 is very easy, 10 is the hardest you can handle.") }
        switch valor {
        case ...2: return L("Muito leve", "Very easy")
        case 3...4: return L("Leve: dá para conversar fácil", "Easy: you can chat comfortably")
        case 5...6: return L("Moderado: conversa em frases curtas", "Moderate: you can talk in short sentences")
        case 7...8: return L("Pesado: poucas palavras", "Hard: just a few words")
        default: return L("Máximo ou quase", "Max or close to it")
        }
    }
}
