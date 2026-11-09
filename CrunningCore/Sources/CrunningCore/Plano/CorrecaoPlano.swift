import Foundation

/// Correção recusada antes de mexer no plano.
public enum ErroCorrecao: Error, Equatable, Sendable {
    /// Novo número de semanas, dias ou teto que o motor não aceita (com o motivo da viabilidade).
    case inviavel(String)
    case foraDosLimites(String)
    case operacao(ErroOperacao)
}

/// Uma correção do plano, sugerida pelo Coach de IA ou escolhida à mão. Toda correção passa pelo
/// motor (`OperacoesPlano` ou `GeradorPlano`) e só é aceita se o plano novo passar no `ValidadorPlano`.
/// Semanas começam em 1; dias vão de 0 (segunda) a 6 (domingo).
public enum CorrecaoPlano: Equatable, Sendable {
    /// Reduz o volume da semana para `fator` (0,5 a 0,95) e refaz as seguintes.
    case reduzirSemana(semana: Int, fator: Double)
    /// Transforma a semana em alívio (20% menos) e refaz as seguintes.
    case aliviarSemana(semana: Int)
    /// Troca dois dias da mesma semana.
    case moverTreino(semana: Int, de: Int, para: Int)
    /// Troca o treino do dia por outro com o mesmo estímulo.
    case trocarTreino(semana: Int, dia: Int)
    /// Refaz o plano com outro número de semanas.
    case mudarSemanas(Int)
    /// Refaz o plano com outro teto de progressão semanal (0,05 a 0,20).
    case mudarTeto(Double)
    /// Refaz o plano com outros dias de corrida e outro dia de longão.
    case mudarDias(Set<Int>, longao: Int)
    /// Volta depois de `dias` parado: a semana recomeça com uma fração do volume (Adaptacao).
    case retomarAposPausa(semana: Int, dias: Int)
    /// Nova data de prova: a partir da semana, o plano passa a ter `semanasRestantes` semanas.
    case reajustarProva(aPartirDaSemana: Int, semanasRestantes: Int)
    /// Prova secundária (de preparação) num dia do plano: véspera e dia seguinte leves e as
    /// semanas seguintes refeitas a partir do volume que sobrou.
    case provaSecundaria(semana: Int, dia: Int, distancia: Double)

    static var nomesDias: [String] {
        [L("segunda", "Monday"), L("terça", "Tuesday"), L("quarta", "Wednesday"), L("quinta", "Thursday"),
         L("sexta", "Friday"), L("sábado", "Saturday"), L("domingo", "Sunday")]
    }

    static func nomeDia(_ d: Int) -> String {
        (0...6).contains(d) ? nomesDias[d] : L("dia \(d)", "day \(d)")
    }

    /// Frase curta do que a correção faz.
    public var descricao: String {
        switch self {
        case let .reduzirSemana(semana, fator):
            let pct = Int((fator * 100).rounded())
            return L("Reduzir a semana \(semana) para \(pct)% do volume",
                     "Reduce week \(semana) to \(pct)% of its volume")
        case let .aliviarSemana(semana):
            return L("Fazer da semana \(semana) uma semana de alívio",
                     "Make week \(semana) a recovery week")
        case let .moverTreino(semana, de, para):
            return L("Semana \(semana): trocar \(Self.nomeDia(de)) com \(Self.nomeDia(para))",
                     "Week \(semana): swap \(Self.nomeDia(de)) with \(Self.nomeDia(para))")
        case let .trocarTreino(semana, dia):
            return L("Semana \(semana): trocar o treino de \(Self.nomeDia(dia)) por um equivalente",
                     "Week \(semana): replace \(Self.nomeDia(dia))'s workout with an equivalent one")
        case let .mudarSemanas(n):
            return L("Refazer o plano com \(n) semanas",
                     "Rebuild the plan with \(n) weeks")
        case let .mudarTeto(t):
            let pct = Int((t * 100).rounded())
            return L("Refazer o plano com aumento de até \(pct)% por semana",
                     "Rebuild the plan with an increase of up to \(pct)% per week")
        case let .mudarDias(dias, longao):
            let lista = dias.sorted().map(Self.nomeDia).joined(separator: ", ")
            return L("Refazer o plano correndo \(lista), longão no \(Self.nomeDia(longao))",
                     "Rebuild the plan running \(lista), long run on \(Self.nomeDia(longao))")
        case let .retomarAposPausa(semana, dias):
            return L("Voltar aos poucos a partir da semana \(semana), depois de \(dias) dias parado",
                     "Ease back in from week \(semana), after \(dias) days off")
        case let .reajustarProva(semana, restantes):
            return L("Refazer a partir da semana \(semana) com \(restantes) semanas até a prova",
                     "Rebuild from week \(semana) with \(restantes) weeks to the race")
        case let .provaSecundaria(semana, dia, distancia):
            let km = Formatador.numero(distancia / 1000, casas: distancia.truncatingRemainder(dividingBy: 1000) == 0 ? 0 : 1)
            return L("Prova secundária de \(km) km na semana \(semana), \(Self.nomeDia(dia))",
                     "Secondary race of \(km) km in week \(semana), \(Self.nomeDia(dia))")
        }
    }

