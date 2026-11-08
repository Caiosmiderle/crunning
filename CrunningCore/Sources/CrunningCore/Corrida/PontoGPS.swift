import Foundation

/// Um ponto de localização, já sem nada de CoreLocation (o app converte CLLocation para isto).
public struct PontoGPS: Codable, Sendable, Equatable {
    public var instante: Date
    public var latitude: Double
    public var longitude: Double
    /// Altitude em metros (nil quando o GPS não informa).
    public var altitude: Double?
    /// Raio de incerteza horizontal em metros. Negativo = ponto inválido.
    public var precisaoHorizontal: Double
    public var precisaoVertical: Double?
    /// Velocidade informada pelo GPS em m/s (nil quando inválida).
    public var velocidade: Double?

    public init(
        instante: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        precisaoHorizontal: Double = 5,
        precisaoVertical: Double? = nil,
        velocidade: Double? = nil
    ) {
        self.instante = instante
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.precisaoHorizontal = precisaoHorizontal
        self.precisaoVertical = precisaoVertical
        self.velocidade = velocidade
    }
}

public enum Geo {
    /// Raio médio da Terra (IUGG), em metros.
    public static let raioMedioTerra = 6_371_008.8
    /// Metros por grau de latitude no raio médio.
    public static let metrosPorGrau = raioMedioTerra * .pi / 180

    /// Distância entre dois pontos pela fórmula de haversine, em metros.
    public static func distancia(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = Double.pi / 180
        let dLat = (lat2 - lat1) * r
        let dLon = (lon2 - lon1) * r
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * r) * cos(lat2 * r) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * raioMedioTerra * asin(min(1, sqrt(a)))
    }

    public static func distancia(_ a: PontoGPS, _ b: PontoGPS) -> Double {
        distancia(lat1: a.latitude, lon1: a.longitude, lat2: b.latitude, lon2: b.longitude)
    }

    /// Desloca um ponto alguns metros para leste e norte (aproximação plana, boa para poucos km).
    public static func deslocar(lat: Double, lon: Double, leste: Double, norte: Double) -> (lat: Double, lon: Double) {
        let novaLat = lat + norte / metrosPorGrau
        let novaLon = lon + leste / (metrosPorGrau * cos(lat * .pi / 180))
        return (novaLat, novaLon)
    }
}

/// Descarta pontos ruins antes de entrarem na corrida.
public struct FiltroGPS: Codable, Sendable {
    /// Acima deste raio de incerteza (m), o ponto é descartado.
    public var precisaoMaxima: Double = 25
    /// Velocidade impossível para quem corre (m/s). 12 m/s = 1:23/km.
    public var velocidadeMaxima: Double = 12
    public private(set) var ultimoAceito: PontoGPS?

    public enum Resultado: Equatable, Sendable {
        case aceito
        case rejeitadoPrecisao
        case rejeitadoTempo
        case rejeitadoSalto
    }

    public init(precisaoMaxima: Double = 25, velocidadeMaxima: Double = 12) {
        self.precisaoMaxima = precisaoMaxima
        self.velocidadeMaxima = velocidadeMaxima
    }

    public mutating func avaliar(_ ponto: PontoGPS) -> Resultado {
        guard ponto.precisaoHorizontal >= 0, ponto.precisaoHorizontal <= precisaoMaxima else {
            return .rejeitadoPrecisao
        }
        if let ultimo = ultimoAceito {
            let dt = ponto.instante.timeIntervalSince(ultimo.instante)
            guard dt > 0 else { return .rejeitadoTempo }
            // Desconta as duas incertezas antes de julgar o salto.
            let deslocamento = Geo.distancia(ultimo, ponto) - ultimo.precisaoHorizontal - ponto.precisaoHorizontal
            if deslocamento / dt > velocidadeMaxima { return .rejeitadoSalto }
        }
        ultimoAceito = ponto
        return .aceito
    }
}
