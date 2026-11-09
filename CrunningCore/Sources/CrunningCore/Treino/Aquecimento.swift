import Foundation

/// Um exercício do aquecimento, com a explicação de como fazer (texto próprio do app).
public struct ExercicioAquecimento: Codable, Sendable, Equatable, Identifiable {
    public enum Medida: Codable, Sendable, Equatable {
        case tempo(TimeInterval)
        case repeticoes(Int, porLado: Bool)
        case distancia(Double, vezes: Int)
    }

    public let id: String
    public let nome: String
    public let medida: Medida
    public let comoFazer: String

    /// Tempo aproximado do exercício (para a rotina e para a execução guiada).
    public var duracaoEstimada: TimeInterval {
        switch medida {
        case let .tempo(t): t
        case let .repeticoes(n, porLado): Double(n * (porLado ? 2 : 1)) * 2.5
        case let .distancia(_, vezes): Double(vezes) * 40   // ida fazendo, volta andando
        }
    }
}

/// Rotina de aquecimento antes de treinos fortes e provas (docs/CIENCIA.md, "Aquecimento").
public struct RotinaAquecimento: Sendable, Equatable {
    public struct Etapa: Sendable, Equatable {
        public let titulo: String
        public let exercicios: [ExercicioAquecimento]
    }

    public let nome: String
    public let etapas: [Etapa]
    public let porque: String
    public let fontes: [String]

    public var duracaoEstimada: TimeInterval {
        etapas.flatMap(\.exercicios).reduce(0) { $0 + $1.duracaoEstimada }
    }
}

public enum Aquecimento {
    // MARK: Exercícios

    static let trote = ExercicioAquecimento(
        id: "trote", nome: "Trote leve", medida: .tempo(600),
        comoFazer: "Corra bem devagar, num ritmo em que dá para conversar à vontade. É o começo do treino."
    )
    static let balancoFrente = ExercicioAquecimento(
        id: "balanco-frente", nome: "Balanço de perna para frente e para trás", medida: .repeticoes(10, porLado: true),
        comoFazer: "Apoie a mão numa parede ou poste e balance a perna solta para frente e para trás, aumentando a amplitude aos poucos."
    )
    static let balancoLado = ExercicioAquecimento(
        id: "balanco-lado", nome: "Balanço de perna para os lados", medida: .repeticoes(10, porLado: true),
        comoFazer: "De frente para o apoio, balance a perna cruzando na frente do corpo e abrindo para fora."
    )
    static let afundo = ExercicioAquecimento(
        id: "afundo", nome: "Afundo andando", medida: .repeticoes(6, porLado: true),
        comoFazer: "Dê um passo longo, desça até o joelho de trás quase tocar o chão, suba e avance com a outra perna. Tronco reto."
    )
    static let quadril = ExercicioAquecimento(
        id: "quadril", nome: "Círculos de quadril", medida: .repeticoes(8, porLado: true),
        comoFazer: "Mãos na cintura, desenhe círculos grandes com o quadril, para um lado e depois para o outro."
    )
    static let panturrilha = ExercicioAquecimento(
        id: "panturrilha", nome: "Subida na ponta dos pés", medida: .repeticoes(12, porLado: false),
        comoFazer: "Suba na ponta dos dois pés e desça devagar, sem pressa e sem dor."
    )
    static let skippingBaixo = ExercicioAquecimento(
        id: "skipping-baixo", nome: "Skipping baixo", medida: .distancia(20, vezes: 2),
        comoFazer: "Passos curtos e rápidos no lugar enquanto avança devagar, apoiando a frente do pé. Volte andando."
    )
    static let skippingAlto = ExercicioAquecimento(
        id: "skipping-alto", nome: "Skipping alto", medida: .distancia(20, vezes: 2),
        comoFazer: "Eleve os joelhos até perto da altura do quadril, braços ativos, avançando devagar. Volte andando."
    )
    static let calcanhar = ExercicioAquecimento(
        id: "calcanhar", nome: "Calcanhar no glúteo", medida: .distancia(20, vezes: 2),
        comoFazer: "Corra devagar levando o calcanhar em direção ao glúteo a cada passo. Volte andando."
    )
    static let aceleracoes = ExercicioAquecimento(
        id: "aceleracoes", nome: "Acelerações progressivas", medida: .tempo(3 * 60),
        comoFazer: "3 vezes 20 segundos, começando leve e chegando perto do ritmo do treino no fim, com 40 segundos andando entre elas."
    )

    // MARK: Rotinas

    static let porque = "Aquecer melhora o desempenho na maior parte das medidas estudadas. Antes de correr, use movimentos dinâmicos: alongamento estático longo logo antes do treino pode atrapalhar. Em corredores, aquecer não mostrou reduzir lesões; o objetivo aqui é correr melhor o treino forte."
    static let fontes = ["Fradkin, Zazryn e Smoliga 2010", "Behm e colegas 2016", "van Mechelen e colegas 1993"]

    /// Completa (cerca de 20 minutos): antes de intervalado, repetições, subidas e prova.
    public static let completa = RotinaAquecimento(
        nome: "Aquecimento completo",
        etapas: [
            .init(titulo: "Trote", exercicios: [trote]),
            .init(titulo: "Mobilidade dinâmica", exercicios: [balancoFrente, balancoLado, afundo, quadril, panturrilha]),
            .init(titulo: "Educativos", exercicios: [skippingBaixo, skippingAlto, calcanhar]),
            .init(titulo: "Acelerações", exercicios: [aceleracoes]),
        ],
        porque: porque, fontes: fontes
    )

    /// Curta (cerca de 14 minutos): antes de limiar, ritmo de prova e fartlek.
    public static let curta = RotinaAquecimento(
        nome: "Aquecimento curto",
        etapas: [
            .init(titulo: "Trote", exercicios: [trote]),
            .init(titulo: "Mobilidade dinâmica", exercicios: [balancoFrente, balancoLado, afundo]),
            .init(titulo: "Acelerações", exercicios: [aceleracoes]),
        ],
        porque: porque, fontes: fontes
    )

    /// Rotina indicada para o tipo de treino; nos treinos leves, o trote do começo já basta.
    public static func rotina(para tipo: TipoTreino) -> RotinaAquecimento? {
        switch tipo {
        case .intervalado, .repeticoes, .prova: completa
        case .limiar, .ritmoProva: curta
        case .caminhada, .recuperacao, .facil, .longao: nil
        }
    }
}