    /// Aplica no plano. Lança erro (e não muda nada) se a correção não couber nas travas.
    public func aplicar(_ plano: Plano) throws -> Plano {
        do {
            switch self {
            case let .reduzirSemana(semana, fator):
                guard (0.5...0.95).contains(fator) else { throw ErroCorrecao.foraDosLimites(L("A redução vai de 50% a 95% do volume.", "The reduction ranges from 50% to 95% of the volume.")) }
                return try OperacoesPlano.reduzirCarga(plano, semana: semana, fator: fator)
            case let .aliviarSemana(semana):
                return try OperacoesPlano.inserirAlivio(plano, semana: semana)
            case let .moverTreino(semana, de, para):
                return try OperacoesPlano.mover(plano, semana: semana, de: de, para: para)
            case let .trocarTreino(semana, dia):
                return try OperacoesPlano.trocarPorEquivalente(plano, semana: semana, dia: dia)
            case let .mudarSemanas(n):
                guard (1...30).contains(n) else { throw ErroCorrecao.foraDosLimites(L("O plano vai de 1 a 30 semanas.", "The plan must be 1 to 30 weeks long.")) }
                var entrada = plano.entrada
                entrada.semanas = n
                return try refazer(entrada)
            case let .mudarTeto(t):
                guard (RegrasPlano.tetoProgressaoMinimo...RegrasPlano.tetoProgressaoMaximo).contains(t) else {
                    throw ErroCorrecao.foraDosLimites(L("O aumento por semana vai de 5% a 20%.", "The weekly increase ranges from 5% to 20%."))
                }
                var entrada = plano.entrada
                entrada.tetoProgressao = t
                return try refazer(entrada)
            case let .mudarDias(dias, longao):
                guard dias.count >= 2, dias.allSatisfy({ (0...6).contains($0) }), dias.contains(longao) else {
                    throw ErroCorrecao.foraDosLimites(L("Escolha pelo menos 2 dias, com o longão num deles.", "Choose at least 2 days, with the long run on one of them."))
                }
                var entrada = plano.entrada
                entrada.diasDisponiveis = dias
                entrada.diaLongao = longao
                return try refazer(entrada)
            case let .retomarAposPausa(semana, dias):
                guard dias > 5 else { throw ErroCorrecao.foraDosLimites(L("Até 5 dias parado, o plano segue igual.", "Up to 5 days off, the plan stays the same.")) }
                return try OperacoesPlano.retomarAposPausa(plano, aPartirDaSemana: semana, diasParado: dias)
            case let .reajustarProva(semana, restantes):
                return try OperacoesPlano.reajustar(plano, aPartirDaSemana: semana, semanasRestantes: restantes)
            case let .provaSecundaria(semana, dia, distancia):
                return try Self.inserirProvaSecundaria(plano, semana: semana, dia: dia, distancia: distancia)
            }
        } catch let erro as ErroOperacao {
            throw ErroCorrecao.operacao(erro)
        }
    }

