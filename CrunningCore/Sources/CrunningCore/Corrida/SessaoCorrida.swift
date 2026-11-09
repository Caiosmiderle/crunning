import Foundation

/// Ajustes da gravação. Os números são escolhas de engenharia (não fisiologia),
/// calibrados para corrida a pé com o GPS do iPhone.
public struct ConfiguracaoCorrida: Codable, Sendable, Equatable {
    public var pausaAutomatica: Bool = true
    /// Parado = andou menos que `deslocamentoParada` metros em `janelaParada` segundos.
    public var janelaParada: TimeInterval = 10
    public var deslocamentoParada: Double = 5
    public var velocidadeParada: Double = 0.6
    /// Voltou a se mover = `deslocamentoRetomada` metros em `janelaRetomada` segundos, ou velocidade do GPS acima de `velocidadeRetomada`.
    public var janelaRetomada: TimeInterval = 4
    public var deslocamentoRetomada: Double = 5
    public var velocidadeRetomada: Double = 1.2
    /// Só soma distância quando sai deste raio do último ponto contado (corta o "tremido" do GPS parado).
    public var passoMinimo: Double = 2.5
    /// Ritmo atual = média dos últimos `janelaRitmo` segundos em movimento, se andou pelo menos `distanciaMinimaRitmo`.
    public var janelaRitmo: TimeInterval = 20
    public var distanciaMinimaRitmo: Double = 25
    /// Subida acumulada só conta variações maiores que isto (ruído do altímetro).
    public var limiarSubida: Double = 3

    public init(pausaAutomatica: Bool = true) {
        self.pausaAutomatica = pausaAutomatica
    }
}

public enum EstadoCorrida: String, Codable, Sendable {
    case pronta
    case correndo
    case pausadaManual
    case pausadaAuto
    case finalizada
}

/// Um ponto já contado na corrida, com os acumulados naquele instante.
public struct AmostraTrilha: Codable, Sendable, Equatable {
    /// Segundos desde o início (relógio de parede).
    public var t: TimeInterval
    public var lat: Double
    public var lon: Double
    public var alt: Double?
    /// Distância acumulada (m).
    public var d: Double
    /// Tempo em movimento acumulado (s).
    public var mov: TimeInterval
    /// Trecho: muda a cada retomada depois de pausa manual.
    public var seg: Int

    public init(t: TimeInterval, lat: Double, lon: Double, alt: Double?, d: Double, mov: TimeInterval, seg: Int) {
        self.t = t
        self.lat = lat
        self.lon = lon
        self.alt = alt
        self.d = d
        self.mov = mov
        self.seg = seg
    }
}

public enum EventoCorrida: Equatable, Sendable {
    case pausouSozinha
    case retomouSozinha
    /// Km completo, com o tempo em movimento daquele km.
    case parcial(numero: Int, duracao: TimeInterval)
}

/// Gravação de uma corrida como valor puro: recebe pontos e comandos com horário
/// explícito e calcula distância, tempos, ritmo, parciais e subida.
/// É Codable para ser salva em disco a cada poucos segundos e recuperada se o iOS fechar o app.
public struct SessaoCorrida: Codable, Sendable {
    public private(set) var estado: EstadoCorrida = .pronta
    public private(set) var inicio: Date?
    public private(set) var fim: Date?
    public private(set) var distancia: Double = 0
    public private(set) var subida: Double = 0
    public private(set) var amostras: [AmostraTrilha] = []
    /// Tempo em movimento de cada km completo.
    public private(set) var parciaisKm: [TimeInterval] = []
    public var configuracao: ConfiguracaoCorrida

    var filtro = FiltroGPS()
    var movimentoAcumulado: TimeInterval = 0
    var marcoMovimento: Date?
    var segmento = 0
    var ancora: PontoGPS?
    var recentes: [PontoGPS] = []
    var altitudeReferencia: Double?
    var movimentoNaUltimaFronteira: TimeInterval = 0

    public init(configuracao: ConfiguracaoCorrida = ConfiguracaoCorrida()) {
        self.configuracao = configuracao
    }

    // MARK: Comandos

    public mutating func iniciar(em instante: Date) {
        guard estado == .pronta else { return }
        estado = .correndo
        inicio = instante
        marcoMovimento = instante
    }

    public mutating func pausar(em instante: Date) {
        switch estado {
        case .correndo:
            acumularMovimento(ate: instante)
            estado = .pausadaManual
        case .pausadaAuto:
            estado = .pausadaManual
        default:
            break
        }
    }

