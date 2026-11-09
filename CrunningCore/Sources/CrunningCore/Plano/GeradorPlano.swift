import Foundation

/// Gera o plano: (objetivo × semanas × nível × dias × volume atual) → fases, volumes
/// semanais e treinos. Determinístico: a mesma entrada dá sempre o mesmo plano.
/// Regras e fontes em docs/CIENCIA.md; as travas são conferidas por `ValidadorPlano`.
public enum GeradorPlano {
    /// O que já aconteceu antes da próxima semana a gerar.
    struct Historico {
        /// Volume de treino de cada semana; o primeiro é a referência de entrada.
        var volumes: [Double]
        /// Maior corrida de cada semana; o primeiro é a referência de entrada.
        var maiores: [Double]
        var ultimoSemAlivio: Double
        /// Maior volume antes do polimento.
        var pico: Double

        init(referencia: Double, longaoReferencia: Double) {
            volumes = [referencia]
            maiores = [longaoReferencia]
            ultimoSemAlivio = referencia
            pico = 0
        }

        mutating func registrar(_ semana: SemanaPlano) {
            volumes.append(semana.volumeTreino)
            maiores.append(semana.maiorCorrida)
            if !semana.alivio && semana.fase != .polimento {
                ultimoSemAlivio = semana.volumeTreino
                pico = max(pico, semana.volumeTreino)
            }
        }
    }

    // MARK: Entrada

    public static func gerar(_ entrada: EntradaPlano) -> Plano {
        let e = normalizar(entrada)
        if e.objetivo == .comecarACorrer { return gerarIniciante(e) }
        let zonas = zonasDa(e)
        let semanas = gerarSemanas(
            e, zonas: zonas, fases: fasesDoPlano(e), primeira: 1,
            historico: historicoInicial(e), volumeForcado: nil, alivioForcado: nil
        )
        return Plano(entrada: e, semanas: semanas, regras: regras(e, semanas: semanas))
    }

    public static func normalizar(_ entrada: EntradaPlano) -> EntradaPlano {
        var e = entrada
        switch e.objetivo {
        case .prova: e.semanas = min(max(e.semanas, 1), 30)
        case .condicionamento: e.semanas = min(max(e.semanas, 4), 30)
        case .comecarACorrer: e.semanas = min(max(e.semanas, RegrasPlano.progressaoCaminhadaCorrida.count), 20)
        }
        var dias = Set(e.diasDisponiveis.filter { (0...6).contains($0) })
        if !(0...6).contains(e.diaLongao) { e.diaLongao = 6 }
        if dias.isEmpty { dias = [e.diaLongao] }
        if dias.count < 2 { dias.insert((dias.first! + 3) % 7) }
        if !dias.contains(e.diaLongao) { e.diaLongao = dias.max()! }
        e.diasDisponiveis = dias
        e.volumeAtual = max(0, e.volumeAtual)
        e.longaoAtual = max(0, e.longaoAtual)
        e.tetoProgressao = min(max(e.tetoProgressao, RegrasPlano.tetoProgressaoMinimo), RegrasPlano.tetoProgressaoMaximo)
        if let v = e.vdot, Zonas(vdot: v) == nil { e.vdot = nil }
        return e
    }

    static func zonasDa(_ e: EntradaPlano) -> Zonas {
        e.vdot.flatMap { Zonas(vdot: $0) } ?? Zonas.estimativaSemReferencia(e.nivel)
    }

    static func historicoInicial(_ e: EntradaPlano) -> Historico {
        Historico(
            referencia: max(e.volumeAtual, RegrasPlano.pisoVolumeReferencia),
            longaoReferencia: max(e.longaoAtual, RegrasPlano.pisoLongaoReferencia)
        )
    }

    /// Fases semana a semana: base, construção, específica (40%, 35%, 25%) e polimento no fim.
    public static func fasesDoPlano(_ e: EntradaPlano) -> [Fase] {
        switch e.objetivo {
        case .comecarACorrer:
            return Array(repeating: .adaptacao, count: e.semanas)
        case .condicionamento:
            let base = max(1, Int((Double(e.semanas) * 0.4).rounded()))
            return Array(repeating: .base, count: base) + Array(repeating: .construcao, count: e.semanas - base)
        case let .prova(d):
            let polimento = RegrasPlano.semanasPolimento(d, totalSemanas: e.semanas)
            let resto = e.semanas - polimento
            var base = Int((Double(resto) * 0.40).rounded())
            var construcao = Int((Double(resto) * 0.35).rounded())
            if resto >= 3 { base = max(base, 1); construcao = max(construcao, 1) }
            base = min(base, resto)
            construcao = min(construcao, resto - base)
            let especifica = resto - base - construcao
            return Array(repeating: .base, count: base) + Array(repeating: .construcao, count: construcao)
                + Array(repeating: .especifica, count: especifica) + Array(repeating: .polimento, count: polimento)
        }
    }