    static func inserirProvaSecundaria(_ plano: Plano, semana: Int, dia: Int, distancia: Double) throws -> Plano {
        guard (1...plano.semanas.count).contains(semana), (0...6).contains(dia) else {
            throw ErroCorrecao.foraDosLimites(L("Escolha uma semana e um dia do plano.", "Choose a week and a day in the plan."))
        }
        guard plano.entrada.objetivo != .comecarACorrer else {
            throw ErroCorrecao.inviavel(L("No começar a correr, a prova fica para depois do plano.",
                                          "In the start running plan, races come after the plan."))
        }
        guard plano.semanas[semana - 1].fase != .polimento else {
            throw ErroCorrecao.inviavel(L("Nas semanas de polimento a prioridade é chegar descansado à prova principal. Escolha uma semana antes.",
                                          "In taper weeks the priority is to arrive rested for the main race. Choose an earlier week."))
        }
        let principal = plano.entrada.objetivo.distanciaProva ?? 42_195
        guard distancia >= 1000, distancia <= principal else {
            throw ErroCorrecao.foraDosLimites(L("A prova secundária tem que ter de 1 km até a distância da principal.",
                                                "The secondary race must be between 1 km and the main race distance."))
        }
        guard !plano.semanas[semana - 1].temProva else { throw ErroCorrecao.inviavel(L("Esta semana já tem uma prova.", "This week already has a race.")) }
        let zonas = plano.zonas
        var novo = plano
        var treino = Modelos.prova.treino(dose: distancia)
        treino.nome = L("Prova secundária", "Secondary race")
        novo.semanas[semana - 1].dias[dia] = SessaoPlanejada(treino: treino, zonas: zonas)
        // Véspera e dia seguinte sem treino forte (escolha do app): viram recuperação curta.
        func aliviar(_ s: Int, _ d: Int) {
            guard (1...novo.semanas.count).contains(s), (0...6).contains(d), let outra = novo.semanas[s - 1].dias[d], outra.ehForte, !outra.ehProva else { return }
            novo.semanas[s - 1].dias[d] = SessaoPlanejada(treino: Modelos.recuperacao.treino(dose: min(outra.distancia, 5000)), zonas: zonas)
        }
        aliviar(semana, dia - 1)
        aliviar(semana, dia + 1)
        if dia == 6 { aliviar(semana + 1, 0) }
        if dia == 0 { aliviar(semana - 1, 6) }
        // Com o longão trocado por uma recuperação, o volume da semana cai: reequilibra as outras
        // sessões (fração do volume e limites de qualidade), como na redução de carga.
        var h = GeradorPlano.historicoInicial(plano.entrada)
        for anterior in plano.semanas.prefix(semana - 1) { h.registrar(anterior) }
        let picoCorrida = RegrasPlano.picoMaximoCorrida
            * (h.maiores.suffix(RegrasPlano.janelaPico).max() ?? RegrasPlano.pisoLongaoReferencia)
        GeradorPlano.equilibrar(&novo.semanas[semana - 1], objetivo: plano.entrada.objetivo, zonas: zonas,
                                limite: .greatestFiniteMagnitude, picoCorrida: picoCorrida)
        do {
            return try OperacoesPlano.refazer(novo, aPartirDaSemana: semana + 1)
        } catch let ErroOperacao.violaria(erros) {
            let detalhe = erros.prefix(2).map(\.description).joined(separator: "; ")
            throw ErroCorrecao.inviavel(L("A prova não cabe nesta semana sem quebrar as travas (\(detalhe)). Tente outro dia ou semana.",
                                          "The race doesn't fit this week without breaking the safety limits (\(detalhe)). Try another day or week."))
        }
    }

    func refazer(_ entrada: EntradaPlano) throws -> Plano {
        switch GeradorPlano.viabilidade(entrada) {
        case .viavel: break
        case let .curto(_, motivo): throw ErroCorrecao.inviavel(motivo)
        case let .naoRecomendado(motivo): throw ErroCorrecao.inviavel(motivo)
        }
        let novo = GeradorPlano.gerar(entrada)
        let erros = ValidadorPlano.validar(novo)
        guard erros.isEmpty else { throw ErroCorrecao.operacao(.violaria(erros)) }
        return novo
    }
}

/// Antes e depois de uma correção, semana a semana (só as semanas que mudaram).
public struct ComparacaoPlano: Equatable, Sendable {
    public struct Linha: Equatable, Sendable, Identifiable {
        public let semana: Int
        public let volumeAntes: Double?
        public let volumeDepois: Double?
        public let longaoAntes: Double?
        public let longaoDepois: Double?
        public var id: Int { semana }
    }

    public let linhas: [Linha]
    public let semanasAntes: Int
    public let semanasDepois: Int

    public init(antes: Plano, depois: Plano) {
        semanasAntes = antes.semanas.count
        semanasDepois = depois.semanas.count
        let total = max(antes.semanas.count, depois.semanas.count)
        linhas = (0..<total).compactMap { i -> Linha? in
            let a = i < antes.semanas.count ? antes.semanas[i] : nil
            let d = i < depois.semanas.count ? depois.semanas[i] : nil
            guard a != d else { return nil }
            return Linha(
                semana: i + 1,
                volumeAntes: a?.volumeTreino, volumeDepois: d?.volumeTreino,
                longaoAntes: a?.maiorCorrida, longaoDepois: d?.maiorCorrida
            )
        }
    }

    public var mudouAlgo: Bool { !linhas.isEmpty || semanasAntes != semanasDepois }
}
