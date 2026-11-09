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

    static let nomesDias = ["segunda", "terça", "quarta", "quinta", "sexta", "sábado", "domingo"]

    static func nomeDia(_ d: Int) -> String {
        (0...6).contains(d) ? nomesDias[d] : "dia \(d)"
    }

    /// Frase curta do que a correção faz.
    public var descricao: String {
        switch self {
        case let .reduzirSemana(semana, fator):
            return "Reduzir a semana \(semana) para \(Int((fator * 100).rounded()))% do volume"
        case let .aliviarSemana(semana):
            return "Fazer da semana \(semana) uma semana de alívio"
        case let .moverTreino(semana, de, para):
            return "Semana \(semana): trocar \(Self.nomeDia(de)) com \(Self.nomeDia(para))"
        case let .trocarTreino(semana, dia):
            return "Semana \(semana): trocar o treino de \(Self.nomeDia(dia)) por um equivalente"
        case let .mudarSemanas(n):
            return "Refazer o plano com \(n) semanas"
        case let .mudarTeto(t):
            return "Refazer o plano com aumento de até \(Int((t * 100).rounded()))% por semana"
        case let .mudarDias(dias, longao):
            let lista = dias.sorted().map(Self.nomeDia).joined(separator: ", ")
            return "Refazer o plano correndo \(lista), longão no \(Self.nomeDia(longao))"
        case let .retomarAposPausa(semana, dias):
            return "Voltar aos poucos a partir da semana \(semana), depois de \(dias) dias parado"
        case let .reajustarProva(semana, restantes):
            return "Refazer a partir da semana \(semana) com \(restantes) semanas até a prova"
        }
    }

    /// Aplica no plano. Lança erro (e não muda nada) se a correção não couber nas travas.
    public func aplicar(_ plano: Plano) throws -> Plano {
        do {
            switch self {
            case let .reduzirSemana(semana, fator):
                guard (0.5...0.95).contains(fator) else { throw ErroCorrecao.foraDosLimites("A redução vai de 50% a 95% do volume.") }
                return try OperacoesPlano.reduzirCarga(plano, semana: semana, fator: fator)
            case let .aliviarSemana(semana):
                return try OperacoesPlano.inserirAlivio(plano, semana: semana)
            case let .moverTreino(semana, de, para):
                return try OperacoesPlano.mover(plano, semana: semana, de: de, para: para)
            case let .trocarTreino(semana, dia):
                return try OperacoesPlano.trocarPorEquivalente(plano, semana: semana, dia: dia)
            case let .mudarSemanas(n):
                guard (1...30).contains(n) else { throw ErroCorrecao.foraDosLimites("O plano vai de 1 a 30 semanas.") }
                var entrada = plano.entrada
                entrada.semanas = n
                return try refazer(entrada)
            case let .mudarTeto(t):
                guard (RegrasPlano.tetoProgressaoMinimo...RegrasPlano.tetoProgressaoMaximo).contains(t) else {
                    throw ErroCorrecao.foraDosLimites("O aumento por semana vai de 5% a 20%.")
                }
                var entrada = plano.entrada
                entrada.tetoProgressao = t
                return try refazer(entrada)
            case let .mudarDias(dias, longao):
                guard dias.count >= 2, dias.allSatisfy({ (0...6).contains($0) }), dias.contains(longao) else {
                    throw ErroCorrecao.foraDosLimites("Escolha pelo menos 2 dias, com o longão num deles.")
                }
                var entrada = plano.entrada
                entrada.diasDisponiveis = dias
                entrada.diaLongao = longao
                return try refazer(entrada)
            case let .retomarAposPausa(semana, dias):
                guard dias > 5 else { throw ErroCorrecao.foraDosLimites("Até 5 dias parado, o plano segue igual.") }
                return try OperacoesPlano.retomarAposPausa(plano, aPartirDaSemana: semana, diasParado: dias)
            case let .reajustarProva(semana, restantes):
                return try OperacoesPlano.reajustar(plano, aPartirDaSemana: semana, semanasRestantes: restantes)
            }
        } catch let erro as ErroOperacao {
            throw ErroCorrecao.operacao(erro)
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