    /// Teto de volume semanal por objetivo e nível (km), nunca abaixo do que a pessoa já corre (escolha do app).
    static func volumePico(_ e: EntradaPlano, referencia: Double) -> Double {
        let tetos: [Double]
        switch e.objetivo {
        case let .prova(d):
            switch d {
            case ..<7_000: tetos = [25, 40, 60]
            case ..<15_000: tetos = [30, 50, 70]
            case ..<30_000: tetos = [35, 55, 80]
            default: tetos = [45, 65, 95]
            }
        case .condicionamento, .comecarACorrer: tetos = [25, 40, 60]
        }
        let indice = Nivel.allCases.firstIndex(of: e.nivel) ?? 0
        return max(tetos[indice] * 1000, referencia)
    }

    // MARK: Semanas

    static func gerarSemanas(
        _ e: EntradaPlano, zonas: Zonas, fases: [Fase], primeira: Int,
        historico inicial: Historico, volumeForcado: Double?, alivioForcado: Int?
    ) -> [SemanaPlano] {
        var h = inicial
        var semanas: [SemanaPlano] = []
        let total = primeira - 1 + fases.count
        let diasCorrida = escolherDias(e)
        let picoAlvo = volumePico(e, referencia: h.volumes.first ?? RegrasPlano.pisoVolumeReferencia)
        let semanasPolimento = fases.filter { $0 == .polimento }.count
        let fatoresPolimento = RegrasPlano.fatoresPolimento(semanasPolimento)
        var indicePolimento = 0
        let aCada = RegrasPlano.aliviaACada(e.nivel)

        for (i, fase) in fases.enumerated() {
            let numero = primeira + i
            let ultima = numero == total
            let proximaEhPolimento = i + 1 < fases.count && fases[i + 1] == .polimento

            var alivio = numero == alivioForcado
            if !alivio, fase != .polimento, !ultima, !proximaEhPolimento, numero > 1, numero % aCada == 0,
               volumeForcado == nil || i > 0 {
                alivio = !(semanas.last?.alivio ?? false)
            }

            let anterior = h.volumes.last ?? 0
            let janela = h.volumes.suffix(RegrasPlano.janelaTeto).max() ?? anterior
            let maiorHistorico = h.volumes.max() ?? anterior
            let limiteSalto = anterior * (1 + RegrasPlano.saltoMaximoSemanal)
            let limite = min(limiteSalto, max(janela * (1 + e.tetoProgressao), maiorHistorico))

            var alvo: Double
            if fase == .polimento {
                let base = h.pico > 0 ? h.pico : maiorHistorico
                alvo = base * fatoresPolimento[min(indicePolimento, fatoresPolimento.count - 1)]
                indicePolimento += 1
            } else if alivio {
                alvo = h.ultimoSemAlivio * RegrasPlano.fatorAlivio
            } else if i == 0, let volumeForcado {
                alvo = volumeForcado
            } else {
                let crescer = janela * (1 + e.tetoProgressao)
                let voltar = min(maiorHistorico, limiteSalto)
                alvo = min(max(crescer, voltar), picoAlvo)
            }
            alvo = min(alvo, limite)

            let semana = montarSemana(
                e, zonas: zonas, numero: numero, fase: fase, alivio: alivio, alvo: alvo, limite: limite,
                diasCorrida: diasCorrida, historico: h, semanaDaProva: ultima && e.objetivo.distanciaProva != nil
            )
            semanas.append(semana)
            h.registrar(semana)
        }
        return semanas
    }

