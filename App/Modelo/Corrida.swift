import Foundation
import SwiftData

/// Uma corrida gravada. Na fase 3 ganha pontos de GPS, parciais e blocos.
/// Todo campo tem valor padrão para o SwiftData migrar sozinho quando surgirem campos novos.
@Model
final class Corrida {
    var inicio: Date = Date.now
    var duracaoTotal: TimeInterval = 0
    var duracaoEmMovimento: TimeInterval = 0
    var distanciaMetros: Double = 0
    var titulo: String = "Corrida livre"
    /// Gerada pelo modo de desenvolvimento, com dados fictícios.
    var exemplo: Bool = false

    init(
        inicio: Date,
        duracaoTotal: TimeInterval,
        duracaoEmMovimento: TimeInterval,
        distanciaMetros: Double,
        titulo: String = "Corrida livre",
        exemplo: Bool = false
    ) {
        self.inicio = inicio
        self.duracaoTotal = duracaoTotal
        self.duracaoEmMovimento = duracaoEmMovimento
        self.distanciaMetros = distanciaMetros
        self.titulo = titulo
        self.exemplo = exemplo
    }

    /// Segundos por quilômetro, sobre o tempo em movimento.
    var ritmoMedioSegundosPorKm: Double {
        guard distanciaMetros > 0 else { return 0 }
        return duracaoEmMovimento / (distanciaMetros / 1000)
    }

    /// Corrida fictícia para testar telas e persistência sem sair de casa.
    static func deExemplo(agora: Date = .now) -> Corrida {
        let distancia = Double.random(in: 3000...12000)
        let ritmo = Double.random(in: 285...390)
        let movimento = distancia / 1000 * ritmo
        let diasAtras = Double(Int.random(in: 0...6))
        return Corrida(
            inicio: agora.addingTimeInterval(-diasAtras * 86_400 - movimento),
            duracaoTotal: movimento + Double.random(in: 0...120),
            duracaoEmMovimento: movimento,
            distanciaMetros: distancia,
            titulo: "Corrida de exemplo",
            exemplo: true
        )
    }
}
