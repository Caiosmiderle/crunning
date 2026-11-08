import CrunningCore
import Foundation
import SwiftData

/// Uma corrida gravada. Todo campo tem valor padrão para o SwiftData migrar
/// sozinho quando surgirem campos novos (a fase 3 acrescentou trilha, subida,
/// esforço e simulada sem perder as corridas antigas).
@Model
final class Corrida {
    var inicio: Date = Date.now
    var duracaoTotal: TimeInterval = 0
    var duracaoEmMovimento: TimeInterval = 0
    var distanciaMetros: Double = 0
    var titulo: String = "Corrida livre"
    /// Gerada pelo modo de desenvolvimento, com dados fictícios.
    var exemplo: Bool = false
    /// Pontos da rota ([AmostraTrilha] em JSON), guardados fora do banco por serem grandes.
    @Attribute(.externalStorage) var trilha: Data? = nil
    var subidaMetros: Double = 0
    /// Esforço percebido de 1 a 10 (escala CR10), respondido no fim.
    var esforcoPercebido: Int? = nil
    /// Gravada com o GPS simulado.
    var simulada: Bool = false

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

    /// Decodifica a rota (custa alguns milissegundos: chamar uma vez por tela).
    func carregarAmostras() -> [AmostraTrilha] {
        guard let trilha else { return [] }
        return (try? JSONDecoder().decode([AmostraTrilha].self, from: trilha)) ?? []
    }

    /// Monta a corrida a partir da gravação terminada.
    static func de(sessao: SessaoCorrida, simulada: Bool, esforco: Int?, agora: Date) -> Corrida {
        let fim = sessao.fim ?? agora
        let corrida = Corrida(
            inicio: sessao.inicio ?? fim,
            duracaoTotal: sessao.tempoTotal(em: fim),
            duracaoEmMovimento: sessao.tempoEmMovimento(em: fim),
            distanciaMetros: sessao.distancia,
            titulo: simulada ? "Corrida simulada" : "Corrida livre"
        )
        corrida.subidaMetros = sessao.subida
        corrida.esforcoPercebido = esforco
        corrida.simulada = simulada
        corrida.trilha = try? JSONEncoder().encode(sessao.amostras)
        return corrida
    }

    /// Corrida fictícia completa (com rota, parciais e altitude), gravada pelo
    /// próprio motor sobre a rota simulada, para testar as telas sem sair de casa.
    static func deExemplo(agora: Date = .now) -> Corrida {
        let diasAtras = Double(Int.random(in: 0...6))
        let inicio = agora.addingTimeInterval(-diasAtras * 86_400 - RotaSimulada.duracaoTotal - 600)
        let pontos = RotaSimulada.gerar(inicio: inicio, semente: UInt64.random(in: 1...UInt64.max))
        var sessao = SessaoCorrida()
        sessao.iniciar(em: inicio)
        for ponto in pontos { sessao.receber(ponto) }
        sessao.finalizar(em: pontos.last?.instante ?? inicio)
        let corrida = Corrida.de(sessao: sessao, simulada: true, esforco: Int.random(in: 4...8), agora: agora)
        corrida.titulo = "Corrida de exemplo"
        corrida.exemplo = true
        return corrida
    }
}
