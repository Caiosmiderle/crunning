import Foundation

public enum ErroOperacao: Error, Equatable, Sendable {
    case semanaInvalida
    case diaInvalido
    case semSessao
    case semEquivalente
    case naoSeAplica
    case violaria([Violacao])
}

/// Mudanças no plano como operações sobre dados. Toda operação devolve um plano que
/// passa no `ValidadorPlano`, ou lança erro sem mudar nada.
/// Semanas começam em 1; dias vão de 0 (segunda) a 6 (domingo).
public enum OperacoesPlano {
    /// Troca o conteúdo de dois dias da mesma semana.
    public static func mover(_ plano: Plano, semana: Int, de origem: Int, para destino: Int) throws -> Plano {
        let i = try indice(plano, semana)
        guard (0...6).contains(origem), (0...6).contains(destino), origem != destino else { throw ErroOperacao.diaInvalido }
        guard plano.semanas[i].dias[origem] != nil else { throw ErroOperacao.semSessao }
        var novo = plano
        novo.semanas[i].dias.swapAt(origem, destino)
        return try conferido(novo)
    }

    /// Troca o treino por outro modelo com o mesmo estímulo e a mesma dose.
    public static func trocarPorEquivalente(_ plano: Plano, semana: Int, dia: Int) throws -> Plano {
        let i = try indice(plano, semana)
        guard (0...6).contains(dia) else { throw ErroOperacao.diaInvalido }
        guard let sessao = plano.semanas[i].dias[dia] else { throw ErroOperacao.semSessao }
        guard let id = sessao.treino.modeloID, let modelo = Modelos.modelo(id: id), let dose = sessao.treino.dose else {
            throw ErroOperacao.semEquivalente
        }
        let zonas = plano.zonas
        for alternativa in Modelos.equivalentes(a: modelo) {
            var novo = plano
            novo.semanas[i].dias[dia] = SessaoPlanejada(treino: alternativa.treino(dose: dose), zonas: zonas)
            if ValidadorPlano.validar(novo).isEmpty { return novo }
        }
        throw ErroOperacao.semEquivalente
    }

    /// Reduz o volume de uma semana (fator de 0,5 a 0,95) e refaz as seguintes a partir dela.
    public static func reduzirCarga(_ plano: Plano, semana: Int, fator: Double) throws -> Plano {
        let i = try indice(plano, semana)
        guard plano.entrada.objetivo != .comecarACorrer else { return try repetirSemanaAnterior(plano, semana: semana) }
        let f = min(max(fator, 0.5), 0.95)
        var novo = plano
        let zonas = plano.zonas
        for dia in 0..<7 {
            guard let s = novo.semanas[i].dias[dia], !s.ehProva else { continue }
            GeradorPlano.reduzir(&novo.semanas[i], dia: dia, para: s.distancia * f, zonas: zonas)
        }
        // Com menos volume, os limites que dependem dele (fração, qualidade) ficam mais justos: reequilibra.
        var h = GeradorPlano.historicoInicial(plano.entrada)
        for anterior in plano.semanas.prefix(i) { h.registrar(anterior) }
        let picoCorrida = RegrasPlano.picoMaximoCorrida
            * (h.maiores.suffix(RegrasPlano.janelaPico).max() ?? RegrasPlano.pisoLongaoReferencia)
        GeradorPlano.equilibrar(&novo.semanas[i], zonas: zonas, limite: .greatestFiniteMagnitude, picoCorrida: picoCorrida)
        return try refazer(novo, aPartirDaSemana: semana + 1)
    }

    /// Transforma a semana em alívio (20% menos) e refaz as seguintes.
    public static func inserirAlivio(_ plano: Plano, semana: Int) throws -> Plano {
        let i = try indice(plano, semana)
        guard plano.entrada.objetivo != .comecarACorrer else { return try repetirSemanaAnterior(plano, semana: semana) }
        guard plano.semanas[i].fase != .polimento else { throw ErroOperacao.naoSeAplica }
        var novo = try reduzirCarga(plano, semana: semana, fator: RegrasPlano.fatorAlivio)
        novo.semanas[i].alivio = true
        return try conferido(novo)
    }

    /// Nova data de prova: mantém as semanas antes de `aPartirDaSemana` e refaz o resto
    /// para `semanasRestantes` semanas, com polimento.
    public static func reajustar(_ plano: Plano, aPartirDaSemana semana: Int, semanasRestantes: Int) throws -> Plano {
        guard semana >= 1, semana <= plano.semanas.count + 1, semanasRestantes >= 1 else { throw ErroOperacao.semanaInvalida }
        guard plano.entrada.objetivo.distanciaProva != nil else { throw ErroOperacao.naoSeAplica }
        var entrada = plano.entrada
        entrada.semanas = semana - 1 + semanasRestantes
        guard entrada.semanas <= 30 else { throw ErroOperacao.semanaInvalida }
        let fases = Array(GeradorPlano.fasesDoPlano(entrada).dropFirst(semana - 1))
        var base = plano
        base.entrada = entrada
        base.semanas = Array(plano.semanas.prefix(semana - 1))
        base.semanasConcluidas = semana - 1
        return try refazer(base, aPartirDaSemana: semana, fases: fases)
    }

