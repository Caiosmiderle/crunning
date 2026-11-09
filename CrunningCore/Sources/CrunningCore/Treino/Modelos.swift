import Foundation

/// O que a dose de um modelo significa.
public enum TipoDose: String, Codable, Sendable {
    /// Metros do treino inteiro.
    case distanciaTotal
    /// Metros só da parte de trabalho (sem aquecimento, pausas e desaquecimento).
    case distanciaDeTrabalho
    /// Minutos de trabalho.
    case minutosDeTrabalho
    /// Número de repetições.
    case ciclos
}

/// Modelo parametrizado de treino. O `porque` é escrito a partir das fontes de
/// docs/CIENCIA.md ("Por que cada modelo de treino existe"), nunca gerado na hora.
public struct ModeloTreino: Sendable, Identifiable {
    public let id: String
    public let nome: String
    public let tipo: TipoTreino
    public let tipoDose: TipoDose
    public let intensidadePrincipal: Intensidade
    public let porque: String
    public let fontes: [String]
    let montar: @Sendable (Double) -> [Bloco]

    public func treino(dose: Double) -> Treino {
        Treino(nome: nome, tipo: tipo, blocos: montar(dose), modeloID: id, dose: dose)
    }
}

public enum Modelos {
    // MARK: Peças

    static func metros(_ d: Double) -> Double { max(100, (d / 100).rounded() * 100) }
    static func aquecimento(_ d: Double = 2000) -> Bloco { .passo(Passo(.aquecimento, .distancia(d), .facil)) }
    static func desaquecimento(_ d: Double = 1500) -> Bloco { .passo(Passo(.desaquecimento, .distancia(d), .facil)) }
    static func reps(_ dose: Double, de tamanho: Double, minimo: Int) -> Int {
        max(minimo, Int((dose / tamanho).rounded()))
    }

    // MARK: Corridas contínuas

    public static let facil = ModeloTreino(
        id: "facil", nome: L("Corrida fácil", "Easy run"), tipo: .facil, tipoDose: .distanciaTotal, intensidadePrincipal: .facil,
        porque: L("Volume aeróbico com pouco desgaste. É a maior parte da semana: constrói a base sem atrapalhar a recuperação dos treinos fortes.",
                  "Aerobic volume with little wear. It is most of the week: it builds the base without getting in the way of recovery from hard workouts."),
        fontes: ["Seiler 2010"]
    ) { d in [.passo(Passo(.trabalho, .distancia(metros(d)), .facil))] }

    public static let recuperacao = ModeloTreino(
        id: "recuperacao", nome: L("Recuperação", "Recovery"), tipo: .recuperacao, tipoDose: .distanciaTotal, intensidadePrincipal: .facil,
        porque: L("Corrida bem leve, só para soltar as pernas e somar volume sem cansar.",
                  "A very easy run, just to loosen the legs and add volume without getting tired."),
        fontes: ["Seiler 2010"]
    ) { d in [.passo(Passo(.trabalho, .distancia(metros(d)), .facil))] }

    public static let longao = ModeloTreino(
        id: "longao", nome: L("Longão", "Long run"), tipo: .longao, tipoDose: .distanciaTotal, intensidadePrincipal: .facil,
        porque: L("A corrida mais longa da semana, sempre fácil. Prepara pernas e cabeça para a duração da prova.",
                  "The longest run of the week, always easy. It prepares legs and mind for the duration of the race."),
        fontes: [L("prática de treinadores", "coaching practice")]
    ) { d in [.passo(Passo(.trabalho, .distancia(metros(d)), .facil))] }

    public static let progressivo = ModeloTreino(
        id: "progressivo", nome: L("Progressivo", "Progression run"), tipo: .ritmoProva, tipoDose: .distanciaTotal, intensidadePrincipal: .maratona,
        porque: L("Começa fácil e termina no ritmo de maratona, para treinar ritmo com as pernas já cansadas, como no fim da prova.",
                  "Starts easy and finishes at marathon pace, to practice pace on tired legs, like at the end of the race."),
        fontes: [L("prática de treinadores", "coaching practice")]
    ) { d in
        let total = metros(d)
        let rapido = metros(total / 3)
        return [
            .passo(Passo(.trabalho, .distancia(max(100, total - rapido)), .facil)),
            .passo(Passo(.trabalho, .distancia(rapido), .maratona)),
        ]
    }

