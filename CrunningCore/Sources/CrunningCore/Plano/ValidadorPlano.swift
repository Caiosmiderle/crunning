import Foundation

/// Uma trava do plano que não foi respeitada. Semanas e dias começam em 1 e em 0 (segunda).
public enum Violacao: Equatable, Sendable, CustomStringConvertible {
    case semanaMalFormada(semana: Int)
    case semDescanso(semana: Int)
    case qualidadeDemais(semana: Int, quantidade: Int)
    case diasFortesSeguidos(semana: Int, dia: Int)
    case saltoSemanal(semana: Int)
    case acimaDoTeto(semana: Int)
    case corridaAcimaDoPico(semana: Int, dia: Int)
    case corridaAcimaDaFracao(semana: Int, dia: Int)
    case corridaLongaDemais(semana: Int, dia: Int)
    case trabalhoAcimaDoLimite(semana: Int, dia: Int)
    case qualidadeAcimaDoLimite(semana: Int)
    case semPolimento
    case semProva
    case inicianteSessoesDemais(semana: Int)
    case inicianteDiasSeguidos(semana: Int)
    case inicianteSaltoDeCorrida(semana: Int)

    public var description: String {
        switch self {
        case let .semanaMalFormada(s): "Semana \(s) sem os 7 dias."
        case let .semDescanso(s): "Semana \(s) sem dia de descanso."
        case let .qualidadeDemais(s, q): "Semana \(s) com \(q) treinos de qualidade."
        case let .diasFortesSeguidos(s, d): "Semana \(s): dias fortes seguidos no dia \(d)."
        case let .saltoSemanal(s): "Semana \(s) sobe mais de 25% em relação à anterior."
        case let .acimaDoTeto(s): "Semana \(s) passa o teto de progressão."
        case let .corridaAcimaDoPico(s, d): "Semana \(s), dia \(d): corrida mais de 10% acima da maior das 4 semanas anteriores."
        case let .corridaAcimaDaFracao(s, d): "Semana \(s), dia \(d): corrida grande demais para o volume da semana."
        case let .corridaLongaDemais(s, d): "Semana \(s), dia \(d): corrida de mais de 150 minutos."
        case let .trabalhoAcimaDoLimite(s, d): "Semana \(s), dia \(d): trabalho de qualidade acima do limite da sessão."
        case let .qualidadeAcimaDoLimite(s): "Semana \(s) com mais de 20% do volume em qualidade."
        case .semPolimento: "Plano de prova sem polimento."
        case .semProva: "Plano de prova sem a prova na última semana."
        case let .inicianteSessoesDemais(s): "Semana \(s) com mais de 3 sessões."
        case let .inicianteDiasSeguidos(s): "Semana \(s) com sessões em dias seguidos."
        case let .inicianteSaltoDeCorrida(s): "Semana \(s) aumenta a corrida mais de 25%."
        }
    }
}

/// Confere as travas de docs/CIENCIA.md em qualquer plano (gerado ou alterado).
public enum ValidadorPlano {
    /// Folga só para ruído de ponto flutuante.
    static func cabe(_ valor: Double, em limite: Double) -> Bool { valor <= limite * 1.000_1 + 1 }

