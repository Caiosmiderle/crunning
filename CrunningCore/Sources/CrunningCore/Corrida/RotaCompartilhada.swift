import Foundation

/// A rota de uma corrida preparada para virar imagem de compartilhar. Por padrão o começo e o
/// fim saem do desenho (quase sempre são a porta de casa); as coordenadas viram uma forma
/// normalizada, sem latitude nem longitude, para a arte desenhar.
public enum RotaCompartilhada {
    /// Quanto do começo e do fim sai por padrão.
    public static let aparoPadrao: Double = 200

    /// Tira os primeiros e os últimos `metros` da rota. Com menos de 3 × `metros` de corrida
    /// sobraria pouco e o pedaço ainda entregaria o lugar: devolve vazio.
    public static func aparar(_ amostras: [AmostraTrilha], metros: Double = aparoPadrao) -> [AmostraTrilha] {
        guard metros > 0 else { return amostras }
        guard let primeira = amostras.first, let ultima = amostras.last, ultima.d - primeira.d >= metros * 3 else { return [] }
        let de = primeira.d + metros, ate = ultima.d - metros
        return amostras.filter { $0.d >= de && $0.d <= ate }
    }

    /// Um ponto da forma, de 0 a 1 nos dois eixos (y = 0 em cima, norte para cima).
    public struct Ponto: Sendable, Equatable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// A forma da rota: um traço por trecho (pausa manual quebra o traço), cabendo num quadrado
    /// de 0 a 1 sem distorcer (o lado menor fica centralizado). No máximo `maximoPontos` no total.
    public static func forma(_ amostras: [AmostraTrilha], maximoPontos: Int = 600) -> [[Ponto]] {
        guard amostras.count >= 2 else { return [] }
        let latMedia = amostras.map(\.lat).reduce(0, +) / Double(amostras.count)
        let k = cos(latMedia * .pi / 180)
        let xs = amostras.map { $0.lon * k }, ys = amostras.map(\.lat)
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return [] }
        let lado = max(x1 - x0, y1 - y0)
        guard lado > 0 else { return [] }
        let folgaX = (lado - (x1 - x0)) / 2, folgaY = (lado - (y1 - y0)) / 2
        let passo = max(1, Int((Double(amostras.count) / Double(max(2, maximoPontos))).rounded(.up)))
        var tracos: [[Ponto]] = []
        var atual: [Ponto] = []
        var trecho = amostras[0].seg
        for (i, a) in amostras.enumerated() {
            if a.seg != trecho {
                if atual.count >= 2 { tracos.append(atual) }
                atual = []
                trecho = a.seg
            }
            guard i % passo == 0 || i == amostras.count - 1 else { continue }
            atual.append(Ponto(x: (xs[i] - x0 + folgaX) / lado, y: 1 - (ys[i] - y0 + folgaY) / lado))
        }
        if atual.count >= 2 { tracos.append(atual) }
        return tracos
    }
}