    public static let aceleracoes = ModeloTreino(
        id: "aceleracoes", nome: L("Fácil com acelerações", "Easy with strides"), tipo: .facil, tipoDose: .distanciaTotal, intensidadePrincipal: .facil,
        porque: L("Corrida fácil com 6 acelerações de 20 segundos, rápidas e soltas. Treinam técnica e velocidade sem gerar cansaço.",
                  "Easy run with 6 strides of 20 seconds, fast and relaxed. They train technique and speed without causing fatigue."),
        fontes: [L("prática de treinadores", "coaching practice")]
    ) { d in
        [
            .passo(Passo(.trabalho, .distancia(metros(d)), .facil)),
            .repetir(vezes: 6, passos: [
                Passo(.trabalho, .tempo(20), .repeticoes),
                Passo(.recuperacao, .tempo(60), .caminhada),
            ]),
        ]
    }

    // MARK: Limiar

    public static let fartlek = ModeloTreino(
        id: "fartlek", nome: "Fartlek", tipo: .limiar, tipoDose: .minutosDeTrabalho, intensidadePrincipal: .limiar,
        porque: L("Trechos de 2 minutos no limiar alternados com trote, controlados por tempo. Introduz intensidade com menos desgaste que um treino de pista.",
                  "2-minute segments at threshold alternated with jogging, controlled by time. It introduces intensity with less wear than a track workout."),
        fontes: [L("prática de treinadores", "coaching practice")]
    ) { minutos in
        [
            .passo(Passo(.aquecimento, .tempo(600), .facil)),
            .repetir(vezes: reps(minutos, de: 2, minimo: 3), passos: [
                Passo(.trabalho, .tempo(120), .limiar),
                Passo(.recuperacao, .tempo(120), .facil),
            ]),
            .passo(Passo(.desaquecimento, .tempo(600), .facil)),
        ]
    }

    public static let limiarContinuo = ModeloTreino(
        id: "limiar-continuo", nome: L("Limiar contínuo", "Continuous threshold"), tipo: .limiar, tipoDose: .distanciaDeTrabalho, intensidadePrincipal: .limiar,
        porque: L("Corrida contínua no ritmo de limiar, o ritmo que se aguenta por cerca de uma hora. Melhora a capacidade de sustentar um ritmo forte.",
                  "Continuous run at threshold pace, the pace you can hold for about an hour. It improves your ability to sustain a hard pace."),
        fontes: [L("Daniels (prática de treinadores)", "Daniels (coaching practice)")]
    ) { d in [aquecimento(), .passo(Passo(.trabalho, .distancia(metros(d)), .limiar)), desaquecimento()] }

    public static let cruise = ModeloTreino(
        id: "cruise", nome: "Cruise intervals", tipo: .limiar, tipoDose: .distanciaDeTrabalho, intensidadePrincipal: .limiar,
        porque: L("O ritmo de limiar dividido em tiros com 1 minuto de pausa. As pausas curtas permitem mais tempo nesse ritmo.",
                  "Threshold pace split into reps with 1-minute breaks. The short breaks allow more time at that pace."),
        fontes: [L("Daniels (prática de treinadores)", "Daniels (coaching practice)")]
    ) { d in
        let tamanho: Double = d >= 4800 ? 1600 : 1000
        return [
            aquecimento(),
            .repetir(vezes: reps(d, de: tamanho, minimo: 2), passos: [
                Passo(.trabalho, .distancia(tamanho), .limiar),
                Passo(.recuperacao, .tempo(60), .facil),
            ]),
            desaquecimento(),
        ]
    }

    // MARK: Intervalado (VO2máx)

    static func intervalado(_ tamanho: Double, pausa: TimeInterval, porque: String) -> ModeloTreino {
        ModeloTreino(
            id: "intervalado-\(Int(tamanho))", nome: L("Intervalado \(Int(tamanho)) m", "Intervals \(Int(tamanho)) m"), tipo: .intervalado,
            tipoDose: .distanciaDeTrabalho, intensidadePrincipal: .intervalado, porque: porque,
            fontes: [L("Buchheit e Laursen 2013", "Buchheit and Laursen 2013")]
        ) { d in
            [
                aquecimento(),
                .repetir(vezes: reps(d, de: tamanho, minimo: 2), passos: [
                    Passo(.trabalho, .distancia(tamanho), .intervalado),
                    Passo(.recuperacao, .tempo(pausa), .facil),
                ]),
                desaquecimento(),
            ]
        }
    }

