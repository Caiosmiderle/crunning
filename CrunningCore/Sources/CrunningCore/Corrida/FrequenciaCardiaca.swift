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
/// com a máxima estimada). Fica no iPhone e só sai dele no TCX enviado ao Strava (ou exportado
/// por você); nunca vai para o Coach de IA.
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
