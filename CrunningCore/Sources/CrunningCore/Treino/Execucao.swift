import Foundation

/// O que se faz numa etapa da execução: um trecho de corrida ou um exercício do aquecimento guiado.
public enum ConteudoEtapa: Codable, Sendable, Equatable {
    case corrida(Passo)
    case exercicio(ExercicioAquecimento)
}

/// Fotografia dos acumulados num instante (começo e fim de etapa, volta manual).
public struct MarcoExecucao: Codable, Sendable, Equatable {
    public var instante: Date
    public var distancia: Double
    public var tempoMovimento: TimeInterval
    /// Tempo de relógio sem as pausas manuais (a pausa automática não para este).
    public var tempoAtivo: TimeInterval
}

/// Uma leitura da gravação, entregue ao motor de blocos a cada segundo e a cada ponto do GPS.
public struct LeituraExecucao: Sendable, Equatable {
    public var instante: Date
    public var distancia: Double
    public var tempoMovimento: TimeInterval
    public var ritmoAtual: Double?
    public var pausadaManual: Bool

    public init(instante: Date, distancia: Double, tempoMovimento: TimeInterval, ritmoAtual: Double?, pausadaManual: Bool = false) {
        self.instante = instante
        self.distancia = distancia
        self.tempoMovimento = tempoMovimento
        self.ritmoAtual = ritmoAtual
        self.pausadaManual = pausadaManual
    }
}

/// Onde o ritmo atual está em relação à faixa-alvo. "Forte" = mais de 5% fora (escolha do app).
public enum SituacaoRitmo: Equatable, Sendable {
    case semDados
    case dentro
    /// Mais devagar que a faixa.
    case lento(forte: Bool)
    /// Mais rápido que a faixa.
    case rapido(forte: Bool)

    public static let margemLeve = 0.05

    public static func avaliar(_ ritmo: Double?, faixa: FaixaRitmo) -> SituacaoRitmo {
        guard let ritmo, ritmo.isFinite, ritmo > 0 else { return .semDados }
        if faixa.contem(ritmo) { return .dentro }
        if ritmo > faixa.lento { return .lento(forte: ritmo > faixa.lento * (1 + margemLeve)) }
        return .rapido(forte: ritmo < faixa.rapido * (1 - margemLeve))
    }

    /// Escala do medidor: 0 = devagar demais, 1 = rápido demais.
    static func limites(_ faixa: FaixaRitmo) -> (lento: Double, rapido: Double) {
        let folga = max(faixa.lento - faixa.rapido, faixa.alvo * 0.06)
        return (faixa.lento + folga, faixa.rapido - folga)
    }

    /// Posição do ritmo no medidor (0 a 1, com o mais rápido à direita).
    public static func posicao(_ ritmo: Double, faixa: FaixaRitmo) -> Double {
        let l = limites(faixa)
        return min(max((l.lento - ritmo) / (l.lento - l.rapido), 0), 1)
    }

    /// Trecho do medidor ocupado pela faixa-alvo.
    public static func faixaNoMedidor(_ faixa: FaixaRitmo) -> ClosedRange<Double> {
        posicao(faixa.lento, faixa: faixa)...posicao(faixa.rapido, faixa: faixa)
    }
}

public enum AvisoRitmo: String, Codable, Equatable, Sendable {
    case acelerar
    case reduzir
    case voltouAoRitmo
}

public enum EventoExecucao: Equatable, Sendable {
    case comecouEtapa(Int)
    /// Últimos segundos da etapa: 3, 2, 1.
    case contagem(Int)
    case ritmo(AvisoRitmo)
    case volta(numero: Int, duracao: TimeInterval, distancia: Double)
    case terminouTreino
}

extension Passo {
    /// Tipo de treino que dá a cor do passo na linha do tempo e na execução.
    public var tipoParaCor: TipoTreino {
        switch intensidade {
        case .caminhada: .caminhada
        case .facil: funcao == .recuperacao ? .recuperacao : .facil
        case .maratona: .ritmoProva
        case .limiar: .limiar
        case .intervalado: .intervalado
        case .repeticoes: .repeticoes
        case .prova: .prova
        }
    }
}