    static func montarSemana(
        _ e: EntradaPlano, zonas: Zonas, numero: Int, fase: Fase, alivio: Bool, alvo: Double, limite: Double,
        diasCorrida: [Int], historico h: Historico, semanaDaProva: Bool
    ) -> SemanaPlano {
        var dias = [SessaoPlanejada?](repeating: nil, count: 7)
        let corridas = diasCorrida.count
        let picoCorrida = RegrasPlano.picoMaximoCorrida
            * (h.maiores.suffix(RegrasPlano.janelaPico).max() ?? RegrasPlano.pisoLongaoReferencia)
        let tetoLongao = min(
            picoCorrida,
            // Margem de 3%: o volume real fecha um pouco abaixo do alvo pelo arredondamento.
            RegrasPlano.fracaoMaximaCorrida(corridas: corridas, volume: alvo, objetivo: e.objetivo) * alvo * 0.97,
            distanciaParaDuracao(RegrasPlano.duracaoMaximaCorrida(e.objetivo), zonas: zonas),
            RegrasPlano.tetoLongao(e.objetivo)
        )
        // Na meia e na maratona o longão é o treino-chave: cresce o que as travas deixam.
        // Nas provas curtas e sem prova, fica numa fração do volume.
        let provaLonga = (e.objetivo.distanciaProva ?? 0) >= 15_000
        let longao = abaixo100(provaLonga ? tetoLongao : min(tetoLongao, RegrasPlano.fracaoLongaoAlvo(corridas: corridas) * alvo))
        let tetoFacil = abaixo100(longao * RegrasPlano.fracaoFacilDoLongao)
        let tetoQualidade = abaixo100(longao * RegrasPlano.fracaoQualidadeDoLongao)

        // Dia do longão: a prova na última semana, o longão nas outras.
        if semanaDaProva, let distancia = e.objetivo.distanciaProva {
            dias[e.diaLongao] = SessaoPlanejada(treino: Modelos.prova.treino(dose: distancia), zonas: zonas)
        } else if longao >= RegrasPlano.corridaMinima {
            dias[e.diaLongao] = sessao(Modelos.longao, dose: longao, zonas: zonas)
        }

        // Acelerações numa corrida fácil (base, construção e semana da prova), se o limite de repetições deixar.
        let querAceleracoes = fase == .base || fase == .construcao || semanaDaProva
        let referenciaAceleracoes = SessaoPlanejada(treino: Modelos.aceleracoes.treino(dose: 3000), zonas: zonas)
        let trabalhoAceleracoes = referenciaAceleracoes.trabalho[.repeticoes] ?? 0
        let extraAceleracoes = max(0, referenciaAceleracoes.distancia - 3000)
        let aceleracoes = querAceleracoes && (e.nivel != .iniciante || fase != .base)
            && trabalhoAceleracoes <= RegrasPlano.limiteTrabalho(.repeticoes, volumeSemana: alvo)

        // Qualidade, sempre menor que o longão.
        let quantidade = semanaDaProva ? 0 : qualidadeDesejada(fase, nivel: e.nivel, corridas: corridas)
        var orcamento = RegrasPlano.fracaoMaximaQualidade * alvo - (aceleracoes ? trabalhoAceleracoes : 0)
        var diasQualidade: [Int] = []
        for candidato in candidatosQualidade(diasCorrida, diaLongao: e.diaLongao)
        where diasQualidade.count < quantidade && !diasQualidade.contains(where: { adjacente($0, candidato) }) {
            diasQualidade.append(candidato)
        }
        for (slot, dia) in diasQualidade.enumerated() {
            let modelo = escolherModelo(slot: slot, numero: numero, fase: fase, e: e)
            var s = sessaoQualidade(modelo, e: e, zonas: zonas, fase: fase, alvo: alvo, orcamento: orcamento,
                                    maiorDistancia: tetoQualidade)
            // Sem espaço para uma dose útil: o treino principal vira fartlek (menos trabalho no limiar);
            // o segundo vira corrida fácil. Melhor um treino forte de verdade que dois de enfeite.
            if s == nil, slot == 0, modelo.id != Modelos.fartlek.id {
                s = sessaoQualidade(Modelos.fartlek, e: e, zonas: zonas, fase: fase, alvo: alvo, orcamento: orcamento,
                                    maiorDistancia: tetoQualidade)
            }
            if let s {
                dias[dia] = s
                orcamento -= s.trabalhoDeQualidade
            }
        }

        // Corridas fáceis com o que sobra do volume, em todos os dias livres que a pessoa deu
        // (cada uma com pelo menos 20 minutos), até 80% do longão. A recuperação depois de um dia
        // forte é mais curta (80% das outras, até 50 minutos) e a diferença vai para as outras.
        let livres = diasCorrida.filter { dias[$0] == nil }
        let usado = dias.compactMap { $0 }.filter { !$0.ehProva }.reduce(0) { $0 + $1.distancia }
        let restante = alvo - usado
        let depoisDeForte: (Int) -> Bool = { dia in dias[(dia + 6) % 7]?.ehForte ?? false }
        let minimoFacil = max(RegrasPlano.corridaMinima, distanciaParaDuracao(RegrasPlano.duracaoMinimaFacil, zonas: zonas))
        let tetoRecuperacao = min(tetoFacil, abaixo100(distanciaParaDuracao(RegrasPlano.duracaoMaximaRecuperacao, zonas: zonas)))
        if restante >= RegrasPlano.corridaMinima, !livres.isEmpty, tetoFacil >= RegrasPlano.corridaMinima {
            let quantidade = max(1, min(livres.count, Int(restante / minimoFacil)))
            // Prefere dias que não vêm logo depois de um dia forte, mantendo a ordem da semana.
            let escolhidos = livres
                .sorted { (depoisDeForte($0) ? 1 : 0, $0) < (depoisDeForte($1) ? 1 : 0, $1) }
                .prefix(quantidade)
                .sorted()
            let distancias = repartir(
                restante,
                pesos: escolhidos.map { depoisDeForte($0) ? RegrasPlano.pesoRecuperacao : 1.0 },
                tetos: escolhidos.map { depoisDeForte($0) ? tetoRecuperacao : tetoFacil }
            )
            var colocouAceleracoes = false
            for (dia, parte) in zip(escolhidos, distancias) {
                let distancia = abaixo100(parte)
                guard distancia >= RegrasPlano.corridaMinima else { continue }
                let doseAceleracoes = abaixo100(distancia - extraAceleracoes)
                if aceleracoes && !colocouAceleracoes && !depoisDeForte(dia) && doseAceleracoes >= RegrasPlano.corridaMinima {
                    dias[dia] = sessao(Modelos.aceleracoes, dose: doseAceleracoes, zonas: zonas)
                    colocouAceleracoes = true
                } else {
                    dias[dia] = sessao(depoisDeForte(dia) ? Modelos.recuperacao : Modelos.facil, dose: distancia, zonas: zonas)
                }
            }
        }

        // Se as fáceis bateram no teto e ainda falta volume (semanas com poucos dias e dois treinos
        // fortes), os treinos de qualidade ganham aquecimento e desaquecimento mais longos, em ritmo
        // fácil, sem mudar a parte forte nem passar de 85% do longão.
        var falta = alvo - dias.compactMap { $0 }.filter { !$0.ehProva }.reduce(0) { $0 + $1.distancia }
        let comQualidade = diasQualidade.filter { dias[$0]?.ehQualidade ?? false }
        for (k, dia) in comQualidade.enumerated() where falta >= 200 {
            guard let s = dias[dia] else { continue }
            let parte = falta / Double(comQualidade.count - k)
            let extra = abaixo100(min(parte, 2 * RegrasPlano.aquecimentoExtraMaximo, tetoQualidade - s.distancia))
            guard extra >= 200 else { continue }
            let nova = estenderAquecimento(s, metros: extra, zonas: zonas)
            dias[dia] = nova
            falta -= nova.distancia - s.distancia
        }

        var semana = SemanaPlano(numero: numero, fase: fase, alivio: alivio, dias: dias)
        equilibrar(&semana, objetivo: e.objetivo, zonas: zonas, limite: limite, picoCorrida: picoCorrida)
        return semana
    }

