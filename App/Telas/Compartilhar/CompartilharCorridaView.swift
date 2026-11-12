import CoreLocation
import CrunningCore
import MapKit
import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Depois da corrida: escolher um modelo e copiar (para colar como adesivo no story), salvar
/// nas Fotos ou mandar para outro app. A imagem é feita no iPhone e só sai dele quando você
/// escolhe para onde.
struct CompartilharCorridaView: View {
    let corrida: DadosCorrida
    let amostras: [AmostraTrilha]
    @Environment(\.dismiss) var fechar
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    /// Esconde os primeiros e os últimos 200 m da rota (quase sempre a porta de casa).
    @AppStorage("compartilharAparaRota") var aparar = true
    @AppStorage("compartilharMostraRota") var mostrarRota = true
    @State var modelo: ModeloPost = .numeros
    @State var mapa: UIImage?
    @State var arquivo: URL?
    @State var aviso: String?

    private var rotaAparada: [AmostraTrilha] {
        aparar ? RotaCompartilhada.aparar(amostras) : amostras
    }

    private var dados: DadosPost {
        DadosPost(
            titulo: corrida.titulo,
            inicio: corrida.inicio,
            distancia: corrida.distancia,
            duracao: corrida.duracaoEmMovimento,
            subida: corrida.subida,
            fcMedia: corrida.fcMedia,
            esteira: corrida.esteira,
            forma: mostrarRota ? RotaCompartilhada.forma(rotaAparada) : [],
            parciais: Parciais.calcular(amostras, comprimento: unidade.metros)
        )
    }

    private var temRota: Bool { amostras.count >= 2 && !corrida.esteira }

    private var modelos: [ModeloPost] {
        ModeloPost.allCases.filter { m in
            if m.precisaRota && (!temRota || !mostrarRota) { return false }
            if m == .parciais && dados.parciais.count < 2 { return false }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    previa
                    galeria
                    opcoes
                    if let aviso {
                        Text(aviso).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) { acoes }
            .background { FundoView() }
            .navigationTitle(L("Compartilhar", "Share"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Fechar", "Close")) { fechar() }
                }
            }
            .task(id: chaveMapa) { await prepararMapa() }
            .task(id: chaveArquivo) { arquivo = gravarArquivo() }
        }
    }

    // MARK: Telas

    private var previa: some View {
        ArtePost(modelo: modelo, dados: dados, unidade: unidade, mapa: mapa)
            .scaleEffect(0.62)
            .frame(width: TamanhoPost.largura * 0.62, height: TamanhoPost.altura * 0.62)
            .background { if modelo.transparente { Xadrez() } }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .padding(.top, 8)
            .accessibilityLabel(L("Prévia da imagem: ", "Image preview: ") + modelo.nome)
    }