    public mutating func retomar(em instante: Date) {
        guard estado == .pausadaManual else { return }
        estado = .correndo
        marcoMovimento = instante
        segmento += 1
        ancora = nil
        recentes.removeAll()
    }

    public mutating func finalizar(em instante: Date) {
        guard estado != .pronta, estado != .finalizada else { return }
        if estado == .correndo { acumularMovimento(ate: instante) }
        estado = .finalizada
        fim = instante
    }

    // MARK: Leituras

    public func tempoEmMovimento(em instante: Date) -> TimeInterval {
        guard estado == .correndo, let marco = marcoMovimento else { return movimentoAcumulado }
        return movimentoAcumulado + max(0, instante.timeIntervalSince(marco))
    }

    public func tempoTotal(em instante: Date) -> TimeInterval {
        guard let inicio else { return 0 }
        return max(0, (fim ?? instante).timeIntervalSince(inicio))
    }

    /// Segundos por km sobre o tempo em movimento (nil nos primeiros 50 m).
    public func ritmoMedio(em instante: Date) -> Double? {
        guard distancia >= 50 else { return nil }
        return tempoEmMovimento(em: instante) / distancia * 1000
    }

    /// Ritmo dos últimos segundos em movimento, em s/km (nil se parado ou sem dados).
    public func ritmoAtual(em instante: Date) -> Double? {
        guard estado == .correndo, let inicio, let ultima = amostras.last else { return nil }
        guard instante.timeIntervalSince(inicio) - ultima.t <= 10 else { return nil }
        let limite = ultima.mov - configuracao.janelaRitmo
        var base: AmostraTrilha?
        for amostra in amostras.reversed() {
            guard amostra.seg == ultima.seg else { break }
            base = amostra
            if amostra.mov <= limite { break }
        }
        guard let base else { return nil }
        let dd = ultima.d - base.d
        let dm = ultima.mov - base.mov
        guard dd >= configuracao.distanciaMinimaRitmo, dm > 0 else { return nil }
        return dm / dd * 1000
    }

    // MARK: Pontos

    /// O GPS avisou que o aparelho está parado (o iOS deixa de mandar pontos até
    /// ele voltar a se mover): pausa já, sem esperar a janela de parada.
    @discardableResult
    public mutating func marcarParado(em instante: Date) -> [EventoCorrida] {
        guard configuracao.pausaAutomatica, estado == .correndo else { return [] }
        let marco = marcoMovimento ?? instante
        acumularMovimento(ate: max(marco, instante))
        estado = .pausadaAuto
        return [.pausouSozinha]
    }

    @discardableResult
    public mutating func receber(_ ponto: PontoGPS) -> [EventoCorrida] {
        guard estado == .correndo || estado == .pausadaAuto else { return [] }
        guard filtro.avaliar(ponto) == .aceito else { return [] }

        let anterior = recentes.last
        recentes.append(ponto)
        let horizonte = max(configuracao.janelaParada, configuracao.janelaRetomada) + 5
        recentes.removeAll { ponto.instante.timeIntervalSince($0.instante) > horizonte }

        var eventos: [EventoCorrida] = []
        if configuracao.pausaAutomatica {
            if estado == .correndo, let anterior, ficouParadoSemPontos(de: anterior, ate: ponto) {
                // Buraco sem pontos com o aparelho no mesmo lugar: a pausa vale desde o último ponto.
                let marco = marcoMovimento ?? anterior.instante
                acumularMovimento(ate: max(marco, anterior.instante))
                estado = .pausadaAuto
                eventos.append(.pausouSozinha)
            } else if estado == .correndo, let inicioParada = inicioDaParada(ate: ponto) {
                // A pausa vale desde o começo da parada, não só desde a detecção.
                let marco = marcoMovimento ?? inicioParada
                acumularMovimento(ate: max(marco, inicioParada))
                estado = .pausadaAuto
                return [.pausouSozinha]
            }
            if estado == .pausadaAuto {
                guard voltouAoMovimento(ate: ponto) else { return eventos }
                estado = .correndo
                marcoMovimento = ponto.instante
                eventos.append(.retomouSozinha)
            }
        } else if estado == .pausadaAuto {
            estado = .correndo
            marcoMovimento = ponto.instante
        }

        contarDistancia(ate: ponto, eventos: &eventos)
        return eventos
    }

    // MARK: Internos

