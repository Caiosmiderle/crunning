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
        id: "trote", nome: L("Trote leve", "Easy jog"), medida: .tempo(600),
        comoFazer: L("Corra bem devagar, num ritmo em que dá para conversar à vontade. É o começo do treino.",
                     "Run very slowly, at a pace where you can chat comfortably. It is the start of the workout.")
    )
    static let balancoFrente = ExercicioAquecimento(
        id: "balanco-frente", nome: L("Balanço de perna para frente e para trás", "Forward and back leg swings"), medida: .repeticoes(10, porLado: true),
        comoFazer: L("Apoie a mão numa parede ou poste e balance a perna solta para frente e para trás, aumentando a amplitude aos poucos.",
                     "Rest a hand on a wall or post and swing the relaxed leg forward and back, gradually increasing the range.")
    )
    static let balancoLado = ExercicioAquecimento(
        id: "balanco-lado", nome: L("Balanço de perna para os lados", "Side-to-side leg swings"), medida: .repeticoes(10, porLado: true),
        comoFazer: L("De frente para o apoio, balance a perna cruzando na frente do corpo e abrindo para fora.",
                     "Facing the support, swing the leg across the front of your body and then out to the side.")
    )
    static let afundo = ExercicioAquecimento(
        id: "afundo", nome: L("Afundo andando", "Walking lunges"), medida: .repeticoes(6, porLado: true),
        comoFazer: L("Dê um passo longo, desça até o joelho de trás quase tocar o chão, suba e avance com a outra perna. Tronco reto.",
                     "Take a long step, lower until the back knee almost touches the ground, rise and step forward with the other leg. Keep your torso upright.")
    )
    static let quadril = ExercicioAquecimento(
        id: "quadril", nome: L("Círculos de quadril", "Hip circles"), medida: .repeticoes(8, porLado: true),
        comoFazer: L("Mãos na cintura, desenhe círculos grandes com o quadril, para um lado e depois para o outro.",
                     "Hands on your waist, draw big circles with your hips, one way and then the other.")
    )
    static let panturrilha = ExercicioAquecimento(
        id: "panturrilha", nome: L("Subida na ponta dos pés", "Calf raises"), medida: .repeticoes(12, porLado: false),
        comoFazer: L("Suba na ponta dos dois pés e desça devagar, sem pressa e sem dor.",
                     "Rise onto the balls of both feet and lower slowly, without rushing and without pain.")
    )
    static let skippingBaixo = ExercicioAquecimento(
        id: "skipping-baixo", nome: L("Skipping baixo", "Low skips"), medida: .distancia(20, vezes: 2),
        comoFazer: L("Passos curtos e rápidos no lugar enquanto avança devagar, apoiando a frente do pé. Volte andando.",
                     "Short, quick steps almost in place while moving forward slowly, landing on the front of the foot. Walk back.")
    )
    static let skippingAlto = ExercicioAquecimento(
        id: "skipping-alto", nome: L("Skipping alto", "High knees"), medida: .distancia(20, vezes: 2),
        comoFazer: L("Eleve os joelhos até perto da altura do quadril, braços ativos, avançando devagar. Volte andando.",
                     "Lift your knees to about hip height, arms active, moving forward slowly. Walk back.")
    )
    static let calcanhar = ExercicioAquecimento(
        id: "calcanhar", nome: L("Calcanhar no glúteo", "Butt kicks"), medida: .distancia(20, vezes: 2),
        comoFazer: L("Corra devagar levando o calcanhar em direção ao glúteo a cada passo. Volte andando.",
                     "Run slowly, bringing your heel toward your glutes with each step. Walk back.")
    )
    static let aceleracoes = ExercicioAquecimento(
        id: "aceleracoes", nome: L("Acelerações progressivas", "Progressive strides"), medida: .tempo(3 * 60),
        comoFazer: L("3 vezes 20 segundos, começando leve e chegando perto do ritmo do treino no fim, com 40 segundos andando entre elas.",
                     "3 times 20 seconds, starting easy and getting close to workout pace by the end, with 40 seconds of walking between them.")
    )

    // MARK: Rotinas

    static let porque = L("Aquecer melhora o desempenho na maior parte das medidas estudadas. Antes de correr, use movimentos dinâmicos: alongamento estático longo logo antes do treino pode atrapalhar. Em corredores, aquecer não mostrou reduzir lesões; o objetivo aqui é correr melhor o treino forte.",
                          "Warming up improves performance in most of the measures studied. Before running, use dynamic movements: long static stretching right before the workout can get in the way. In runners, warming up has not been shown to reduce injuries; the goal here is to run the hard workout better.")
    static let fontes = [
        L("Fradkin, Zazryn e Smoliga 2010", "Fradkin, Zazryn and Smoliga 2010"),
        L("Behm e colegas 2016", "Behm et al. 2016"),
        L("van Mechelen e colegas 1993", "van Mechelen et al. 1993"),
    ]

    /// Completa (cerca de 20 minutos): antes de intervalado, repetições, subidas e prova.
    public static let completa = RotinaAquecimento(
        nome: L("Aquecimento completo", "Full warm-up"),
        etapas: [
            .init(titulo: L("Trote", "Jog"), exercicios: [trote]),
            .init(titulo: L("Mobilidade dinâmica", "Dynamic mobility"), exercicios: [balancoFrente, balancoLado, afundo, quadril, panturrilha]),
            .init(titulo: L("Educativos", "Running drills"), exercicios: [skippingBaixo, skippingAlto, calcanhar]),
            .init(titulo: L("Acelerações", "Strides"), exercicios: [aceleracoes]),
        ],
        porque: porque, fontes: fontes
    )

    /// Curta (cerca de 14 minutos): antes de limiar, ritmo de prova e fartlek.
    public static let curta = RotinaAquecimento(
        nome: L("Aquecimento curto", "Short warm-up"),
        etapas: [
            .init(titulo: L("Trote", "Jog"), exercicios: [trote]),
            .init(titulo: L("Mobilidade dinâmica", "Dynamic mobility"), exercicios: [balancoFrente, balancoLado, afundo]),
            .init(titulo: L("Acelerações", "Strides"), exercicios: [aceleracoes]),
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
