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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ritmo")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart(serie) { ponto in
                LineMark(
                    x: .value("Distância", ponto.distancia / unidade.metros),
                    y: .value("Ritmo", ponto.valor)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
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
        .accessibilityLabel("Gráfico do ritmo ao longo da corrida")
    }
}

struct GraficoAltitude: View {
    let serie: [PontoSerie]
    let unidade: UnidadeDistancia

    var body: some View {
        let minimo = serie.map(\.valor).min() ?? 0
        VStack(alignment: .leading, spacing: 10) {
            Text("Altitude")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart(serie) { ponto in
                AreaMark(
                    x: .value("Distância", ponto.distancia / unidade.metros),
                    yStart: .value("Base", minimo - 5),
                    yEnd: .value("Altitude", ponto.valor)
                )
                .foregroundStyle(LinearGradient(colors: [TipoTreino.longao.cor.opacity(0.5), TipoTreino.longao.cor.opacity(0.05)],
                                                startPoint: .top, endPoint: .bottom))
                LineMark(
                    x: .value("Distância", ponto.distancia / unidade.metros),
                    y: .value("Altitude", ponto.valor)
                )
                .foregroundStyle(TipoTreino.longao.cor)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel("m")
            .chartXAxisLabel(unidade.sigla)
            .frame(height: 140)
        }
        .accessibilityLabel("Gráfico da altitude ao longo da corrida")
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