    // MARK: Equilíbrio final (garante as travas depois do arredondamento)

    /// A primeira trava da semana que ainda não fecha: o dia a encolher e até quanto.
    static func primeiroProblema(
        _ semana: SemanaPlano, objetivo: Objetivo, limite: Double, picoCorrida: Double, distanciaMaxima: Double
    ) -> (dia: Int, alvo: Double)? {
        let volume = semana.volumeTreino
        if volume > limite + 1, let dia = maiorFacil(semana) ?? maiorContinua(semana) ?? maiorSessao(semana) {
            return (dia, semana.dias[dia]!.distancia - (volume - limite))
        }
        let fracao = RegrasPlano.fracaoMaximaCorrida(corridas: semana.corridas, volume: volume, objetivo: objetivo)
        let tetoFracao = semana.corridas <= 1 ? Double.infinity : fracao * volume
        let teto = min(tetoFracao, picoCorrida, distanciaMaxima)
        for dia in 0..<7 {
            guard let s = semana.dias[dia], !s.ehProva else { continue }
            if s.distancia > teto + 1 {
                // Encolher uma corrida também baixa o volume (e o teto pela fração): desconta isso.
                let alvo = teto == tetoFracao ? s.distancia - (s.distancia - teto) / max(0.2, 1 - fracao) : teto
                return (dia, min(alvo, teto))
            }
            if s.trabalho.contains(where: { $0.value > RegrasPlano.limiteTrabalho($0.key, volumeSemana: volume) + 1 }) {
                return (dia, s.distancia * 0.85)
            }
        }
        // O longão é a maior corrida da semana.
        if let diaLongao = semana.dias.indices.first(where: { semana.dias[$0]?.tipo == .longao }) {
            let longao = semana.dias[diaLongao]!.distancia
            let tetoFacil = abaixo100(longao * RegrasPlano.fracaoFacilDoLongao) + 100
            for dia in 0..<7 where dia != diaLongao {
                guard let s = semana.dias[dia], !s.ehProva else { continue }
                let facil = s.tipo == .facil || s.tipo == .recuperacao
                let teto = facil ? tetoFacil : longao * RegrasPlano.fracaoMaximaDoLongao
                if s.distancia > teto + 1 {
                    return (dia, abaixo100(longao * (facil ? RegrasPlano.fracaoFacilDoLongao : RegrasPlano.fracaoQualidadeDoLongao)))
                }
            }
        }
        let qualidade = semana.sessoes.reduce(0) { $0 + $1.trabalhoDeQualidade }
        if qualidade > RegrasPlano.fracaoMaximaQualidade * volume + 1,
           let dia = semana.dias.indices.filter({ (semana.dias[$0]?.trabalhoDeQualidade ?? 0) > 0 })
            .max(by: { semana.dias[$0]!.trabalhoDeQualidade < semana.dias[$1]!.trabalhoDeQualidade }) {
            return (dia, semana.dias[dia]!.distancia * 0.85)
        }
        return nil
    }

    static func equilibrar(_ semana: inout SemanaPlano, objetivo: Objetivo, zonas: Zonas, limite: Double, picoCorrida: Double) {
        let distanciaMaxima = distanciaParaDuracao(RegrasPlano.duracaoMaximaCorrida(objetivo), zonas: zonas)
        for _ in 0..<300 {
            guard let p = primeiroProblema(semana, objetivo: objetivo, limite: limite, picoCorrida: picoCorrida, distanciaMaxima: distanciaMaxima) else {
                return
            }
            let antes = semana.dias[p.dia]
            reduzir(&semana, dia: p.dia, para: p.alvo, zonas: zonas)
            // Sem progresso (sessão que não encolhe mais): vira descanso.
            if semana.dias[p.dia] == antes { semana.dias[p.dia] = nil }
        }
        // Rede de segurança: tira sessões até todas as travas fecharem.
        while let p = primeiroProblema(semana, objetivo: objetivo, limite: limite, picoCorrida: picoCorrida, distanciaMaxima: distanciaMaxima) {
            semana.dias[p.dia] = nil
        }
    }

