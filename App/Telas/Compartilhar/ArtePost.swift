import CrunningCore
import SwiftUI

/// O que a imagem de compartilhar mostra, já pronto (sem SwiftData nem coordenadas cruas).
struct DadosPost {
    var titulo: String
    var inicio: Date
    var distancia: Double
    var duracao: TimeInterval
    var subida: Double
    var fcMedia: Int?
    var esteira: Bool
    /// Forma da rota já aparada e normalizada (vazia sem rota ou com a rota escondida).
    var forma: [[RotaCompartilhada.Ponto]]
    var parciais: [Parcial]

    func ritmo(_ unidade: UnidadeDistancia) -> String {
        guard distancia > 0 else { return "--:--" }
        return Formatador.ritmo(segundosPorKm: duracao / distancia * 1000, unidade: unidade) + " " + unidade.siglaRitmo
    }
}

/// Modelos da imagem. Os "adesivos" têm fundo transparente para colar sobre uma foto (copiar e
/// colar no story); o cartão e o mapa têm fundo próprio.
enum ModeloPost: String, CaseIterable, Identifiable {
    case numeros, rota, faixa, parciais, cartao, mapa

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .numeros: L("Números", "Stats")
        case .rota: L("Rota", "Route")
        case .faixa: L("Faixa", "Strip")
        case .parciais: L("Parciais", "Splits")
        case .cartao: L("Cartão", "Card")
        case .mapa: L("Mapa", "Map")
        }
    }

    var transparente: Bool { self != .cartao && self != .mapa }
    var precisaRota: Bool { self == .rota || self == .mapa }
}

/// Tamanho da arte em pontos (9:16). Renderizada a 3× sai 1080 × 1920, o tamanho do story.
enum TamanhoPost {
    static let largura: CGFloat = 360
    static let altura: CGFloat = 640
}

/// A forma da rota desenhada num retângulo, sem distorcer.
struct FormaRota: Shape {
    let tracos: [[RotaCompartilhada.Ponto]]

    func path(in rect: CGRect) -> Path {
        let lado = min(rect.width, rect.height)
        let ox = rect.minX + (rect.width - lado) / 2, oy = rect.minY + (rect.height - lado) / 2
        var p = Path()
        for traco in tracos {
            guard let primeiro = traco.first else { continue }
            p.move(to: CGPoint(x: ox + primeiro.x * lado, y: oy + primeiro.y * lado))
            for ponto in traco.dropFirst() {
                p.addLine(to: CGPoint(x: ox + ponto.x * lado, y: oy + ponto.y * lado))
            }
        }
        return p
    }
}

/// A arte de um modelo, no tamanho do story. Texto branco com sombra leve nos adesivos, para
/// ler sobre qualquer foto.
struct ArtePost: View {
    let modelo: ModeloPost
    let dados: DadosPost
    let unidade: UnidadeDistancia
    /// Fundo do modelo Mapa (já com a rota desenhada), quando pronto.
    var mapa: UIImage?

    var body: some View {
        Group {
            switch modelo {
            case .numeros: numeros
            case .rota: rota
            case .faixa: faixa
            case .parciais: parciais
            case .cartao: cartao
            case .mapa: mapaArte
            }
        }
        .frame(width: TamanhoPost.largura, height: TamanhoPost.altura)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Peças

    private var distanciaTexto: String { Formatador.distancia(dados.distancia, unidade: unidade) }
    private var tempoTexto: String { Formatador.duracao(dados.duracao) }

    private func marca(_ largura: CGFloat, cor: Color = .white) -> some View {
        Image("Marca")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: largura)
            .foregroundStyle(cor)
    }

