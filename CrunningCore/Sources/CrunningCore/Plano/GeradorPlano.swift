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
            let polimento = min(RegrasPlano.semanasPolimento(d), e.semanas)
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
        let maiorPermitida = min(
            picoCorrida,
            RegrasPlano.fracaoMaximaCorrida(corridas: corridas, volume: alvo) * alvo,
            distanciaParaDuracao(RegrasPlano.duracaoMaximaCorrida, zonas: zonas),
            RegrasPlano.tetoLongao(e.objetivo)
        )
        let longao = abaixo100(maiorPermitida)

        // Dia do longão: a prova na última semana, o longão nas outras.
        if semanaDaProva, let distancia = e.objetivo.distanciaProva {
            dias[e.diaLongao] = SessaoPlanejada(treino: Modelos.prova.treino(dose: distancia), zonas: zonas)
        } else if longao >= RegrasPlano.corridaMinima {
            dias[e.diaLongao] = sessao(Modelos.longao, dose: longao, zonas: zonas)
        }

        // Aceleracoes numa corrida fácil (base, construção e semana da prova), se o limite de repetições deixar.
        let querAceleracoes = fase == .base || fase == .construcao || semanaDaProva
        let trabalhoAceleracoes = SessaoPlanejada(treino: Modelos.aceleracoes.treino(dose: 3000), zonas: zonas)
            .trabalho[.repeticoes] ?? 0
        let aceleracoes = querAceleracoes && (e.nivel != .iniciante || fase != .base)
            && trabalhoAceleracoes <= RegrasPlano.limiteTrabalho(.repeticoes, volumeSemana: alvo)

        // Qualidade.
        let quantidade = semanaDaProva ? 0 : qualidadeDesejada(fase, nivel: e.nivel, corridas: corridas)
        var orcamento = RegrasPlano.fracaoMaximaQualidade * alvo - (aceleracoes ? trabalhoAceleracoes : 0)
        var diasQualidade: [Int] = []
        for candidato in candidatosQualidade(diasCorrida, diaLongao: e.diaLongao)
        where diasQualidade.count < quantidade && !diasQualidade.contains(where: { adjacente($0, candidato) }) {
            diasQualidade.append(candidato)
        }
        for (slot, dia) in diasQualidade.enumerated() {
            let modelo = escolherModelo(slot: slot, numero: numero, fase: fase, e: e)
            if let s = sessaoQualidade(modelo, e: e, zonas: zonas, fase: fase, alvo: alvo, orcamento: orcamento,
                                       maiorDistancia: max(longao, RegrasPlano.corridaMinima)) {
                dias[dia] = s
                orcamento -= s.trabalhoDeQualidade
            }
        }

        // Corridas fáceis com o que sobra do volume, nunca maiores que o longão.
        var faceis = diasCorrida.filter { dias[$0] == nil }
        let usado = dias.compactMap { $0 }.filter { !$0.ehProva }.reduce(0) { $0 + $1.distancia }
        let restante = alvo - usado
        while !faceis.isEmpty && restante / Double(faceis.count) < RegrasPlano.corridaMinima {
            faceis.removeLast()
        }
        if !faceis.isEmpty {
            let cada = abaixo100(min(restante / Double(faceis.count), max(longao, RegrasPlano.corridaMinima)))
            if cada >= RegrasPlano.corridaMinima {
                var colocouAceleracoes = false
                for dia in faceis {
                    let depoisDeForte = dias[(dia + 6) % 7]?.ehForte ?? false
                    let modelo: ModeloTreino
                    if aceleracoes && !colocouAceleracoes && !depoisDeForte {
                        modelo = Modelos.aceleracoes
                        colocouAceleracoes = true
                    } else {
                        modelo = depoisDeForte ? Modelos.recuperacao : Modelos.facil
                    }
                    dias[dia] = sessao(modelo, dose: cada, zonas: zonas)
                }
            }
        }

        var semana = SemanaPlano(numero: numero, fase: fase, alivio: alivio, dias: dias)
        equilibrar(&semana, zonas: zonas, limite: limite, picoCorrida: picoCorrida)
        return semana
    }

    // MARK: Equilíbrio final (garante as travas depois do arredondamento)

    static func equilibrar(_ semana: inout SemanaPlano, zonas: Zonas, limite: Double, picoCorrida: Double) {
        let distanciaMaxima = distanciaParaDuracao(RegrasPlano.duracaoMaximaCorrida, zonas: zonas)
        for _ in 0..<60 {
            let volume = semana.volumeTreino
            let fracao = RegrasPlano.fracaoMaximaCorrida(corridas: semana.corridas, volume: volume)
            let tetoCorrida = min(fracao * volume, picoCorrida, distanciaMaxima)
            var mudou = false

            if volume > limite {
                let excesso = volume - limite
                if let dia = maiorContinua(semana) {
                    reduzir(&semana, dia: dia, para: semana.dias[dia]!.distancia - excesso, zonas: zonas)
                } else if let dia = semana.dias.indices.filter({ semana.dias[$0].map { !$0.ehProva } ?? false })
                    .max(by: { semana.dias[$0]!.distancia < semana.dias[$1]!.distancia }) {
                    reduzir(&semana, dia: dia, para: semana.dias[dia]!.distancia * 0.85, zonas: zonas)
                }
                continue
            }

            for dia in semana.dias.indices {
                guard let s = semana.dias[dia], !s.ehProva else { continue }
                if s.distancia > tetoCorrida + 1 {
                    let nova = ehContinua(s) ? s.distancia - (s.distancia - tetoCorrida) / max(0.2, 1 - fracao) : s.distancia * 0.85
                    reduzir(&semana, dia: dia, para: min(nova, tetoCorrida), zonas: zonas)
                    mudou = true
                    break
                }
                for (intensidade, metros) in s.trabalho where metros > RegrasPlano.limiteTrabalho(intensidade, volumeSemana: volume) + 1 {
                    reduzir(&semana, dia: dia, para: s.distancia * 0.85, zonas: zonas)
                    mudou = true
                    break
                }
                if mudou { break }
            }
            if mudou { continue }

            let qualidade = semana.sessoes.reduce(0) { $0 + $1.trabalhoDeQualidade }
            if qualidade > RegrasPlano.fracaoMaximaQualidade * volume + 1,
               let dia = semana.dias.indices.filter({ (semana.dias[$0]?.trabalhoDeQualidade ?? 0) > 0 })
                .max(by: { semana.dias[$0]!.trabalhoDeQualidade < semana.dias[$1]!.trabalhoDeQualidade }) {
                reduzir(&semana, dia: dia, para: semana.dias[dia]!.distancia * 0.85, zonas: zonas)
                continue
            }
            break
        }
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

    /// Reduz uma sessão para (no máximo) a distância pedida; se não couber o mínimo, vira descanso.
    static func reduzir(_ semana: inout SemanaPlano, dia: Int, para distancia: Double, zonas: Zonas) {
        guard let s = semana.dias[dia], let id = s.treino.modeloID, let modelo = Modelos.modelo(id: id),
              let dose = s.treino.dose else {
            semana.dias[dia] = nil
            return
        }
        if modelo.tipoDose == .distanciaTotal {
            let nova = abaixo100(min(distancia, s.distancia - 100))
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
        case .distanciaDeTrabalho:
            switch modelo.intensidadePrincipal {
            case .limiar: 1000
            case .intervalado: modelo.id == Modelos.intervalado400.id ? 800 : 1200
            case .repeticoes: 800
            case .maratona: 3000
            default: 1000
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

    static func distanciaParaDuracao(_ segundos: TimeInterval, zonas: Zonas) -> Double {
        segundos / zonas.faixa(.facil).alvo * 1000
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
        linhas.append("Nenhuma corrida passa 10% da maior das 4 semanas anteriores; o longão fica em até 25% a 40% do volume (conforme o número de corridas) e 150 minutos.")
        linhas.append("No máximo \(RegrasPlano.maximoQualidade(e.nivel)) treinos de qualidade por semana, nunca em dias seguidos nem colados no longão, e até 20% do volume em qualidade.")
        if let d = e.objetivo.distanciaProva {
            let n = min(RegrasPlano.semanasPolimento(d), semanas.count)
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