/// Uma etapa da execução, já com as repetições abertas.
public struct EtapaExecucao: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let conteudo: ConteudoEtapa
    /// Bloco do treino de onde a etapa veio (nil no exercício do aquecimento guiado).
    public let bloco: Int?
    public let repeticao: Int?
    public let totalRepeticoes: Int?
    public let faixa: FaixaRitmo?
    /// Como foi planejada (para o resumo).
    public let planejado: Medida
    /// O que encerra a etapa. Na esteira, a distância vira tempo pelo ritmo-alvo.
    public let medida: Medida
    public let duracaoEstimada: TimeInterval
    public let distanciaEstimada: Double
    public internal(set) var inicio: MarcoExecucao?
    public internal(set) var fim: MarcoExecucao?
    public internal(set) var concluida = false
    public internal(set) var pulada = false

    public var passo: Passo? {
        if case let .corrida(p) = conteudo { return p }
        return nil
    }

    public var exercicio: ExercicioAquecimento? {
        if case let .exercicio(e) = conteudo { return e }
        return nil
    }

    /// Nome curto para a tela e para a voz.
    public var nome: String {
        switch conteudo {
        case let .exercicio(e): return e.nome
        case let .corrida(p): return EtapaExecucao.nome(p)
        }
    }

    public static func nome(_ p: Passo) -> String {
        switch p.funcao {
        case .aquecimento: return L("Aquecimento", "Warm-up")
        case .desaquecimento: return L("Desaquecimento", "Cool-down")
        case .recuperacao: return p.intensidade == .caminhada ? L("Caminhada", "Walk") : L("Recuperação", "Recovery")
        case .trabalho:
            switch p.intensidade {
            case .caminhada: return L("Caminhada", "Walk")
            case .facil: return L("Corrida leve", "Easy run")
            case .maratona: return L("Ritmo de maratona", "Marathon pace")
            case .limiar: return L("Limiar", "Threshold")
            case .intervalado: return L("Tiro", "Rep")
            case .repeticoes: return L("Tiro rápido", "Fast rep")
            case .prova: return L("Ritmo de prova", "Race pace")
            }
        }
    }

    /// Tipo usado para a cor da etapa (o exercício do aquecimento fica na cor da caminhada).
    public var tipo: TipoTreino {
        guard case let .corrida(p) = conteudo else { return .caminhada }
        return p.tipoParaCor
    }

    /// Recuperação, caminhada e exercício contam o relógio mesmo parado: na pausa entre tiros é
    /// normal ficar em pé, e a pausa automática não pode congelar a recuperação.
    public var contaTempoAtivo: Bool {
        switch conteudo {
        case .exercicio: return true
        case let .corrida(p): return p.funcao == .recuperacao || p.intensidade == .caminhada
        }
    }
}

/// Resultado de uma etapa para o resumo (planejado x realizado).
public struct ResultadoEtapa: Codable, Sendable, Equatable, Identifiable {
    public enum Situacao: String, Codable, Sendable {
        case feita
        case parcial
        case pulada
        case naoFeita
    }

    public let id: Int
    public let nome: String
    public let tipo: TipoTreino
    public let repeticao: Int?
    public let totalRepeticoes: Int?
    public let ehExercicio: Bool
    public let planejado: Medida
    public let faixa: FaixaRitmo?
    public let distancia: Double
    public let duracao: TimeInterval
    public let situacao: Situacao

    public init(id: Int, nome: String, tipo: TipoTreino, repeticao: Int?, totalRepeticoes: Int?, ehExercicio: Bool,
                planejado: Medida, faixa: FaixaRitmo?, distancia: Double, duracao: TimeInterval, situacao: Situacao) {
        self.id = id
        self.nome = nome
        self.tipo = tipo
        self.repeticao = repeticao
        self.totalRepeticoes = totalRepeticoes
        self.ehExercicio = ehExercicio
        self.planejado = planejado
        self.faixa = faixa
        self.distancia = distancia
        self.duracao = duracao
        self.situacao = situacao
    }

    /// Ritmo médio da etapa (nil em exercício, sem distância medida ou trecho curto demais).
    public var ritmo: Double? {
        guard !ehExercicio, distancia >= 50, duracao > 0 else { return nil }
        return duracao / distancia * 1000
    }