    private func bloco(_ titulo: String, _ valor: String, tamanho: CGFloat = 30) -> some View {
        VStack(spacing: 1) {
            Text(titulo.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .opacity(0.85)
            Text(valor)
                .font(.system(size: tamanho, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
    }

    private var traco: some View {
        FormaRota(tracos: dados.forma)
            .stroke(Paleta.verdeLogo, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
    }

    // MARK: Modelos

    private var numeros: some View {
        VStack(spacing: 14) {
            Spacer()
            bloco(L("Distância", "Distance"), distanciaTexto, tamanho: 40)
            bloco(L("Pace", "Pace"), dados.ritmo(unidade))
            bloco(L("Tempo", "Time"), tempoTexto)
            if let fc = dados.fcMedia { bloco(L("FC média", "Avg HR"), "\(fc) bpm") }
            if !dados.forma.isEmpty {
                traco.frame(width: 150, height: 110).padding(.top, 6)
            }
            marca(150).padding(.top, 10)
            Spacer()
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
    }

    private var rota: some View {
        VStack(spacing: 18) {
            Spacer()
            traco.frame(width: 260, height: 260)
            HStack(spacing: 22) {
                bloco(L("Distância", "Distance"), distanciaTexto, tamanho: 20)
                bloco(L("Pace", "Pace"), dados.ritmo(unidade), tamanho: 20)
                bloco(L("Tempo", "Time"), tempoTexto, tamanho: 20)
            }
            marca(120)
            Spacer()
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
    }

    private var faixa: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    pilula(dados.inicio.formatted(.dateTime.day().month(.abbreviated)))
                    pilula(distanciaTexto)
                    pilula(dados.ritmo(unidade))
                }
                HStack(spacing: 8) {
                    pilula(tempoTexto)
                    if let fc = dados.fcMedia { pilula("\(fc) bpm") }
                    pilula(dados.titulo)
                }
                marca(110).padding(.top, 4)
            }
            .padding(.bottom, 90)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
    }

    private func pilula(_ texto: String) -> some View {
        Text(texto)
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(.white, lineWidth: 1.5))
    }

    private var parciais: some View {
        let lista = Array(dados.parciais.filter { $0.distancia > 0 }.prefix(12))
        let ritmos = lista.map { $0.duracao / $0.distancia * 1000 }
        let maisRapido = ritmos.min() ?? 1, maisLento = ritmos.max() ?? 1
        return VStack(alignment: .leading, spacing: 6) {
            Spacer()
            Text(L("Parciais", "Splits")).font(.system(size: 16, weight: .bold))
            ForEach(Array(lista.enumerated()), id: \.offset) { i, p in
                linhaParcial(p, ritmo: ritmos[i], maisRapido: maisRapido, maisLento: maisLento)
            }
            HStack {
                Spacer()
                marca(110).padding(.top, 8)
                Spacer()
            }
            Spacer()
        }
        .padding(.horizontal, 40)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
    }

    private func linhaParcial(_ p: Parcial, ritmo: Double, maisRapido: Double, maisLento: Double) -> some View {
        // Barra maior = parcial mais rápida.
        let fracao = maisLento > maisRapido ? 0.35 + 0.65 * (maisLento - ritmo) / (maisLento - maisRapido) : 1
        return HStack(spacing: 8) {
            Text(p.completa ? "\(p.numero)" : Formatador.numero(Formatador.distanciaNaUnidade(p.distancia, unidade: unidade), casas: 1))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .frame(width: 28, alignment: .leading)
            Capsule()
                .fill(Paleta.verdeLogo)
                .frame(width: 170 * fracao, height: 12)
            Spacer(minLength: 4)
            Text(Formatador.ritmo(segundosPorKm: ritmo, unidade: unidade))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
        }
    }

    private var cartao: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.07, blue: 0.05), Color(red: 0.10, green: 0.16, blue: 0.03)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 18) {
                marca(130, cor: Paleta.verdeLogo)
                Spacer()
                if !dados.forma.isEmpty {
                    traco.frame(maxWidth: .infinity).frame(height: 230)
                }
                Spacer()
                Text(dados.titulo)
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(2)
                Text(dados.inicio.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 13, weight: .medium))
                    .opacity(0.75)
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                    GridRow {
                        bloco(L("Distância", "Distance"), distanciaTexto, tamanho: 24)
                        bloco(L("Pace", "Pace"), dados.ritmo(unidade), tamanho: 24)
                    }
                    GridRow {
                        bloco(L("Tempo", "Time"), tempoTexto, tamanho: 24)
                        if let fc = dados.fcMedia {
                            bloco(L("FC média", "Avg HR"), "\(fc) bpm", tamanho: 24)
                        } else {
                            bloco(L("Subida", "Gain"), "\(Int(dados.subida.rounded())) m", tamanho: 24)
                        }
                    }
                }
            }
            .padding(32)
            .foregroundStyle(.white)
        }
    }

    private var mapaArte: some View {
        ZStack(alignment: .bottom) {
            if let mapa {
                Image(uiImage: mapa).resizable().scaledToFill()
            } else {
                Color(red: 0.08, green: 0.09, blue: 0.10)
                ProgressView().tint(.white).frame(maxHeight: .infinity)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                Text(dados.titulo).font(.system(size: 22, weight: .bold)).lineLimit(1)
                HStack(spacing: 22) {
                    bloco(L("Distância", "Distance"), distanciaTexto, tamanho: 20)
                    bloco(L("Pace", "Pace"), dados.ritmo(unidade), tamanho: 20)
                    bloco(L("Tempo", "Time"), tempoTexto, tamanho: 20)
                }
                marca(110, cor: Paleta.verdeLogo).padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
        }
        .clipped()
    }
}