    /// Maior corrida fácil (fácil, recuperação ou com acelerações).
    static func maiorFacil(_ semana: SemanaPlano) -> Int? {
        let faceis: Set<String> = [Modelos.facil.id, Modelos.recuperacao.id, Modelos.aceleracoes.id]
        return semana.dias.indices
            .filter { semana.dias[$0].map { faceis.contains($0.treino.modeloID ?? "") } ?? false }
            .max { semana.dias[$0]!.distancia < semana.dias[$1]!.distancia }
    }

    static func ehContinua(_ s: SessaoPlanejada) -> Bool {
        guard let id = s.treino.modeloID, let modelo = Modelos.modelo(id: id) else { return false }
        return modelo.tipoDose == .distanciaTotal
    }

    static func maiorContinua(_ semana: SemanaPlano) -> Int? {
        semana.dias.indices
            .filter { semana.dias[$0].map { ehContinua($0) && !$0.ehProva } ?? false }
            .max { semana.dias[$0]!.distancia < semana.dias[$1]!.distancia }
    }

    static func maiorSessao(_ semana: SemanaPlano) -> Int? {
        semana.dias.indices
            .filter { semana.dias[$0].map { !$0.ehProva } ?? false }
            .max { semana.dias[$0]!.distancia < semana.dias[$1]!.distancia }
    }

    /// Reduz uma sessão para (no máximo) a distância pedida; se não couber o mínimo, vira descanso.
    static func reduzir(_ semana: inout SemanaPlano, dia: Int, para distancia: Double, zonas: Zonas) {
        guard let s = semana.dias[dia], let id = s.treino.modeloID, let modelo = Modelos.modelo(id: id),
              let dose = s.treino.dose else {
            semana.dias[dia] = nil
            return
        }
        if modelo.id == Modelos.aceleracoes.id {
            // A distância desta sessão é a dose mais as acelerações: primeiro saem as acelerações.
            let nova = abaixo100(min(dose, distancia))
            semana.dias[dia] = nova >= RegrasPlano.corridaMinima ? sessao(Modelos.facil, dose: nova, zonas: zonas) : nil
            return
        }
        if modelo.tipoDose == .distanciaTotal {
            let nova = abaixo100(min(distancia, dose - 100))
            semana.dias[dia] = nova >= RegrasPlano.corridaMinima ? sessao(modelo, dose: nova, zonas: zonas) : nil
            return
        }
        var novaDose = dose
        for _ in 0..<20 {
            novaDose *= 0.85
            guard novaDose >= doseMinima(modelo) else { break }
            let candidata = SessaoPlanejada(treino: modelo.treino(dose: arredondarDose(novaDose, modelo)), zonas: zonas)
            if candidata.distancia <= distancia || candidata.distancia < s.distancia - 50 {
                semana.dias[dia] = candidata
                return
            }
        }
        semana.dias[dia] = nil
    }

    // MARK: Qualidade

    static func qualidadeDesejada(_ fase: Fase, nivel: Nivel, corridas: Int) -> Int {
        let desejada: Int
        switch fase {
        case .adaptacao: desejada = 0
        case .base: desejada = nivel == .iniciante ? 0 : 1
        case .construcao, .especifica: desejada = 2
        case .polimento: desejada = 1
        }
        return max(0, min(desejada, RegrasPlano.maximoQualidade(nivel), corridas - 2))
    }

    static func candidatosQualidade(_ diasCorrida: [Int], diaLongao: Int) -> [Int] {
        diasCorrida
            .filter { $0 != diaLongao && !adjacente($0, diaLongao) }
            .sorted { a, b in
                let da = distanciaCircular(a, diaLongao), db = distanciaCircular(b, diaLongao)
                return da != db ? da > db : a < b
            }
    }

    static let rodizioIntervalado: [ModeloTreino] = [
        Modelos.intervalado800, Modelos.intervalado1000, Modelos.intervalado400, Modelos.intervalado1200, Modelos.escada,
    ]

    static func escolherModelo(slot: Int, numero: Int, fase: Fase, e: EntradaPlano) -> ModeloTreino {
        let par = numero % 2 == 0
        let distancia = e.objetivo.distanciaProva ?? 10_000
        let iniciante = e.nivel == .iniciante
        switch fase {
        case .adaptacao, .base:
            return par ? Modelos.subidas : Modelos.fartlek
        case .construcao:
            if slot == 0 {
                if iniciante { return par ? Modelos.fartlek : Modelos.limiarContinuo }
                return par ? Modelos.cruise : Modelos.limiarContinuo
            }
            return rodizioIntervalado[numero % rodizioIntervalado.count]
        case .especifica:
            switch distancia {
            case ..<15_000:
                if iniciante { return par ? Modelos.limiarContinuo : Modelos.fartlek }
                if slot == 0 { return [Modelos.intervalado1000, Modelos.intervalado1200, Modelos.escada, Modelos.intervalado800][numero % 4] }
                return par ? Modelos.cruise : Modelos.repeticoes400
            case ..<30_000:
                if slot == 0 || iniciante { return par ? Modelos.cruise : Modelos.limiarContinuo }
                return par ? Modelos.intervalado1000 : Modelos.ritmoMaratona
            default:
                if slot == 0 || iniciante { return Modelos.ritmoMaratona }
                return par ? Modelos.cruise : Modelos.limiarContinuo
            }
        case .polimento:
            return distancia < 15_000 ? Modelos.intervalado1000 : Modelos.cruise
        }
    }