    public var noRitmo: Bool? {
        guard let ritmo, let faixa else { return nil }
        return SituacaoRitmo.avaliar(ritmo, faixa: faixa) == .dentro
    }
}

/// Motor da execução por blocos, como valor puro (salvo junto com a corrida para continuar se o
/// iOS fechar o app). Recebe leituras da gravação e devolve eventos: etapa nova, contagem
/// regressiva, aviso de ritmo, volta e fim do treino. Regras e números em docs/CIENCIA.md
/// ("Execução do treino").
public struct ExecucaoTreino: Codable, Sendable {
    /// Fora da faixa por pelo menos isto (em movimento) antes de avisar.
    public static let atrasoAvisoRitmo: TimeInterval = 15
    /// No máximo um aviso de ritmo a cada intervalo, por etapa.
    public static let intervaloAvisoRitmo: TimeInterval = 60
    /// Nos primeiros segundos de cada etapa o ritmo ainda está mudando: sem aviso.
    public static let rampaInicial: TimeInterval = 20

    public let treino: Treino
    public let esteira: Bool
    /// Fração aplicada às faixas de ritmo pelo calor (`Calor`); nil = sem ajuste.
    public let ajusteCalor: Double?
    public private(set) var etapas: [EtapaExecucao]
    public private(set) var atual = 0
    public private(set) var comecou = false
    public private(set) var encerrada = false
    public private(set) var voltas: [MarcoExecucao] = []

    var tempoAtivo: TimeInterval = 0
    var ultimoInstante: Date?
    var ultimaDistancia: Double?
    var ultimoMovimento: TimeInterval?
    var ultimaContagem: Int?
    var direcaoFora: AvisoRitmo?
    var foraDesde: TimeInterval?
    var ultimoAvisoRitmo: TimeInterval?
    var avisouFora = false

    /// - Parameters:
    ///   - zonas: ritmos do usuário; sem elas, não há faixa-alvo (vale o esforço) e as estimativas usam um VDOT médio.
    ///   - aquecimentoGuiado: insere a rotina de `Aquecimento` quando o treino pede (veja `rotinaIndicada`).
    ///   - esteira: sem GPS; trechos por distância viram tempo pelo ritmo-alvo e não há aviso de ritmo.
    public init(treino: Treino, zonas: Zonas?, aquecimentoGuiado: Bool, esteira: Bool, ajusteCalor: Double = 0) {
        self.treino = treino
        self.esteira = esteira
        self.ajusteCalor = ajusteCalor > 0 ? ajusteCalor : nil
        let estimativa = zonas ?? Zonas.estimativaSemReferencia(.intermediario)

        struct Rascunho {
            var conteudo: ConteudoEtapa
            var bloco: Int?
            var repeticao: Int?
            var total: Int?
        }
        var lista: [Rascunho] = []
        for (b, bloco) in treino.blocos.enumerated() {
            switch bloco {
            case let .passo(p):
                lista.append(Rascunho(conteudo: .corrida(p), bloco: b))
            case let .repetir(vezes, passos):
                for k in 1...max(1, vezes) {
                    for p in passos { lista.append(Rascunho(conteudo: .corrida(p), bloco: b, repeticao: k, total: max(1, vezes))) }
                }
            }
        }

        if aquecimentoGuiado, let rotina = Self.rotinaIndicada(para: treino) {
            let exercicios = rotina.etapas.flatMap(\.exercicios)
            let aquece = lista.firstIndex { r in
                if case let .corrida(p) = r.conteudo { return p.funcao == .aquecimento && r.repeticao == nil }
                return false
            }
            if let aquece {
                // O trote do treino já é o começo do aquecimento: entram a mobilidade, os educativos e as acelerações.
                let extras = exercicios.filter { $0.id != "trote" }.map { Rascunho(conteudo: .exercicio($0)) }
                lista.insert(contentsOf: extras, at: aquece + 1)
            } else {
                let extras = exercicios.map { e -> Rascunho in
                    if e.id == "trote", case let .tempo(t) = e.medida {
                        return Rascunho(conteudo: .corrida(Passo(.aquecimento, .tempo(t), .facil)))
                    }
                    return Rascunho(conteudo: .exercicio(e))
                }
                lista.insert(contentsOf: extras, at: 0)
            }
        }

        etapas = lista.enumerated().map { i, r -> EtapaExecucao in
            switch r.conteudo {
            case let .exercicio(e):
                let t = e.duracaoEstimada
                return EtapaExecucao(
                    id: i, conteudo: r.conteudo, bloco: nil, repeticao: nil, totalRepeticoes: nil, faixa: nil,
                    planejado: .tempo(t), medida: .tempo(t), duracaoEstimada: t, distanciaEstimada: 0
                )
            case let .corrida(p):
                let distanciaProva: Double?
                if case let .distancia(d) = p.medida { distanciaProva = d } else { distanciaProva = nil }
                let faixa = (p.intensidade == .caminhada) ? nil
                    : zonas.map { Calor.ajustar($0.faixa(p.intensidade, distanciaProva: distanciaProva), fracao: ajusteCalor) }
                let est = p.estimativa(zonas: estimativa)
                var medida = p.medida
                if esteira, case let .distancia(d) = p.medida {
                    let ritmo = estimativa.faixa(p.intensidade, distanciaProva: d).alvo
                    medida = .tempo(max(5, (d / 1000 * ritmo / 5).rounded() * 5))
                }
                return EtapaExecucao(
                    id: i, conteudo: r.conteudo, bloco: r.bloco, repeticao: r.repeticao, totalRepeticoes: r.total,
                    faixa: faixa, planejado: p.medida, medida: medida, duracaoEstimada: est.duracao, distanciaEstimada: est.distancia
                )
            }
        }
    }

