import Foundation

/// Gerador de números previsível (SplitMix64): mesma semente, mesma sequência.
public struct GeradorAleatorio: RandomNumberGenerator, Sendable {
    var estado: UInt64

    public init(semente: UInt64) {
        estado = semente
    }

    public mutating func next() -> UInt64 {
        estado &+= 0x9E37_79B9_7F4A_7C15
        var z = estado
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Número entre -1 e 1.
    mutating func ruido() -> Double {
        Double.random(in: -1...1, using: &self)
    }
}

/// Rota fictícia para testar sem sair de casa: uma volta oval num parque público
/// qualquer (nada a ver com o usuário), com aquecimento, uma parada de 20 s
/// (testa a pausa automática), 4 tiros com trote, desaquecimento, ruído de GPS
/// e dois pontos ruins de propósito (um impreciso e um salto) para o filtro descartar.
public enum RotaSimulada {
    /// (duração em segundos, velocidade em m/s)
    public static let perfil: [(TimeInterval, Double)] = {
        var fases: [(TimeInterval, Double)] = [(300, 2.78), (20, 0)]
        for _ in 0..<4 { fases += [(90, 3.9), (60, 2.4)] }
        fases.append((300, 2.6))
        return fases
    }()

    public static var duracaoTotal: TimeInterval { perfil.reduce(0) { $0 + $1.0 } }

    public static func gerar(
        inicio: Date,
        semente: UInt64 = 42,
        centroLat: Double = -23.5874,
        centroLon: Double = -46.6576
    ) -> [PontoGPS] {
        var aleatorio = GeradorAleatorio(semente: semente)
        let semiEixoLeste = 250.0
        let semiEixoNorte = 150.0
        var angulo = 0.0
        var ruidoLeste = 0.0
        var ruidoNorte = 0.0
        var pontos: [PontoGPS] = []
        var segundo = 0

        for (duracao, velocidade) in perfil {
            for _ in 0..<Int(duracao) {
                // Avança na elipse pelo comprimento de arco (velocidade x 1 s).
                let rapidez = sqrt(pow(semiEixoLeste * sin(angulo), 2) + pow(semiEixoNorte * cos(angulo), 2))
                angulo += velocidade / max(rapidez, 1)
                // Ruído de GPS correlacionado (anda devagar, como o erro real).
                ruidoLeste = 0.8 * ruidoLeste + 0.6 * aleatorio.ruido()
                ruidoNorte = 0.8 * ruidoNorte + 0.6 * aleatorio.ruido()
                let leste = semiEixoLeste * cos(angulo) + ruidoLeste
                let norte = semiEixoNorte * sin(angulo) + ruidoNorte
                var posicao = Geo.deslocar(lat: centroLat, lon: centroLon, leste: leste, norte: norte)
                var precisao = 6 + 3 * abs(aleatorio.ruido())

                if segundo == 150 { precisao = 65 }                  // impreciso: filtro descarta
                if segundo == 700 {                                    // salto de 400 m: filtro descarta
                    posicao = Geo.deslocar(lat: posicao.lat, lon: posicao.lon, leste: 400, norte: 0)
                }

                pontos.append(PontoGPS(
                    instante: inicio.addingTimeInterval(Double(segundo)),
                    latitude: posicao.lat,
                    longitude: posicao.lon,
                    altitude: 760 + 6 * sin(angulo) + 0.4 * aleatorio.ruido(),
                    precisaoHorizontal: precisao,
                    precisaoVertical: 6,
                    velocidade: max(0, velocidade + 0.15 * aleatorio.ruido())
                ))
                segundo += 1
            }
        }
        return pontos
    }
}