    static func doseMinima(_ modelo: ModeloTreino) -> Double {
        switch modelo.tipoDose {
        case .distanciaTotal: RegrasPlano.corridaMinima
        case .minutosDeTrabalho: 6
        case .ciclos: 4
        // Abaixo disto o treino não vale o desgaste do dia (escolha do app, ver CIENCIA.md).
        case .distanciaDeTrabalho:
            switch modelo.intensidadePrincipal {
            case .limiar: 3000
            case .intervalado: 2000
            case .repeticoes: 1600
            case .maratona: 5000
            default: 2000
            }
        }
    }

    static func arredondarDose(_ dose: Double, _ modelo: ModeloTreino) -> Double {
        switch modelo.tipoDose {
        case .distanciaTotal, .distanciaDeTrabalho: abaixo100(dose)
        case .minutosDeTrabalho: dose.rounded(.down)
        case .ciclos: dose.rounded(.down)
        }
    }

    static func doseInicial(_ modelo: ModeloTreino, e: EntradaPlano, zonas: Zonas, fase: Fase, alvo: Double) -> Double {
        let fator = fase == .polimento ? 0.6 : 1.0
        switch modelo.tipoDose {
        case .distanciaDeTrabalho:
            let teto: Double
            switch modelo.intensidadePrincipal {
            case .limiar: teto = 8000
            case .intervalado: teto = 6000
            case .repeticoes: teto = 3200
            case .maratona: teto = 12_000
            default: teto = 5000
            }
            let limite = RegrasPlano.limiteTrabalho(modelo.intensidadePrincipal, volumeSemana: alvo)
            return min(limite, teto) * fator
        case .minutosDeTrabalho:
            let limiteLimiar = RegrasPlano.limiteTrabalho(.limiar, volumeSemana: alvo)
            let minutos = limiteLimiar / 1000 * zonas.faixa(.limiar).alvo / 60
            return min(minutos, 20) * fator
        case .ciclos:
            let base: Double
            switch e.nivel {
            case .iniciante: base = 5
            case .intermediario: base = 6
            case .avancado: base = 8
            }
            return base * fator
        case .distanciaTotal:
            return alvo * 0.2 * fator
        }
    }

    static func sessaoQualidade(
        _ modelo: ModeloTreino, e: EntradaPlano, zonas: Zonas, fase: Fase, alvo: Double, orcamento: Double, maiorDistancia: Double
    ) -> SessaoPlanejada? {
        var dose = doseInicial(modelo, e: e, zonas: zonas, fase: fase, alvo: alvo)
        for _ in 0..<15 {
            let arredondada = arredondarDose(dose, modelo)
            guard arredondada >= doseMinima(modelo) else { return nil }
            let s = SessaoPlanejada(treino: modelo.treino(dose: arredondada), zonas: zonas)
            let dentroDosLimites = s.trabalho.allSatisfy { $0.value <= RegrasPlano.limiteTrabalho($0.key, volumeSemana: alvo) }
            if dentroDosLimites && s.trabalhoDeQualidade <= orcamento && s.distancia <= maiorDistancia {
                return s
            }
            dose *= 0.85
        }
        return nil
    }

    // MARK: Dias

    static func distanciaCircular(_ a: Int, _ b: Int) -> Int {
        let d = abs(a - b) % 7
        return min(d, 7 - d)
    }

    static func adjacente(_ a: Int, _ b: Int) -> Bool { distanciaCircular(a, b) == 1 }

    /// Dias de corrida: o do longão e os outros o mais espaçados possível.
    static func escolherDias(_ e: EntradaPlano, quantidade: Int? = nil) -> [Int] {
        let disponiveis = e.diasDisponiveis.sorted()
        let n = quantidade ?? min(disponiveis.count, RegrasPlano.maximoCorridas(e.nivel), 6)
        var escolhidos = [e.diaLongao]
        while escolhidos.count < n {
            let livres = disponiveis.filter { !escolhidos.contains($0) }
            guard let proximo = livres.max(by: { a, b in
                let da = escolhidos.map { distanciaCircular(a, $0) }.min() ?? 7
                let db = escolhidos.map { distanciaCircular(b, $0) }.min() ?? 7
                return da != db ? da < db : a > b
            }) else { break }
            escolhidos.append(proximo)
        }
        return escolhidos.sorted()
    }

    // MARK: Começar a correr

    static func gerarIniciante(_ e: EntradaPlano) -> Plano {
        let zonas = zonasDa(e)
        var dias = escolherDias(e, quantidade: min(3, e.diasDisponiveis.count))
        while dias.count > 1, temDiasSeguidos(dias) {
            dias = escolherDias(e, quantidade: dias.count - 1)
        }
        let progressao = RegrasPlano.progressaoCaminhadaCorrida
        var semanas: [SemanaPlano] = []
        for i in 0..<e.semanas {
            let passo = progressao[min(i, progressao.count - 1)]
            var semana = [SessaoPlanejada?](repeating: nil, count: 7)
            for dia in dias {
                let treino = Modelos.caminhadaCorrida(correrSegundos: passo.correr, caminharSegundos: passo.caminhar, ciclos: passo.ciclos)
                semana[dia] = SessaoPlanejada(treino: treino, zonas: zonas)
            }
            semanas.append(SemanaPlano(numero: i + 1, fase: .adaptacao, alivio: false, dias: semana))
        }
        return Plano(entrada: e, semanas: semanas, regras: regras(e, semanas: semanas))
    }

