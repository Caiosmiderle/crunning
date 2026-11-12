import Foundation

/// Volume de uma semana (segunda a domingo): o que foi corrido e o que o plano pedia.
public struct VolumeSemana: Equatable, Sendable, Identifiable {
    /// Segunda-feira da semana, à meia-noite.
    public let inicio: Date
    /// Metros corridos (0 nas semanas futuras).
    public let feito: Double
    /// Metros de treino planejados (nil sem plano naquela semana).
    public let planejado: Double?

    public var id: Date { inicio }
}

public enum VolumeSemanal {
    /// Da semana de `passadas` atrás até a de `hoje`, mais até `futuras` semanas do plano à frente.
    public static func calcular(
        corridas: [(inicio: Date, distancia: Double)], plano: [(inicio: Date, distancia: Double)],
        hoje: Date, passadas: Int = 11, futuras: Int = 4, calendario: Calendar = CalendarioTreino.padrao()
    ) -> [VolumeSemana] {
        func semana(_ d: Date) -> Date { CalendarioTreino.inicioDaSemana(d, calendario: calendario) }
        let atual = semana(hoje)
        var feito: [Date: Double] = [:]
        for c in corridas where c.distancia > 0 { feito[semana(c.inicio), default: 0] += c.distancia }
        var planejado: [Date: Double] = [:]
        for p in plano { planejado[semana(p.inicio), default: 0] += p.distancia }

        var lista: [VolumeSemana] = []
        for k in -max(0, passadas)...max(0, futuras) {
            guard let inicio = calendario.date(byAdding: .weekOfYear, value: k, to: atual) else { continue }
            let p = planejado[inicio]
            if k > 0, p == nil { continue }
            lista.append(VolumeSemana(inicio: inicio, feito: k > 0 ? 0 : (feito[inicio] ?? 0), planejado: p))
        }
        return lista
    }

    /// Volume por mês (`inicio` = dia 1 à meia-noite), de `passados` meses antes do atual até o
    /// último mês com plano. O planejado de cada semana é dividido igualmente pelos 7 dias, para a
    /// semana que atravessa a virada do mês contar nos dois.
    public static func porMes(
        corridas: [(inicio: Date, distancia: Double)], plano: [(inicio: Date, distancia: Double)],
        hoje: Date, passados: Int = 5, calendario: Calendar = CalendarioTreino.padrao()
    ) -> [VolumeSemana] {
        func mes(_ d: Date) -> Date { calendario.dateInterval(of: .month, for: d)?.start ?? calendario.startOfDay(for: d) }
        let atual = mes(hoje)
        var feito: [Date: Double] = [:]
        for c in corridas where c.distancia > 0 { feito[mes(c.inicio), default: 0] += c.distancia }
        var planejado: [Date: Double] = [:]
        for p in plano {
            let inicio = CalendarioTreino.inicioDaSemana(p.inicio, calendario: calendario)
            for d in 0..<7 {
                guard let dia = calendario.date(byAdding: .day, value: d, to: inicio) else { continue }
                planejado[mes(dia), default: 0] += p.distancia / 7
            }
        }
        let ultimo = max(atual, planejado.keys.max() ?? atual)
        var lista: [VolumeSemana] = []
        var k = -max(0, passados)
        while let inicio = calendario.date(byAdding: .month, value: k, to: atual), inicio <= ultimo {
            lista.append(VolumeSemana(inicio: inicio, feito: inicio > atual ? 0 : (feito[inicio] ?? 0), planejado: planejado[inicio]))
            k += 1
        }
        return lista
    }

    /// Distância feita em cada dia (segunda a domingo) da semana de `hoje`.
    public static func porDia(corridas: [(inicio: Date, distancia: Double)], hoje: Date,
                              calendario: Calendar = CalendarioTreino.padrao()) -> [Double] {
        let inicio = CalendarioTreino.inicioDaSemana(hoje, calendario: calendario)
        var dias = Array(repeating: 0.0, count: 7)
        for c in corridas where c.distancia > 0 {
            guard let d = calendario.dateComponents([.day], from: inicio, to: calendario.startOfDay(for: c.inicio)).day,
                  (0..<7).contains(d) else { continue }
            dias[d] += c.distancia
        }
        return dias
    }

    /// Média das `n` semanas completas antes da semana de `hoje`.
    public static func media(_ semanas: [VolumeSemana], ultimas n: Int, hoje: Date,
                             calendario: Calendar = CalendarioTreino.padrao()) -> Double {
        let atual = CalendarioTreino.inicioDaSemana(hoje, calendario: calendario)
        let completas = semanas.filter { $0.inicio < atual }.suffix(max(1, n))
        guard !completas.isEmpty else { return 0 }
        return completas.reduce(0) { $0 + $1.feito } / Double(completas.count)
    }

    /// Variação da última semana completa sobre a anterior (0,12 = +12%); nil se a anterior foi zero.
    public static func variacao(_ semanas: [VolumeSemana], hoje: Date,
                                calendario: Calendar = CalendarioTreino.padrao()) -> Double? {
        let atual = CalendarioTreino.inicioDaSemana(hoje, calendario: calendario)
        let completas = semanas.filter { $0.inicio < atual }
        guard completas.count >= 2 else { return nil }
        let ultima = completas[completas.count - 1].feito, anterior = completas[completas.count - 2].feito
        guard anterior > 0 else { return nil }
        return (ultima - anterior) / anterior
    }
}