    /// Rotina de aquecimento para o treino, se ele pedir: tipo forte (`Aquecimento.rotina`) e o
    /// primeiro trecho de trabalho já de qualidade (no progressivo, o começo fácil já aquece).
    public static func rotinaIndicada(para treino: Treino) -> RotinaAquecimento? {
        guard let rotina = Aquecimento.rotina(para: treino.tipo) else { return nil }
        guard let primeiro = treino.passosExpandidos.first(where: { $0.funcao == .trabalho }),
              primeiro.intensidade.ehQualidade else { return nil }
        return rotina
    }

    // MARK: Leituras

    public var etapaAtual: EtapaExecucao? { atual < etapas.count ? etapas[atual] : nil }
    public var terminou: Bool { comecou && atual >= etapas.count }
    public var duracaoEstimada: TimeInterval { etapas.reduce(0) { $0 + $1.duracaoEstimada } }
    public var distanciaEstimada: Double { etapas.reduce(0) { $0 + $1.distanciaEstimada } }

    /// Quanto falta na etapa atual, na unidade da medida (segundos ou metros).
    public func restante(_ l: LeituraExecucao) -> Double? {
        guard atual < etapas.count else { return nil }
        return restante(etapas[atual], l)
    }

    /// Fração feita da etapa atual (0 a 1).
    public func progresso(_ l: LeituraExecucao) -> Double {
        guard let etapa = etapaAtual, let resta = restante(etapa, l) else { return 0 }
        let total: Double
        switch etapa.medida {
        case let .tempo(t): total = t
        case let .distancia(d): total = d
        }
        guard total > 0 else { return 1 }
        return min(max(1 - resta / total, 0), 1)
    }

    /// Fração feita do treino inteiro, pelo tempo estimado das etapas.
    public func progressoTotal(_ l: LeituraExecucao) -> Double {
        let total = duracaoEstimada
        guard total > 0 else { return 0 }
        let feitas = etapas.prefix(atual).reduce(0) { $0 + $1.duracaoEstimada }
        let atualFeita = (etapaAtual?.duracaoEstimada ?? 0) * progresso(l)
        return min((feitas + atualFeita) / total, 1)
    }

    // MARK: Comandos

    public mutating func iniciar(_ l: LeituraExecucao) -> [EventoExecucao] {
        guard !comecou, !etapas.isEmpty else { return [] }
        comecou = true
        lembrar(l)
        etapas[0].inicio = marco(l)
        return [.comecouEtapa(0)]
    }

    public mutating func atualizar(_ l: LeituraExecucao) -> [EventoExecucao] {
        guard comecou, !encerrada else { return [] }
        avancarRelogio(l)
        defer { lembrar(l) }
        var eventos: [EventoExecucao] = []
        var voltasNoLaco = 0
        while atual < etapas.count, voltasNoLaco <= etapas.count, let resta = restante(etapas[atual], l), resta <= 0 {
            eventos += concluirAtual(l, pulada: false)
            voltasNoLaco += 1
        }
        guard atual < etapas.count else { return eventos }
        eventos += contagem(l)
        eventos += avisoRitmo(l)
        return eventos
    }