    public static let intervalado400 = intervalado(400, pausa: 90, porque: L(
        "Tiros curtos de 400 m perto do ritmo de VO2máx, com trote entre eles. Variação para quando ainda não há volume para tiros longos.",
        "Short 400 m reps near VO2max pace, with jogging between them. A variation for when there is not yet enough volume for long reps."))
    public static let intervalado800 = intervalado(800, pausa: 120, porque: L(
        "Tiros de 800 m perto do ritmo de VO2máx, com trote entre eles. Somam tempo perto do consumo máximo de oxigênio, o estímulo que mais o eleva.",
        "800 m reps near VO2max pace, with jogging between them. They add up time near maximal oxygen uptake, the stimulus that raises it the most."))
    public static let intervalado1000 = intervalado(1000, pausa: 150, porque: L(
        "Tiros de 1.000 m perto do ritmo de VO2máx, com trote entre eles. Somam tempo perto do consumo máximo de oxigênio, o estímulo que mais o eleva.",
        "1,000 m reps near VO2max pace, with jogging between them. They add up time near maximal oxygen uptake, the stimulus that raises it the most."))
    public static let intervalado1200 = intervalado(1200, pausa: 180, porque: L(
        "Tiros de 1.200 m perto do ritmo de VO2máx, com trote entre eles. Os mais longos da série: mais tempo seguido perto do VO2máx.",
        "1,200 m reps near VO2max pace, with jogging between them. The longest of the series: more continuous time near VO2max."))

    public static let escada = ModeloTreino(
        id: "escada", nome: L("Escada", "Ladder"), tipo: .intervalado, tipoDose: .distanciaDeTrabalho, intensidadePrincipal: .intervalado,
        porque: L("Tiros de 400 a 1.200 m subindo e descendo, perto do ritmo de VO2máx. Mesmo estímulo do intervalado, com variedade.",
                  "Reps from 400 to 1,200 m going up and down, near VO2max pace. Same stimulus as intervals, with variety."),
        fontes: [L("Buchheit e Laursen 2013", "Buchheit and Laursen 2013")]
    ) { d in
        let degraus: [Double] = d >= 3600 ? [400, 800, 1200, 800, 400] : d >= 2400 ? [400, 800, 800, 400] : [400, 800, 400]
        var blocos: [Bloco] = [aquecimento()]
        for (i, degrau) in degraus.enumerated() {
            blocos.append(.passo(Passo(.trabalho, .distancia(degrau), .intervalado)))
            if i < degraus.count - 1 { blocos.append(.passo(Passo(.recuperacao, .tempo(120), .facil))) }
        }
        blocos.append(desaquecimento())
        return blocos
    }

    // MARK: Repetições, subidas, ritmo de prova

    static func repeticoes(_ tamanho: Double) -> ModeloTreino {
        ModeloTreino(
            id: "repeticoes-\(Int(tamanho))", nome: L("Repetições \(Int(tamanho)) m", "Repetitions \(Int(tamanho)) m"), tipo: .repeticoes,
            tipoDose: .distanciaDeTrabalho, intensidadePrincipal: .repeticoes,
            porque: L("Tiros curtos e rápidos com recuperação completa. Treinam velocidade e economia de corrida, não o fôlego.",
                      "Short, fast reps with full recovery. They train speed and running economy, not endurance."),
            fontes: [L("Daniels (prática de treinadores)", "Daniels (coaching practice)")]
        ) { d in
            [
                aquecimento(),
                .repetir(vezes: reps(d, de: tamanho, minimo: 2), passos: [
                    Passo(.trabalho, .distancia(tamanho), .repeticoes),
                    Passo(.recuperacao, .distancia(tamanho), .facil),
                ]),
                desaquecimento(),
            ]
        }
    }

    public static let repeticoes200 = repeticoes(200)
    public static let repeticoes400 = repeticoes(400)