    static func temDiasSeguidos(_ dias: [Int]) -> Bool {
        for a in dias { for b in dias where a < b && adjacente(a, b) { return true } }
        return false
    }

    // MARK: Utilidades

    static func sessao(_ modelo: ModeloTreino, dose: Double, zonas: Zonas) -> SessaoPlanejada {
        SessaoPlanejada(treino: modelo.treino(dose: dose), zonas: zonas)
    }

    static func abaixo100(_ d: Double) -> Double { max(0, (d / 100).rounded(.down) * 100) }

    /// Divide `total` pelos pesos sem passar dos tetos: o que não cabe em quem bateu no teto
    /// vai para as outras. Se nem com todas no teto couber, todas ficam no teto.
    static func repartir(_ total: Double, pesos: [Double], tetos: [Double]) -> [Double] {
        var resultado = [Double](repeating: 0, count: pesos.count)
        var abertas = Array(pesos.indices)
        var resto = total
        while !abertas.isEmpty {
            let soma = abertas.reduce(0) { $0 + pesos[$1] }
            guard soma > 0 else { break }
            let base = resto / soma
            let cheias = abertas.filter { base * pesos[$0] >= tetos[$0] }
            if cheias.isEmpty {
                for i in abertas { resultado[i] = base * pesos[i] }
                break
            }
            for i in cheias {
                resultado[i] = tetos[i]
                resto -= tetos[i]
            }
            abertas.removeAll { cheias.contains($0) }
        }
        return resultado
    }

    /// Mesmo treino com `metros` a mais de trote, metade no aquecimento e metade no desaquecimento.
    static func estenderAquecimento(_ s: SessaoPlanejada, metros: Double, zonas: Zonas) -> SessaoPlanejada {
        let antes = abaixo100(metros / 2)
        let depois = metros - antes
        let ritmoFacil = zonas.faixa(.facil).alvo
        func esticar(_ p: Passo, _ m: Double) -> Passo {
            var novo = p
            switch p.medida {
            case let .distancia(d): novo.medida = .distancia(d + m)
            case let .tempo(t): novo.medida = .tempo(t + m / 1000 * ritmoFacil)
            }
            return novo
        }
        var treino = s.treino
        var faltaAntes = true, faltaDepois = true
        treino.blocos = treino.blocos.map { (bloco: Bloco) -> Bloco in
            guard case let .passo(p) = bloco else { return bloco }
            if p.funcao == .aquecimento, faltaAntes {
                faltaAntes = false
                return .passo(esticar(p, antes))
            }
            if p.funcao == .desaquecimento, faltaDepois {
                faltaDepois = false
                return .passo(esticar(p, depois))
            }
            return bloco
        }
        if faltaAntes { treino.blocos.insert(.passo(Passo(.aquecimento, .distancia(antes), .facil)), at: 0) }
        if faltaDepois { treino.blocos.append(.passo(Passo(.desaquecimento, .distancia(depois), .facil))) }
        return SessaoPlanejada(treino: treino, zonas: zonas)
    }

    static func distanciaParaDuracao(_ segundos: TimeInterval, zonas: Zonas) -> Double {
        segundos / zonas.faixa(.facil).alvo * 1000
    }

    // MARK: Viabilidade e alertas (CIENCIA: "Viabilidade do plano")

    /// Longão de pico recomendado para a prova, limitado pelo tempo máximo de corrida e pelo teto do objetivo.
    static func longaoRecomendado(_ e: EntradaPlano, zonas: Zonas) -> Double? {
        guard let d = e.objetivo.distanciaProva else { return nil }
        return min(
            RegrasPlano.longaoRecomendado(d, nivel: e.nivel),
            distanciaParaDuracao(RegrasPlano.duracaoMaximaCorrida(e.objetivo), zonas: zonas),
            RegrasPlano.tetoLongao(e.objetivo)
        )
    }

    /// Dá para preparar a prova no tempo pedido? O longão sobe até 10% por semana, com alívio e polimento.
    public static func viabilidade(_ entrada: EntradaPlano) -> Viabilidade {
        let e = normalizar(entrada)
        guard let d = e.objetivo.distanciaProva, let recomendado = longaoRecomendado(e, zonas: zonasDa(e)) else { return .viavel }
        func km(_ m: Double) -> String { Formatador.numero(m / 1000, casas: m >= 10_000 ? 0 : 1) + " km" }
        let atual = max(e.longaoAtual, RegrasPlano.pisoLongaoReferencia)
        let crescimento = atual >= recomendado ? 0 : Int((log(recomendado / atual) / log(RegrasPlano.picoMaximoCorrida)).rounded(.up))
        let alivios = crescimento / max(1, RegrasPlano.aliviaACada(e.nivel) - 1)
        let porLongao = crescimento + alivios + RegrasPlano.semanasPolimento(d)
        let minimo = RegrasPlano.semanasMinimas(d, nivel: e.nivel)
        let necessarias = max(minimo, porLongao)
        let nome = e.objetivo.nome.lowercased()
        if necessarias > 30 {
            return .naoRecomendado(motivo: "Para a \(nome) a partir de um longão de \(km(atual)), seriam mais de 30 semanas. Comece por uma prova mais curta ou pelo condicionamento.")
        }
        guard e.semanas < necessarias else { return .viavel }
        let motivo = porLongao > minimo
            ? "Com o seu longão atual de \(km(atual)), a \(nome) pede pelo menos \(necessarias) semanas: o longão precisa chegar a cerca de \(km(recomendado)), subindo até 10% por semana, com alívio e polimento."
            : "A \(nome) pede pelo menos \(necessarias) semanas de preparação."
        return .curto(semanasMinimas: necessarias, motivo: motivo)
    }

