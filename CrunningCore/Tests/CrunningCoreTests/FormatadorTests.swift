import Testing
@testable import CrunningCore

@Suite("Formatação de distância, ritmo e duração")
struct FormatadorTests {
    @Test func distanciaEmQuilometros() {
        #expect(Formatador.distancia(5234) == "5,23 km")
        #expect(Formatador.distancia(10_000, casas: 1) == "10,0 km")
    }

    @Test func distanciaEmMilhas() {
        #expect(Formatador.distancia(1609.344, unidade: .milhas) == "1,00 mi")
    }

    @Test func distanciaInvalidaViraZero() {
        #expect(Formatador.distancia(-50) == "0,00 km")
        #expect(Formatador.distancia(.nan) == "0,00 km")
        #expect(Formatador.distancia(.infinity) == "0,00 km")
    }

    @Test(arguments: zip([300.0, 307.4, 299.5, 59.6, 3599.4], ["5:00", "5:07", "5:00", "1:00", "59:59"]))
    func ritmoPorQuilometro(segundos: Double, esperado: String) {
        #expect(Formatador.ritmo(segundosPorKm: segundos) == esperado)
    }

    @Test func ritmoEmMilhas() {
        // 5:00/km = 482,8 s/mi -> 8:03/mi
        #expect(Formatador.ritmo(segundosPorKm: 300, unidade: .milhas) == "8:03")
    }

    @Test(arguments: [0.0, -10, .infinity, .nan, 3600])
    func ritmoImpossivel(segundos: Double) {
        #expect(Formatador.ritmo(segundosPorKm: segundos) == "--:--")
    }

    @Test(arguments: zip([0.0, 45, 59.9, 300, 3599, 3600, 3725, 36_000], ["0:00", "0:45", "0:59", "5:00", "59:59", "1:00:00", "1:02:05", "10:00:00"]))
    func duracao(segundos: Double, esperado: String) {
        #expect(Formatador.duracao(segundos) == esperado)
    }

    @Test func duracaoNegativaViraZero() {
        #expect(Formatador.duracao(-5) == "0:00")
    }
}

@Suite("Tipos de treino")
struct TipoTreinoTests {
    @Test func qualidadeSoNosFortes() {
        let fortes = TipoTreino.allCases.filter(\.ehQualidade)
        #expect(Set(fortes) == [.limiar, .intervalado, .repeticoes])
    }

    @Test func todosTemNome() {
        for tipo in TipoTreino.allCases {
            #expect(!tipo.nome.isEmpty)
        }
    }
}