    public static let subidas = ModeloTreino(
        id: "subidas", nome: L("Subidas", "Hill repeats"), tipo: .intervalado, tipoDose: .ciclos, intensidadePrincipal: .intervalado,
        porque: L("Tiros de 1 minuto em subida, voltando em trote. Força específica de corrida com menos impacto.",
                  "1-minute uphill reps, jogging back down. Running-specific strength with less impact."),
        fontes: [L("prática de treinadores", "coaching practice")]
    ) { ciclos in
        [
            .passo(Passo(.aquecimento, .tempo(900), .facil)),
            .repetir(vezes: max(1, Int(ciclos.rounded())), passos: [
                Passo(.trabalho, .tempo(60), .intervalado),
                Passo(.recuperacao, .tempo(90), .facil),
            ]),
            .passo(Passo(.desaquecimento, .tempo(600), .facil)),
        ]
    }

    public static let ritmoMaratona = ModeloTreino(
        id: "ritmo-maratona", nome: L("Ritmo de maratona", "Marathon pace"), tipo: .ritmoProva, tipoDose: .distanciaDeTrabalho, intensidadePrincipal: .maratona,
        porque: L("Trecho contínuo no ritmo previsto de maratona. Ensina o corpo e a cabeça o ritmo exato da prova.",
                  "A continuous segment at your predicted marathon pace. It teaches body and mind the exact race pace."),
        fontes: [L("prática de treinadores", "coaching practice")]
    ) { d in [aquecimento(), .passo(Passo(.trabalho, .distancia(metros(d)), .maratona)), desaquecimento()] }

    public static let prova = ModeloTreino(
        id: "prova", nome: L("Prova", "Race"), tipo: .prova, tipoDose: .distanciaTotal, intensidadePrincipal: .prova,
        porque: L("O dia da prova. O ritmo-alvo é o previsto para a distância.", "Race day. The target pace is the one predicted for the distance."),
        fontes: [L("Daniels e Gilbert 1979", "Daniels and Gilbert 1979")]
    ) { d in [.passo(Passo(.trabalho, .distancia(d), .prova))] }

    // MARK: Catálogo

    public static let todos: [ModeloTreino] = [
        facil, recuperacao, longao, progressivo, aceleracoes,
        fartlek, limiarContinuo, cruise,
        intervalado400, intervalado800, intervalado1000, intervalado1200, escada,
        repeticoes200, repeticoes400, subidas, ritmoMaratona, prova,
    ]

    public static func modelo(id: String) -> ModeloTreino? {
        todos.first { $0.id == id }
    }

    /// Outros modelos que dão o mesmo estímulo com a mesma dose (para "trocar por equivalente").
    public static func equivalentes(a modelo: ModeloTreino) -> [ModeloTreino] {
        todos.filter {
            $0.id != modelo.id && $0.tipo == modelo.tipo && $0.tipoDose == modelo.tipoDose
                && $0.intensidadePrincipal == modelo.intensidadePrincipal && $0.tipo != .prova
        }
    }

    /// Caminhada e corrida para quem está começando (estilo Couch to 5K, progressão do app).
    public static func caminhadaCorrida(correrSegundos: TimeInterval, caminharSegundos: TimeInterval, ciclos: Int) -> Treino {
        var blocos: [Bloco] = [.passo(Passo(.aquecimento, .tempo(300), .caminhada))]
        if caminharSegundos <= 0 {
            blocos.append(.passo(Passo(.trabalho, .tempo(correrSegundos * Double(max(1, ciclos))), .facil)))
        } else {
            blocos.append(.repetir(vezes: max(1, ciclos), passos: [
                Passo(.trabalho, .tempo(correrSegundos), .facil),
                Passo(.recuperacao, .tempo(caminharSegundos), .caminhada),
            ]))
        }
        blocos.append(.passo(Passo(.desaquecimento, .tempo(300), .caminhada)))
        return Treino(nome: L("Caminhada e corrida", "Walk and run"), tipo: .facil, blocos: blocos, modeloID: "caminhada-corrida")
    }

    public static let porqueCaminhadaCorrida = L("Alterna corrida leve e caminhada por tempo. A corrida aumenta aos poucos até 30 minutos contínuos.",
                                                 "Alternates easy running and walking by time. Running time builds up gradually to 30 continuous minutes.")
}
