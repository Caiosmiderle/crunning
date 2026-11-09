import Foundation

/// Treino pronto para usar no construtor ou executar direto, com os ritmos das zonas do usuário.
public struct ModeloPronto: Sendable, Identifiable {
    public let id: String
    public let nome: String
    public let porque: String
    public let treino: Treino
}

extension Modelos {
    static let prefixoTeste = "teste-"

    /// Teste de referência: aquecimento completo, a distância o mais rápido que der num ritmo
    /// constante, e desaquecimento. O tempo vira a prova de referência (VDOT) em Meus ritmos.
    public static func teste(_ distancia: Double) -> Treino {
        Treino(
            nome: L("Teste de \(Int((distancia / 1000).rounded())) km", "\(Int((distancia / 1000).rounded())) km test"), tipo: .prova,
            blocos: [aquecimento(), .passo(Passo(.trabalho, .distancia(distancia), .prova)), desaquecimento()],
            modeloID: prefixoTeste + "\(Int(distancia))"
        )
    }

    public static let porqueTeste = L("Um teste forte e cronometrado, como uma prova. O tempo do trecho forte vira a sua prova de referência e atualiza todos os ritmos. Faça descansado, num percurso plano.",
                                      "A hard, timed test, like a race. The time of the hard section becomes your reference race and updates all your paces. Do it rested, on a flat course.")
}

public enum ModelosProntos {
    static func renomear(_ treino: Treino, _ nome: String) -> Treino {
        var t = treino
        t.nome = nome
        return t
    }

    public static let todos: [ModeloPronto] = [
        ModeloPronto(
            id: "6x400", nome: "6 × 400 m", porque: Modelos.intervalado400.porque,
            treino: renomear(Modelos.intervalado400.treino(dose: 2400), "6 × 400 m")
        ),
        ModeloPronto(
            id: "5x1000", nome: L("5 × 1.000 m", "5 × 1,000 m"), porque: Modelos.intervalado1000.porque,
            treino: renomear(Modelos.intervalado1000.treino(dose: 5000), L("5 × 1.000 m", "5 × 1,000 m"))
        ),
        ModeloPronto(
            id: "fartlek", nome: "Fartlek", porque: Modelos.fartlek.porque,
            treino: Modelos.fartlek.treino(dose: 12)
        ),
        ModeloPronto(
            id: "limiar-20", nome: L("Limiar 20 min", "Threshold 20 min"), porque: Modelos.limiarContinuo.porque,
            treino: Treino(
                nome: L("Limiar 20 min", "Threshold 20 min"), tipo: .limiar,
                blocos: [
                    .passo(Passo(.aquecimento, .tempo(600), .facil)),
                    .passo(Passo(.trabalho, .tempo(1200), .limiar)),
                    .passo(Passo(.desaquecimento, .tempo(600), .facil)),
                ],
                modeloID: "limiar-20"
            )
        ),
        ModeloPronto(
            id: "cruise", nome: L("3 × 1.600 m no limiar", "3 × 1,600 m at threshold"), porque: Modelos.cruise.porque,
            treino: renomear(Modelos.cruise.treino(dose: 4800), L("3 × 1.600 m no limiar", "3 × 1,600 m at threshold"))
        ),
        ModeloPronto(
            id: "progressivo", nome: L("Progressivo", "Progression run"), porque: Modelos.progressivo.porque,
            treino: Modelos.progressivo.treino(dose: 9000)
        ),
        ModeloPronto(
            id: "subidas", nome: L("Subidas", "Hill repeats"), porque: Modelos.subidas.porque,
            treino: Modelos.subidas.treino(dose: 8)
        ),
        ModeloPronto(
            id: "aceleracoes", nome: L("Fácil com acelerações", "Easy with strides"), porque: Modelos.aceleracoes.porque,
            treino: Modelos.aceleracoes.treino(dose: 6000)
        ),
        ModeloPronto(id: "teste-3000", nome: L("Teste de 3 km", "3 km test"), porque: Modelos.porqueTeste, treino: Modelos.teste(3000)),
        ModeloPronto(id: "teste-5000", nome: L("Teste de 5 km", "5 km test"), porque: Modelos.porqueTeste, treino: Modelos.teste(5000)),
    ]
}