    mutating func acumularMovimento(ate instante: Date) {
        guard let marco = marcoMovimento else { return }
        movimentoAcumulado += max(0, instante.timeIntervalSince(marco))
        // Nunca anda para trás em relação ao que já foi registrado.
        movimentoAcumulado = max(movimentoAcumulado, amostras.last?.mov ?? 0)
        marcoMovimento = nil
    }

    mutating func contarDistancia(ate ponto: PontoGPS, eventos: inout [EventoCorrida]) {
        guard let inicio else { return }
        let mov = tempoEmMovimento(em: ponto.instante)
        guard let ancora else {
            self.ancora = ponto
            registrar(ponto, mov: mov, inicio: inicio)
            atualizarSubida(ponto)
            return
        }
        let passo = Geo.distancia(ancora, ponto)
        guard passo >= configuracao.passoMinimo else { return }
        let anterior = amostras.last
        distancia += passo
        self.ancora = ponto
        registrar(ponto, mov: mov, inicio: inicio)
        atualizarSubida(ponto)

        guard let anterior, distancia > anterior.d else { return }
        var km = Int(anterior.d / 1000) + 1
        while Double(km) * 1000 <= distancia {
            let fronteira = Double(km) * 1000
            let fracao = (fronteira - anterior.d) / (distancia - anterior.d)
            let movFronteira = anterior.mov + fracao * (mov - anterior.mov)
            let duracao = max(0, movFronteira - movimentoNaUltimaFronteira)
            parciaisKm.append(duracao)
            movimentoNaUltimaFronteira = movFronteira
            eventos.append(.parcial(numero: km, duracao: duracao))
            km += 1
        }
    }

    mutating func registrar(_ ponto: PontoGPS, mov: TimeInterval, inicio: Date) {
        let movMonotono = max(mov, amostras.last?.mov ?? 0)
        amostras.append(AmostraTrilha(
            t: ponto.instante.timeIntervalSince(inicio),
            lat: ponto.latitude,
            lon: ponto.longitude,
            alt: ponto.altitude,
            d: distancia,
            mov: movMonotono,
            seg: segmento
        ))
    }

    mutating func atualizarSubida(_ ponto: PontoGPS) {
        guard let altitude = ponto.altitude, (ponto.precisaoVertical ?? 0) <= 20 else { return }
        guard let referencia = altitudeReferencia else {
            altitudeReferencia = altitude
            return
        }
        if altitude - referencia >= configuracao.limiarSubida {
            subida += altitude - referencia
            altitudeReferencia = altitude
        } else if referencia - altitude >= configuracao.limiarSubida {
            altitudeReferencia = altitude
        }
    }

    /// Passaram `janelaParada` segundos ou mais sem pontos e, nesse tempo, o aparelho
    /// quase não saiu do lugar (velocidade média abaixo da de parada). Um buraco com
    /// deslocamento grande (túnel, sinal perdido correndo) não é parada.
    func ficouParadoSemPontos(de anterior: PontoGPS, ate ponto: PontoGPS) -> Bool {
        let intervalo = ponto.instante.timeIntervalSince(anterior.instante)
        guard intervalo >= configuracao.janelaParada else { return false }
        return Geo.distancia(anterior, ponto) / intervalo < configuracao.velocidadeParada
    }

    /// Se os últimos `janelaParada` segundos foram parados, devolve quando a parada começou.
    func inicioDaParada(ate ponto: PontoGPS) -> Date? {
        let janela = configuracao.janelaParada
        guard let primeiro = recentes.first(where: { ponto.instante.timeIntervalSince($0.instante) <= janela }) else {
            return nil
        }
        guard ponto.instante.timeIntervalSince(primeiro.instante) >= janela * 0.8 else { return nil }
        let velocidadeBaixa = ponto.velocidade.map { $0 < configuracao.velocidadeParada } ?? true
        guard velocidadeBaixa, Geo.distancia(primeiro, ponto) < configuracao.deslocamentoParada else { return nil }
        return primeiro.instante
    }

    func voltouAoMovimento(ate ponto: PontoGPS) -> Bool {
        if let velocidade = ponto.velocidade, velocidade >= configuracao.velocidadeRetomada { return true }
        let janela = configuracao.janelaRetomada
        guard let primeiro = recentes.first(where: { ponto.instante.timeIntervalSince($0.instante) <= janela }),
              ponto.instante.timeIntervalSince(primeiro.instante) >= janela * 0.5 else {
            return false
        }
        return Geo.distancia(primeiro, ponto) >= configuracao.deslocamentoRetomada
    }
}
