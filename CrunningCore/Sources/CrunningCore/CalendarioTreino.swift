import Foundation

/// Semana de treino: começa na segunda, como em planilhas de corrida.
public enum CalendarioTreino {
    public static func padrao(fuso: TimeZone = .current) -> Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.locale = Locale(identifier: "pt_BR")
        calendario.timeZone = fuso
        calendario.firstWeekday = 2
        calendario.minimumDaysInFirstWeek = 4
        return calendario
    }

    /// Meia-noite da segunda-feira da semana que contém `data`.
    public static func inicioDaSemana(_ data: Date, calendario: Calendar = padrao()) -> Date {
        calendario.dateInterval(of: .weekOfYear, for: data)?.start ?? calendario.startOfDay(for: data)
    }

    /// Os 7 dias (segunda a domingo, à meia-noite) da semana que contém `data`.
    public static func diasDaSemana(contendo data: Date, calendario: Calendar = padrao()) -> [Date] {
        let inicio = inicioDaSemana(data, calendario: calendario)
        return (0..<7).compactMap { calendario.date(byAdding: .day, value: $0, to: inicio) }
    }
}