    /// Volta depois de uma pausa: a semana `aPartirDaSemana` começa com uma fração do
    /// volume de antes (`Adaptacao.fatorRetomada`) e as seguintes sobem aos poucos.
    public static func retomarAposPausa(_ plano: Plano, aPartirDaSemana semana: Int, diasParado: Int) throws -> Plano {
        _ = try indice(plano, semana)
        let fator = Adaptacao.fatorRetomada(diasParado: diasParado)
        guard fator < 1 else { return plano }
        if plano.entrada.objetivo == .comecarACorrer {
            let voltar = diasParado >= 28 ? 4 : diasParado >= 14 ? 2 : 1
            return try recuarIniciante(plano, semana: semana, passos: voltar)
        }
        let anteriores = plano.semanas.prefix(semana - 1)
        var h = GeradorPlano.historicoInicial(plano.entrada)
        for s in anteriores { h.registrar(s) }
        let antes = h.ultimoSemAlivio
        // Depois de parar, a maior corrida recente também cai na mesma proporção.
        h.maiores = [max(RegrasPlano.pisoLongaoReferencia, (h.maiores.suffix(RegrasPlano.janelaPico).max() ?? 0) * fator)]
        let fases = plano.semanas.dropFirst(semana - 1).map(\.fase)
        var novo = plano
        novo.semanas = Array(anteriores) + GeradorPlano.gerarSemanas(
            plano.entrada, zonas: plano.zonas, fases: fases, primeira: semana,
            historico: h, volumeForcado: antes * fator, alivioForcado: nil
        )
        return try conferido(novo)
    }

    // MARK: Internos

    static func indice(_ plano: Plano, _ semana: Int) throws -> Int {
        guard semana >= 1, semana <= plano.semanas.count else { throw ErroOperacao.semanaInvalida }
        return semana - 1
    }

    static func conferido(_ plano: Plano) throws -> Plano {
        let erros = ValidadorPlano.validar(plano)
        guard erros.isEmpty else { throw ErroOperacao.violaria(erros) }
        return plano
    }

    /// Refaz as semanas a partir de `semana` com o gerador, usando o que já existe antes como histórico.
    static func refazer(_ plano: Plano, aPartirDaSemana semana: Int, fases fasesNovas: [Fase]? = nil) throws -> Plano {
        guard semana <= plano.entrada.semanas else { return try conferido(plano) }
        let anteriores = plano.semanas.prefix(semana - 1)
        var h = GeradorPlano.historicoInicial(plano.entrada)
        for s in anteriores { h.registrar(s) }
        let fases = fasesNovas ?? plano.semanas.dropFirst(semana - 1).map(\.fase)
        var novo = plano
        novo.semanas = Array(anteriores) + GeradorPlano.gerarSemanas(
            plano.entrada, zonas: plano.zonas, fases: fases, primeira: semana,
            historico: h, volumeForcado: nil, alivioForcado: nil
        )
        novo.regras = GeradorPlano.regras(novo.entrada, semanas: novo.semanas)
        return try conferido(novo)
    }

    /// No começar a correr, "aliviar" é repetir a semana anterior.
    static func repetirSemanaAnterior(_ plano: Plano, semana: Int) throws -> Plano {
        try recuarIniciante(plano, semana: semana, passos: 1)
    }

    /// Recomeça a progressão de caminhada e corrida alguns passos atrás.
    static func recuarIniciante(_ plano: Plano, semana: Int, passos: Int) throws -> Plano {
        let i = try indice(plano, semana)
        let progressao = RegrasPlano.progressaoCaminhadaCorrida
        let atual = indiceProgressao(plano.semanas[i], padrao: min(i, progressao.count - 1))
        let inicio = max(0, atual - passos)
        var novo = plano
        let dias = plano.semanas[i].dias.indices.filter { plano.semanas[i].dias[$0] != nil }
        let zonas = plano.zonas
        for (k, j) in (i..<plano.semanas.count).enumerated() {
            let p = progressao[min(inicio + k, progressao.count - 1)]
            var semanaDias = [SessaoPlanejada?](repeating: nil, count: 7)
            for dia in dias {
                semanaDias[dia] = SessaoPlanejada(
                    treino: Modelos.caminhadaCorrida(correrSegundos: p.correr, caminharSegundos: p.caminhar, ciclos: p.ciclos),
                    zonas: zonas
                )
            }
            novo.semanas[j].dias = semanaDias
        }
        return try conferido(novo)
    }

    /// Em que passo da progressão de caminhada e corrida a semana está (pelo treino, não pelo número).
    static func indiceProgressao(_ semana: SemanaPlano, padrao: Int) -> Int {
        guard let treino = semana.sessoes.first?.treino else { return padrao }
        let progressao = RegrasPlano.progressaoCaminhadaCorrida
        return progressao.indices.last { i in
            let p = progressao[i]
            return Modelos.caminhadaCorrida(correrSegundos: p.correr, caminharSegundos: p.caminhar, ciclos: p.ciclos).blocos == treino.blocos
        } ?? padrao
    }
}