    /// Avisos sobre o plano gerado, em linguagem de treinador.
    public static func alertas(_ plano: Plano) -> [String] {
        let e = plano.entrada
        func km(_ m: Double) -> String { Formatador.numero(m / 1000, casas: 1) + " km" }
        var lista: [String] = []
        switch viabilidade(e) {
        case let .curto(_, motivo): lista.append(motivo + " Este plano tem \(e.semanas).")
        case let .naoRecomendado(motivo): lista.append(motivo)
        case .viavel: break
        }
        guard e.objetivo != .comecarACorrer, let primeira = plano.semanas.first else { return lista }
        if e.volumeAtual > 0, primeira.volumeTreino < 0.8 * e.volumeAtual {
            let maior = max(e.longaoAtual, RegrasPlano.pisoLongaoReferencia)
            lista.append("A primeira semana (\(km(primeira.volumeTreino))) fica abaixo do que você corre hoje (\(km(e.volumeAtual))): nenhuma corrida passa 10% da sua maior corrida recente (\(km(maior))) e as outras ficam menores que o longão. O volume sobe junto com o longão. Se você já corre mais longe, informe a maior corrida das últimas 4 semanas.")
        }
        if let recomendado = longaoRecomendado(e, zonas: plano.zonas) {
            let maior = plano.semanas.map(\.maiorCorrida).max() ?? 0
            if maior < 0.9 * recomendado {
                lista.append("O maior longão do plano (\(km(maior))) fica abaixo do recomendado para a prova (cerca de \(km(recomendado))). Mais semanas, mais dias de corrida ou mais volume ajudam.")
            }
        }
        return lista
    }

    // MARK: "Por que este plano?"

    static func regras(_ e: EntradaPlano, semanas: [SemanaPlano]) -> [String] {
        func km(_ m: Double) -> String { Formatador.numero(m / 1000, casas: 0) + " km" }
        var linhas: [String] = []
        let corridas = semanas.map(\.corridas).max() ?? 0
        linhas.append("\(e.objetivo.nome), \(semanas.count) semanas, nível \(e.nivel.nome.lowercased()), até \(corridas) corridas por semana.")

        if e.objetivo == .comecarACorrer {
            linhas.append("Caminhada e corrida alternadas por tempo, com um dia livre entre as sessões. A corrida sobe aos poucos até 30 minutos contínuos.")
            linhas.append("Se uma semana ficar pesada, repita a semana antes de avançar.")
            return linhas
        }

        var trechos: [String] = []
        var inicio = 1
        for (i, s) in semanas.enumerated() where i == semanas.count - 1 || semanas[i + 1].fase != s.fase {
            trechos.append("\(s.fase.nome.lowercased()) (\(inicio == s.numero ? "semana \(s.numero)" : "semanas \(inicio) a \(s.numero)"))")
            inicio = s.numero + 1
        }
        linhas.append("Fases: " + trechos.joined(separator: ", ") + ".")
        let referencia = max(e.volumeAtual, RegrasPlano.pisoVolumeReferencia)
        linhas.append("O volume parte de \(km(referencia)) por semana e sobe no máximo \(Int((e.tetoProgressao * 100).rounded()))% sobre as 3 semanas anteriores, nunca mais de 25% de uma semana para a outra.")
        linhas.append("Semana de alívio a cada \(RegrasPlano.aliviaACada(e.nivel)) semanas, com 20% menos volume.")
        linhas.append("Nenhuma corrida passa 10% da maior das 4 semanas anteriores. O longão é a maior corrida da semana (as fáceis ficam em até 80% dele) e tem limite de fração do volume e de tempo (\(Int(RegrasPlano.duracaoMaximaCorrida(e.objetivo) / 60)) minutos).")
        linhas.append("No máximo \(RegrasPlano.maximoQualidade(e.nivel)) treinos de qualidade por semana, nunca em dias seguidos nem colados no longão, e até 20% do volume em qualidade.")
        if let d = e.objetivo.distanciaProva {
            let n = RegrasPlano.semanasPolimento(d, totalSemanas: semanas.count)
            linhas.append("Polimento de \(n) semana\(n == 1 ? "" : "s"): o volume cai até cerca de metade do pico, com a mesma intensidade e o mesmo número de corridas.")
        }
        if let v = e.vdot {
            linhas.append("Ritmos pelo VDOT \(Formatador.numero(v, casas: 1)), da sua prova de referência.")
        } else {
            linhas.append("Sem prova de referência: siga pelo esforço percebido e pelo teste da fala até registrar uma prova ou um teste.")
        }
        return linhas
    }
}
