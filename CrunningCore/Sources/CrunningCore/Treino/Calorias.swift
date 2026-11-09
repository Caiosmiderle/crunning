import Foundation

/// Energia estimada por MET × peso × horas, com o MET pela velocidade média.
/// Valores do 2024 Adult Compendium of Physical Activities (Herrmann e colegas, 2024),
/// tabelas oficiais de corrida (12xxx) e caminhada (17xxx); a velocidade de cada linha
/// é o meio da faixa em mph, convertido para km/h. Média populacional: o gasto real varia.
public enum Calorias {
    public enum Atividade: Sendable {
        case corrida
        case caminhada
    }

    /// (km/h, MET), em ordem de velocidade.
    static let corrida: [(kmh: Double, met: Double)] = [
        (6.6, 6.5),    // 12028: 4 a 4,2 mph
        (7.3, 7.8),    // 12029: 4,3 a 4,8 mph
        (8.2, 8.5),    // 12030: 5 a 5,2 mph
        (9.1, 9.0),    // 12045: 5,5 a 5,8 mph
        (9.9, 9.3),    // 12050: 6 a 6,3 mph
        (10.8, 10.5),  // 12060: 6,7 mph
        (11.3, 11.0),  // 12070: 7 mph
        (12.1, 11.8),  // 12080: 7,5 mph
        (12.9, 12.0),  // 12090: 8 mph
        (13.8, 12.5),  // 12100: 8,6 mph
        (14.5, 13.0),  // 12110: 9 mph
        (15.2, 14.8),  // 12115: 9,3 a 9,6 mph
        (16.1, 14.8),  // 12120: 10 mph
        (17.7, 16.8),  // 12130: 11 mph
        (19.3, 18.5),  // 12132: 12 mph
        (20.9, 19.8),  // 12134: 13 mph
        (22.5, 23.0),  // 12135: 14 mph
    ]

    static let caminhada: [(kmh: Double, met: Double)] = [
        (2.4, 2.3),    // 17151: menos de 2 mph
        (3.5, 2.8),    // 17152: 2 a 2,4 mph
        (4.0, 3.0),    // 17170: 2,5 mph
        (5.0, 3.8),    // 17190: 2,8 a 3,4 mph
        (6.0, 4.8),    // 17200: 3,5 a 3,9 mph
        (6.8, 5.5),    // 17220: 4 a 4,4 mph
        (7.6, 7.0),    // 17230: 4,5 a 4,9 mph
    ]

    /// MET pela velocidade, interpolado entre as linhas (preso nas pontas da tabela).
    public static func met(_ atividade: Atividade, velocidadeKmH v: Double) -> Double {
        let tabela = atividade == .corrida ? corrida : caminhada
        guard let primeira = tabela.first, let ultima = tabela.last else { return 0 }
        if v <= primeira.kmh { return primeira.met }
        if v >= ultima.kmh { return ultima.met }
        for (a, b) in zip(tabela, tabela.dropFirst()) where v <= b.kmh {
            let fracao = (v - a.kmh) / (b.kmh - a.kmh)
            return a.met + fracao * (b.met - a.met)
        }
        return ultima.met
    }

    /// Quilocalorias: MET × kg × horas.
    public static func estimar(_ atividade: Atividade, velocidadeKmH: Double, pesoKg: Double, duracaoSegundos: Double) -> Double {
        guard pesoKg > 0, duracaoSegundos > 0, velocidadeKmH > 0 else { return 0 }
        return met(atividade, velocidadeKmH: velocidadeKmH) * pesoKg * duracaoSegundos / 3600
    }
}