    /// Pula a etapa atual (a tela pede confirmação antes).
    public mutating func pular(_ l: LeituraExecucao) -> [EventoExecucao] {
        guard comecou, !encerrada, atual < etapas.count else { return [] }
        avancarRelogio(l)
        defer { lembrar(l) }
        return concluirAtual(l, pulada: true)
    }

    /// Volta manual: marca o instante e devolve a duração e a distância desde a volta anterior.
    public mutating func marcarVolta(_ l: LeituraExecucao) -> [EventoExecucao] {
        guard comecou, let comeco = etapas.first?.inicio else { return [] }
        avancarRelogio(l)
        defer { lembrar(l) }
        let anterior = voltas.last ?? comeco
        let agora = marco(l)
        voltas.append(agora)
        return [.volta(numero: voltas.count, duracao: max(0, agora.tempoMovimento - anterior.tempoMovimento),
                       distancia: max(0, agora.distancia - anterior.distancia))]
    }

    /// Fim da corrida antes (ou depois) do fim do treino: fecha a etapa em andamento.
    public mutating func encerrar(_ l: LeituraExecucao) {
        guard comecou, !encerrada else { return }
        avancarRelogio(l)
        if atual < etapas.count, etapas[atual].inicio != nil, etapas[atual].fim == nil {
            etapas[atual].fim = marco(l)
        }
        encerrada = true
        lembrar(l)
    }

    // MARK: Resultado

    public var resultados: [ResultadoEtapa] {
        etapas.map { e in
            var distancia = 0.0
            var duracao: TimeInterval = 0
            if let i = e.inicio, let f = e.fim {
                distancia = esteira ? 0 : max(0, f.distancia - i.distancia)
                duracao = e.contaTempoAtivo ? max(0, f.tempoAtivo - i.tempoAtivo) : max(0, f.tempoMovimento - i.tempoMovimento)
            }
            let situacao: ResultadoEtapa.Situacao
            if e.pulada {
                situacao = .pulada
            } else if e.inicio == nil {
                situacao = .naoFeita
            } else {
                situacao = e.concluida ? .feita : .parcial
            }
            return ResultadoEtapa(
                id: e.id, nome: e.nome, tipo: e.tipo, repeticao: e.repeticao, totalRepeticoes: e.totalRepeticoes,
                ehExercicio: e.exercicio != nil, planejado: e.planejado, faixa: e.faixa,
                distancia: distancia, duracao: duracao, situacao: situacao
            )
        }
    }

    /// Resultado de um teste de referência (`Modelos.teste`): distância e tempo do trecho forte,
    /// se ele foi feito inteiro com GPS. Vira a prova de referência dos ritmos.
    public var resultadoTeste: (distancia: Double, tempo: TimeInterval)? {
        guard !esteira, treino.modeloID?.hasPrefix(Modelos.prefixoTeste) == true else { return nil }
        guard let e = etapas.first(where: { $0.passo?.funcao == .trabalho && $0.passo?.intensidade == .prova }),
              e.concluida, !e.pulada, case let .distancia(d) = e.planejado,
              let i = e.inicio, let f = e.fim else { return nil }
        let tempo = f.tempoMovimento - i.tempoMovimento
        guard tempo > 0 else { return nil }
        return (d, tempo)
    }

    // MARK: Internos

    func marco(_ l: LeituraExecucao) -> MarcoExecucao {
        MarcoExecucao(instante: l.instante, distancia: l.distancia, tempoMovimento: l.tempoMovimento, tempoAtivo: tempoAtivo)
    }

    mutating func avancarRelogio(_ l: LeituraExecucao) {
        if let anterior = ultimoInstante, !l.pausadaManual {
            tempoAtivo += max(0, l.instante.timeIntervalSince(anterior))
        }
        ultimoInstante = l.instante
    }

    mutating func lembrar(_ l: LeituraExecucao) {
        ultimoInstante = l.instante
        ultimaDistancia = l.distancia
        ultimoMovimento = l.tempoMovimento
    }

