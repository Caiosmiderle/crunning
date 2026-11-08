import Foundation

/// Uma parcial (km ou milha) calculada a partir da trilha.
public struct Parcial: Sendable, Equatable, Identifiable {
    public var numero: Int
    /// Metros desta parcial (a última pode ser incompleta).
    public var distancia: Double
    /// Tempo em movimento da parcial.
    public var duracao: TimeInterval
    public var completa: Bool

    public var id: Int { numero }
    /// Segundos por km.
    public var ritmo: Double { distancia > 0 ? duracao / distancia * 1000 : 0 }

    public init(numero: Int, distancia: Double, duracao: TimeInterval, completa: Bool) {
        self.numero = numero
        self.distancia = distancia
        self.duracao = duracao
        self.completa = completa
    }
}

public enum Parciais {
    /// Parciais a cada `comprimento` metros (1000 = km, 1609,344 = milha), com o
    /// tempo de cada fronteira interpolado entre as amostras vizinhas.
    public static func calcular(_ amostras: [AmostraTrilha], comprimento: Double = 1000) -> [Parcial] {
        guard comprimento > 0, let ultima = amostras.last, ultima.d > 0 else { return [] }
        var resultado: [Parcial] = []
        var movNaFronteiraAnterior: TimeInterval = 0
        var proxima = comprimento
        var numero = 1
        for (anterior, atual) in zip(amostras, amostras.dropFirst()) {
            while atual.d >= proxima, atual.d > anterior.d {
                let fracao = (proxima - anterior.d) / (atual.d - anterior.d)
                let mov = anterior.mov + fracao * (atual.mov - anterior.mov)
                resultado.append(Parcial(numero: numero, distancia: comprimento, duracao: mov - movNaFronteiraAnterior, completa: true))
                movNaFronteiraAnterior = mov
                numero += 1
                proxima += comprimento
            }
        }
        let resto = ultima.d - (proxima - comprimento)
        if resto >= 10 {
            resultado.append(Parcial(numero: numero, distancia: resto, duracao: ultima.mov - movNaFronteiraAnterior, completa: false))
        }
        return resultado
    }
}

/// Ponto de uma série para gráfico: distância (m) no eixo x.
public struct PontoSerie: Sendable, Equatable, Identifiable {
    public var distancia: Double
    public var valor: Double
    public var id: Double { distancia }

    public init(distancia: Double, valor: Double) {
        self.distancia = distancia
        self.valor = valor
    }
}

public enum Series {
    /// Ritmo (s/km) em janelas móveis de `janela` metros, um ponto a cada `passo` metros.
    public static func ritmo(_ amostras: [AmostraTrilha], passo: Double = 100, janela: Double = 200) -> [PontoSerie] {
        guard let total = amostras.last?.d, total >= janela, passo > 0 else { return [] }
        var serie: [PontoSerie] = []
        var x = janela
        while x <= total {
            if let m2 = interpolar(amostras, distancia: x)?.mov,
               let m1 = interpolar(amostras, distancia: x - janela)?.mov, m2 > m1 {
                serie.append(PontoSerie(distancia: x, valor: (m2 - m1) / janela * 1000))
            }
            x += passo
        }
        return serie
    }

    /// Altitude (m) a cada `passo` metros. Vazia se o GPS não informou altitude.
    public static func altitude(_ amostras: [AmostraTrilha], passo: Double = 50) -> [PontoSerie] {
        guard let total = amostras.last?.d, total > 0, passo > 0,
              amostras.contains(where: { $0.alt != nil }) else { return [] }
        var serie: [PontoSerie] = []
        var x = 0.0
        while x <= total {
            if let alt = interpolar(amostras, distancia: x)?.alt {
                serie.append(PontoSerie(distancia: x, valor: alt))
            }
            x += passo
        }
        return serie
    }

    /// Tempo em movimento e altitude na distância pedida (busca binária + interpolação linear).
    public static func interpolar(_ amostras: [AmostraTrilha], distancia: Double) -> (mov: TimeInterval, alt: Double?)? {
        guard let primeira = amostras.first, let ultima = amostras.last else { return nil }
        if distancia <= primeira.d { return (primeira.mov, primeira.alt) }
        if distancia >= ultima.d { return (ultima.mov, ultima.alt) }
        var baixo = 0
        var alto = amostras.count - 1
        while alto - baixo > 1 {
            let meio = (baixo + alto) / 2
            if amostras[meio].d < distancia { baixo = meio } else { alto = meio }
        }
        let a = amostras[baixo]
        let b = amostras[alto]
        guard b.d > a.d else { return (b.mov, b.alt) }
        let f = (distancia - a.d) / (b.d - a.d)
        let alt: Double? = if let altA = a.alt, let altB = b.alt { altA + f * (altB - altA) } else { a.alt ?? b.alt }
        return (a.mov + f * (b.mov - a.mov), alt)
    }
}

public struct Coordenada: Sendable, Equatable {
    public var lat: Double
    public var lon: Double
}

/// Pedaço da rota para desenhar no mapa com a cor do ritmo daquele trecho.
public struct TrechoMapa: Sendable, Identifiable {
    public var id: Int
    public var coordenadas: [Coordenada]
    /// s/km do pedaço (nil se curto demais para medir).
    public var ritmo: Double?
}

public enum Trechos {
    /// Divide a trilha em cerca de `quantidade` pedaços (respeitando as pausas manuais),
    /// cada um com seu ritmo. Pedaços vizinhos compartilham o ponto de junção.
    public static func dividir(_ amostras: [AmostraTrilha], quantidade: Int = 150) -> [TrechoMapa] {
        guard amostras.count >= 2 else { return [] }
        let tamanho = max(2, amostras.count / max(1, quantidade))
        var trechos: [TrechoMapa] = []
        var inicio = 0
        while inicio < amostras.count - 1 {
            var fim = min(inicio + tamanho, amostras.count - 1)
            // Não liga pontos de trechos diferentes (antes e depois de uma pausa manual).
            if let quebra = (inicio + 1...fim).first(where: { amostras[$0].seg != amostras[inicio].seg }) {
                fim = quebra - 1
            }
            if fim > inicio {
                let pedaco = amostras[inicio...fim]
                let dd = amostras[fim].d - amostras[inicio].d
                let dm = amostras[fim].mov - amostras[inicio].mov
                trechos.append(TrechoMapa(
                    id: trechos.count,
                    coordenadas: pedaco.map { Coordenada(lat: $0.lat, lon: $0.lon) },
                    ritmo: dd >= 5 && dm > 0 ? dm / dd * 1000 : nil
                ))
                inicio = fim
            } else {
                inicio = fim + 1
            }
        }
        return trechos
    }
}
