import Foundation

/// Um batimento lido de uma pulseira durante a corrida.
public struct AmostraFC: Codable, Sendable, Equatable {
    /// Segundos desde o início (relógio de parede), como em `AmostraTrilha.t`.
    public var t: TimeInterval
    public var bpm: Int

    public init(t: TimeInterval, bpm: Int) {
        self.t = t
        self.bpm = bpm
    }
}

/// Frequência cardíaca vinda de uma pulseira por Bluetooth (o tipo nasce em Treino/Zonas.swift,
/// com a máxima estimada). Fica no iPhone; sai dele no TCX enviado ao Strava (ou exportado por
/// você) e, só como média e máxima por etapa, na análise pós-treino que você pede.
extension FrequenciaCardiaca {
    /// Valores fora disso são leitura ruim (pulseira solta, sem medir).
    public static let faixaValida = 30...230

    /// Código da Xiaomi nos dados de fabricante do anúncio Bluetooth (little-endian: 0x57 0x01).
    public static let codigoXiaomi: UInt16 = 0x0157

    /// Batimento no anúncio Bluetooth da Mi Band 4 a 7 com a transmissão de frequência cardíaca
    /// ligada no app oficial. Os dados de fabricante começam pelo código da empresa (2 bytes) e
    /// o batimento é o 4º byte depois dele, como lê o projeto Tnze/miband-heart-rate (branch
    /// miband-4-to-7, testado na Mi Band 6).
    public static func lerAnuncioMiBand(_ dados: [UInt8]) -> Int? {
        guard ehXiaomi(dados), dados.count >= 6 else { return nil }
        let bpm = Int(dados[5])
        return faixaValida.contains(bpm) ? bpm : nil
    }

    /// Medição do serviço de frequência cardíaca padrão do Bluetooth (característica 0x2A37):
    /// o 1º byte são as flags; com o bit 0 desligado o batimento é um byte (UInt8), com ele ligado
    /// são dois (UInt16 little-endian). Heart Rate Service 1.0, Bluetooth SIG.
    public static func lerMedicaoPadrao(_ dados: [UInt8]) -> Int? {
        guard let flags = dados.first else { return nil }
        let bpm: Int
        if flags & 0x01 == 0 {
            guard dados.count >= 2 else { return nil }
            bpm = Int(dados[1])
        } else {
            guard dados.count >= 3 else { return nil }
            bpm = Int(UInt16(dados[1]) | UInt16(dados[2]) << 8)
        }
        return faixaValida.contains(bpm) ? bpm : nil
    }

    public static func ehXiaomi(_ dados: [UInt8]) -> Bool {
        dados.count >= 2 && UInt16(dados[0]) | UInt16(dados[1]) << 8 == codigoXiaomi
    }

    public struct Resumo: Sendable, Equatable {
        public let media: Int
        public let maxima: Int
    }

    /// Média e máxima. A média pondera cada leitura pelo tempo até a próxima (no máximo 5 s),
    /// para um trecho sem leitura não pesar como se fosse um batimento só.
    public static func resumo(_ amostras: [AmostraFC]) -> Resumo? {
        let validas = amostras.filter { faixaValida.contains($0.bpm) }.sorted { $0.t < $1.t }
        guard let maxima = validas.map(\.bpm).max() else { return nil }
        var soma = 0.0
        var peso = 0.0
        for (i, a) in validas.enumerated() {
            let ate = i + 1 < validas.count ? validas[i + 1].t : a.t + 1
            let p = min(max(ate - a.t, 0), 5)
            guard p > 0 else { continue }
            soma += Double(a.bpm) * p
            peso += p
        }
        let media = peso > 0 ? Int((soma / peso).rounded()) : maxima
        return Resumo(media: media, maxima: maxima)
    }

    /// Média e máxima entre dois instantes (segundos desde o início), como num trecho do treino.
    public static func resumo(_ amostras: [AmostraFC], de t0: TimeInterval, ate t1: TimeInterval) -> Resumo? {
        resumo(amostras.filter { $0.t >= t0 && $0.t <= t1 })
    }

    /// Um ponto do gráfico de batimentos: média de uma janela de tempo. `trecho` muda depois de um
    /// buraco sem leitura, para o gráfico não ligar os dois lados com uma reta.
    public struct PontoGrafico: Sendable, Equatable, Identifiable {
        public let t: TimeInterval
        public let bpm: Double
        public let trecho: Int
        public var id: TimeInterval { t }
    }

    /// Série para o gráfico: média por janela de `janela` segundos (no meio da janela), com um
    /// trecho novo quando passam mais de `buraco` segundos sem leitura.
    public static func serieGrafico(_ amostras: [AmostraFC], janela: TimeInterval = 10, buraco: TimeInterval = 20) -> [PontoGrafico] {
        let validas = amostras.filter { faixaValida.contains($0.bpm) }.sorted { $0.t < $1.t }
        guard janela > 0 else { return [] }
        var pontos: [PontoGrafico] = []
        var trecho = 0
        var anterior: TimeInterval?
        var balde: (indice: Int, soma: Int, n: Int)?
        func fechar() {
            guard let b = balde, b.n > 0 else { return }
            pontos.append(PontoGrafico(t: (Double(b.indice) + 0.5) * janela, bpm: Double(b.soma) / Double(b.n), trecho: trecho))
            balde = nil
        }
        for a in validas {
            if let anterior, a.t - anterior > buraco {
                fechar()
                trecho += 1
            }
            anterior = a.t
            let indice = Int((a.t / janela).rounded(.down))
            if let b = balde, b.indice == indice {
                balde = (indice, b.soma + a.bpm, b.n + 1)
            } else {
                fechar()
                balde = (indice, a.bpm, 1)
            }
        }
        fechar()
        return pontos
    }

    /// Batimento mais perto do instante `t`, se houver um a no máximo `tolerancia` segundos.
    public static func valor(em t: TimeInterval, _ amostras: [AmostraFC], tolerancia: TimeInterval = 5) -> Int? {
        guard !amostras.isEmpty else { return nil }
        // Busca binária: as amostras chegam em ordem de tempo.
        var baixo = 0
        var alto = amostras.count - 1
        while baixo < alto {
            let meio = (baixo + alto) / 2
            if amostras[meio].t < t { baixo = meio + 1 } else { alto = meio }
        }
        var melhor: AmostraFC?
        for i in [baixo - 1, baixo] where amostras.indices.contains(i) {
            let a = amostras[i]
            if abs(a.t - t) <= tolerancia, melhor.map({ abs($0.t - t) > abs(a.t - t) }) ?? true { melhor = a }
        }
        return melhor?.bpm
    }
}