    public static func validar(_ plano: Plano) -> [Violacao] {
        let e = plano.entrada
        let zonas = plano.zonas
        var erros: [Violacao] = []

        for semana in plano.semanas where semana.dias.count != 7 {
            erros.append(.semanaMalFormada(semana: semana.numero))
        }
        guard erros.isEmpty else { return erros }

        // Dias fortes seguidos, inclusive de domingo para a segunda seguinte.
        let todos = plano.semanas.flatMap { semana in semana.dias.enumerated().map { (semana.numero, $0.offset, $0.element) } }
        for (a, b) in zip(todos, todos.dropFirst()) where (a.2?.ehForte ?? false) && (b.2?.ehForte ?? false) {
            erros.append(.diasFortesSeguidos(semana: b.0, dia: b.1))
        }

        if e.objetivo == .comecarACorrer {
            return erros + validarIniciante(plano)
        }

        var volumes = [max(e.volumeAtual, RegrasPlano.pisoVolumeReferencia)]
        var maiores = [max(e.longaoAtual, RegrasPlano.pisoLongaoReferencia)]
        let distanciaMaxima = RegrasPlano.duracaoMaximaCorrida / zonas.faixa(.facil).alvo * 1000

        for semana in plano.semanas {
            let n = semana.numero
            let volume = semana.volumeTreino
            if semana.dias.allSatisfy({ $0 != nil }) { erros.append(.semDescanso(semana: n)) }
            let qualidade = semana.sessoes.filter(\.ehQualidade).count
            if qualidade > RegrasPlano.maximoQualidade(e.nivel) { erros.append(.qualidadeDemais(semana: n, quantidade: qualidade)) }

            let anterior = volumes.last!
            if !cabe(volume, em: anterior * (1 + RegrasPlano.saltoMaximoSemanal)) { erros.append(.saltoSemanal(semana: n)) }
            let janela = volumes.suffix(RegrasPlano.janelaTeto).max()!
            if !cabe(volume, em: max(janela * (1 + e.tetoProgressao), volumes.max()!)) { erros.append(.acimaDoTeto(semana: n)) }

            let pico = RegrasPlano.picoMaximoCorrida * maiores.suffix(RegrasPlano.janelaPico).max()!
            let fracao = RegrasPlano.fracaoMaximaCorrida(corridas: semana.corridas, volume: volume)
            for (dia, sessao) in semana.dias.enumerated() {
                guard let s = sessao, !s.ehProva else { continue }
                if !cabe(s.distancia, em: pico) { erros.append(.corridaAcimaDoPico(semana: n, dia: dia)) }
                if !cabe(s.distancia, em: fracao * volume) { erros.append(.corridaAcimaDaFracao(semana: n, dia: dia)) }
                if !cabe(s.distancia, em: distanciaMaxima) { erros.append(.corridaLongaDemais(semana: n, dia: dia)) }
                if s.trabalho.contains(where: { !cabe($0.value, em: RegrasPlano.limiteTrabalho($0.key, volumeSemana: volume)) }) {
                    erros.append(.trabalhoAcimaDoLimite(semana: n, dia: dia))
                }
            }
            let totalQualidade = semana.sessoes.reduce(0) { $0 + $1.trabalhoDeQualidade }
            if !cabe(totalQualidade, em: RegrasPlano.fracaoMaximaQualidade * volume) { erros.append(.qualidadeAcimaDoLimite(semana: n)) }

            volumes.append(volume)
            maiores.append(semana.maiorCorrida)
        }

        if let distancia = e.objetivo.distanciaProva {
            erros += validarPolimento(plano, distancia: distancia)
        }
        return erros
    }

    static func validarPolimento(_ plano: Plano, distancia: Double) -> [Violacao] {
        guard let ultima = plano.semanas.last else { return [.semProva] }
        var erros: [Violacao] = []
        if !ultima.temProva { erros.append(.semProva) }
        let esperadas = max(1, min(RegrasPlano.semanasPolimento(distancia), plano.semanas.count - plano.semanasConcluidas))
        let finais = plano.semanas.suffix(esperadas)
        let antes = plano.semanas.dropLast(esperadas)
        let referencia = max(plano.entrada.volumeAtual, RegrasPlano.pisoVolumeReferencia)
        let pico = antes.map(\.volumeTreino).max() ?? referencia
        let polimentoOk = finais.allSatisfy { $0.fase == .polimento && cabe($0.volumeTreino, em: pico * 0.85) }
            && cabe(ultima.volumeTreino, em: pico * 0.60)
        if !polimentoOk { erros.append(.semPolimento) }
        return erros
    }

    static func validarIniciante(_ plano: Plano) -> [Violacao] {
        var erros: [Violacao] = []
        var corridaAnterior: Double?
        for semana in plano.semanas {
            let ocupados = semana.dias.indices.filter { semana.dias[$0] != nil }
            if ocupados.count > 3 { erros.append(.inicianteSessoesDemais(semana: semana.numero)) }
            if GeradorPlano.temDiasSeguidos(ocupados) { erros.append(.inicianteDiasSeguidos(semana: semana.numero)) }
            let corrida = semana.sessoes.map(minutosCorrendo).max() ?? 0
            if let anterior = corridaAnterior, anterior > 0, !cabe(corrida, em: anterior * 1.25) {
                erros.append(.inicianteSaltoDeCorrida(semana: semana.numero))
            }
            corridaAnterior = corrida
        }
        return erros
    }

    /// Minutos correndo numa sessão de caminhada e corrida (trechos de trabalho por tempo).
    static func minutosCorrendo(_ s: SessaoPlanejada) -> Double {
        s.treino.passosExpandidos.reduce(0) { total, passo in
            guard passo.funcao == .trabalho, passo.intensidade != .caminhada, case let .tempo(t) = passo.medida else { return total }
            return total + t / 60
        }
    }
}