    func restante(_ etapa: EtapaExecucao, _ l: LeituraExecucao) -> Double? {
        guard let inicio = etapa.inicio else { return nil }
        switch etapa.medida {
        case let .tempo(t):
            let decorrido = etapa.contaTempoAtivo ? tempoAtivo - inicio.tempoAtivo : l.tempoMovimento - inicio.tempoMovimento
            return t - decorrido
        case let .distancia(d):
            return d - (l.distancia - inicio.distancia)
        }
    }

    /// Fecha a etapa atual e abre a próxima no mesmo instante. Num trecho por distância, o fim é
    /// interpolado no metro exato entre a leitura anterior e esta (o ritmo de cada tiro fica certo).
    mutating func concluirAtual(_ l: LeituraExecucao, pulada: Bool) -> [EventoExecucao] {
        var fim = marco(l)
        if !pulada, let inicio = etapas[atual].inicio, case let .distancia(d) = etapas[atual].medida,
           let d0 = ultimaDistancia, let t0 = ultimoMovimento, l.distancia > d0 {
            let alvo = inicio.distancia + d
            if alvo > d0, alvo < l.distancia {
                let fracao = (alvo - d0) / (l.distancia - d0)
                let movimento = t0 + fracao * (l.tempoMovimento - t0)
                fim = MarcoExecucao(
                    instante: l.instante, distancia: alvo, tempoMovimento: movimento,
                    tempoAtivo: tempoAtivo - (l.tempoMovimento - movimento)
                )
            }
        }
        etapas[atual].fim = fim
        etapas[atual].pulada = pulada
        etapas[atual].concluida = !pulada
        atual += 1
        ultimaContagem = nil
        direcaoFora = nil
        foraDesde = nil
        ultimoAvisoRitmo = nil
        avisouFora = false
        guard atual < etapas.count else { return [.terminouTreino] }
        etapas[atual].inicio = fim
        return [.comecouEtapa(atual)]
    }

    mutating func contagem(_ l: LeituraExecucao) -> [EventoExecucao] {
        guard let etapa = etapaAtual, let resta = restante(etapa, l) else { return [] }
        let segundos: Double?
        switch etapa.medida {
        case .tempo:
            segundos = resta
        case .distancia:
            let ritmo = l.ritmoAtual ?? etapa.faixa?.alvo
            segundos = ritmo.map { resta / 1000 * $0 }
        }
        guard let s = segundos, s > 0, s <= 3 else { return [] }
        let n = Int(s.rounded(.up))
        guard n < (ultimaContagem ?? 4) else { return [] }
        ultimaContagem = n
        return [.contagem(n)]
    }

    mutating func avisoRitmo(_ l: LeituraExecucao) -> [EventoExecucao] {
        guard !esteira, let etapa = etapaAtual, let p = etapa.passo, let faixa = etapa.faixa,
              p.intensidade != .caminhada, let inicio = etapa.inicio else { return [] }
        guard l.tempoMovimento - inicio.tempoMovimento >= Self.rampaInicial else { return [] }
        let situacao = SituacaoRitmo.avaliar(l.ritmoAtual, faixa: faixa)
        let direcao: AvisoRitmo?
        switch situacao {
        case .semDados: return []
        case .dentro: direcao = nil
        // Devagar demais só importa nos trechos de qualidade: o fácil não tem piso.
        case .lento: direcao = p.intensidade.ehQualidade ? .acelerar : nil
        case .rapido: direcao = .reduzir
        }
        guard let direcao else {
            direcaoFora = nil
            foraDesde = nil
            if avisouFora, situacao == .dentro {
                avisouFora = false
                return [.ritmo(.voltouAoRitmo)]
            }
            return []
        }
        if direcaoFora != direcao {
            direcaoFora = direcao
            foraDesde = l.tempoMovimento
        }
        guard let desde = foraDesde, l.tempoMovimento - desde >= Self.atrasoAvisoRitmo else { return [] }
        if let ultimo = ultimoAvisoRitmo, l.tempoMovimento - ultimo < Self.intervaloAvisoRitmo { return [] }
        ultimoAvisoRitmo = l.tempoMovimento
        avisouFora = true
        return [.ritmo(direcao)]
    }
}