    private var galeria: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(modelos) { m in
                    miniatura(m)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func miniatura(_ m: ModeloPost) -> some View {
        Button {
            modelo = m
        } label: {
            VStack(spacing: 6) {
                ArtePost(modelo: m, dados: dados, unidade: unidade, mapa: mapa)
                    .scaleEffect(0.2)
                    .frame(width: TamanhoPost.largura * 0.2, height: TamanhoPost.altura * 0.2)
                    .background { if m.transparente { Xadrez() } }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(m == modelo ? Paleta.verdeLogo : Color.primary.opacity(0.12), lineWidth: m == modelo ? 3 : 1))
                Text(m.nome).font(.caption.weight(m == modelo ? .semibold : .regular))
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(m == modelo ? .isSelected : [])
    }

    private var opcoes: some View {
        VStack(alignment: .leading, spacing: 10) {
            if temRota {
                Toggle(L("Mostrar a rota", "Show the route"), isOn: $mostrarRota)
                Toggle(L("Esconder começo e fim (200 m)", "Hide start and end (200 m)"), isOn: $aparar)
                    .disabled(!mostrarRota)
                Text(modelo == .mapa
                     ? L("O mapa mostra o bairro por onde você passou, mesmo com o começo e o fim escondidos.", "The map shows the area you ran through, even with the start and end hidden.")
                     : L("O começo e o fim costumam ser a porta de casa. A imagem não leva coordenadas.", "The start and end are usually your front door. The image carries no coordinates."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if modelo.transparente {
                Text(L("Fundo transparente: toque em Copiar e cole no story, por cima de uma foto.", "Transparent background: tap Copy and paste it into a story, over a photo."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .cartaoVidro(raio: 20)
    }

    private var acoes: some View {
        HStack(spacing: 12) {
            Button {
                copiar()
            } label: {
                Label(L("Copiar", "Copy"), systemImage: "doc.on.doc").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            Button {
                Task { await salvar() }
            } label: {
                Label(L("Salvar", "Save"), systemImage: "square.and.arrow.down").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            if let arquivo {
                ShareLink(item: arquivo, preview: SharePreview(dados.titulo, image: Image(systemName: "figure.run"))) {
                    Label(L("Enviar", "Send"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: Imagem

    private var chaveMapa: String { "\(aparar)-\(mostrarRota)-\(modelo == .mapa)" }
    private var chaveArquivo: String { "\(modelo.rawValue)-\(aparar)-\(mostrarRota)-\(mapa != nil)-\(unidade.rawValue)" }

    /// A arte em 1080 × 1920 (PNG com transparência nos adesivos).
    @MainActor
    private func renderizar() -> UIImage? {
        let renderer = ImageRenderer(content: ArtePost(modelo: modelo, dados: dados, unidade: unidade, mapa: mapa))
        renderer.scale = 3
        renderer.isOpaque = !modelo.transparente
        return renderer.uiImage
    }

    @MainActor
    private func gravarArquivo() -> URL? {
        guard let png = renderizar()?.pngData() else { return nil }
        let nome = "CRUNNING-" + corrida.inicio.formatted(.iso8601.year().month().day()) + "-" + modelo.rawValue + ".png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nome)
        do {
            try png.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func copiar() {
        guard let png = renderizar()?.pngData() else { return }
        UIPasteboard.general.setData(png, forPasteboardType: UTType.png.identifier)
        aviso = L("Copiada. No story do Instagram, toque e segure e escolha Colar.", "Copied. In an Instagram story, press and hold and choose Paste.")
    }

    private func salvar() async {
        guard let png = renderizar()?.pngData() else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            aviso = L("Sem permissão para salvar nas Fotos. Libere em Ajustes do iPhone > CRUNNING > Fotos.", "No permission to save to Photos. Allow it in iPhone Settings > CRUNNING > Photos.")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: png, options: nil)
            }
            aviso = L("Salva nas Fotos.", "Saved to Photos.")
        } catch {
            aviso = L("Não deu para salvar nas Fotos.", "Could not save to Photos.")
        }
    }

    /// Fundo do modelo Mapa: mapa escuro da Apple com a rota (já aparada) desenhada por cima.
    private func prepararMapa() async {
        guard modelo == .mapa, temRota, mostrarRota else { return }
        let pontos = rotaAparada.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        guard pontos.count >= 2 else { mapa = nil; return }
        mapa = await MapaPost.gerar(pontos)
    }
}

/// Fundo xadrez da prévia, para mostrar o que é transparente.
struct Xadrez: View {
    var body: some View {
        Canvas { contexto, tamanho in
            let lado: CGFloat = 10
            var y: CGFloat = 0, linha = 0
            while y < tamanho.height {
                var x: CGFloat = linha % 2 == 0 ? 0 : lado
                while x < tamanho.width {
                    contexto.fill(Path(CGRect(x: x, y: y, width: lado, height: lado)), with: .color(.gray.opacity(0.35)))
                    x += lado * 2
                }
                y += lado
                linha += 1
            }
        }
        .background(Color.gray.opacity(0.18))
    }
}

/// Foto do mapa com a rota, feita pelo MapKit no próprio iPhone.
enum MapaPost {
    static func gerar(_ pontos: [CLLocationCoordinate2D]) async -> UIImage? {
        let lats = pontos.map(\.latitude), lons = pontos.map(\.longitude)
        guard let la0 = lats.min(), let la1 = lats.max(), let lo0 = lons.min(), let lo1 = lons.max() else { return nil }
        let centro = CLLocationCoordinate2D(latitude: (la0 + la1) / 2, longitude: (lo0 + lo1) / 2)
        let regiao = MKCoordinateRegion(center: centro,
                                        span: MKCoordinateSpan(latitudeDelta: max(0.004, (la1 - la0) * 1.8),
                                                               longitudeDelta: max(0.004, (lo1 - lo0) * 1.4)))
        let opcoes = MKMapSnapshotter.Options()
        opcoes.region = regiao
        opcoes.size = CGSize(width: TamanhoPost.largura, height: TamanhoPost.altura)
        opcoes.scale = 3
        opcoes.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        opcoes.pointOfInterestFilter = .excludingAll
        opcoes.showsBuildings = false
        let snapshotter = MKMapSnapshotter(options: opcoes)
        return await withCheckedContinuation { continuacao in
            snapshotter.start(with: .main) { foto, _ in
                guard let foto else { continuacao.resume(returning: nil); return }
                let base = foto.image
                let tela = pontos.map { foto.point(for: $0) }
                let formato = UIGraphicsImageRendererFormat()
                formato.scale = base.scale
                let imagem = UIGraphicsImageRenderer(size: base.size, format: formato).image { ctx in
                    base.draw(at: .zero)
                    let caminho = UIBezierPath()
                    caminho.move(to: tela[0])
                    for p in tela.dropFirst() { caminho.addLine(to: p) }
                    caminho.lineWidth = 5
                    caminho.lineCapStyle = .round
                    caminho.lineJoinStyle = .round
                    UIColor(Paleta.verdeLogo).setStroke()
                    caminho.stroke()
                }
                continuacao.resume(returning: imagem)
            }
        }
    }
}
