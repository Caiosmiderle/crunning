import Foundation

/// O que saiu do plano numa semana. Decide se vale sugerir a revisão do Coach de IA: com a semana
/// dentro do plano, o app só diz isso e não chama a IA (nem gasta a sua chave).
public struct DesvioSemana: Equatable, Sendable {
    /// Sessões de dias já passados que não foram feitas (perdidas ou sem registro).
    public var perdidas = 0
    /// Corridas gravadas na semana que não cumpriram nenhuma sessão do plano.
    public var foraDoPlano = 0
    /// Corridas fáceis do plano com esforço percebido 6 ou mais (o mesmo corte de `Adaptacao`).
    public var esforcoAltoEmFaceis = 0
    /// Treinos de qualidade com o ritmo fora da faixa (`Adaptacao.ladoDoRitmo`).
    public var ritmoFora = 0

    public init() {}

    public var temDesvio: Bool { perdidas + foraDoPlano + esforcoAltoEmFaceis + ritmoFora > 0 }

    public var motivos: [String] {
        var lista: [String] = []
        func plural(_ n: Int, _ um: String, _ varios: String) -> String { n == 1 ? "1 \(um)" : "\(n) \(varios)" }
        if perdidas > 0 {
            lista.append(plural(perdidas, L("treino perdido", "missed workout"), L("treinos perdidos", "missed workouts")))
        }
        if foraDoPlano > 0 {
            lista.append(plural(foraDoPlano, L("corrida fora do plano", "run outside the plan"), L("corridas fora do plano", "runs outside the plan")))
        }
        if esforcoAltoEmFaceis > 0 {
            lista.append(L("esforço alto em ", "high effort in ")
                         + plural(esforcoAltoEmFaceis, L("corrida fácil", "easy run"), L("corridas fáceis", "easy runs")))
        }
        if ritmoFora > 0 {
            lista.append(L("ritmo fora da faixa em ", "pace off target in ")
                         + plural(ritmoFora, L("treino forte", "hard workout"), L("treinos fortes", "hard workouts")))
        }
        return lista
    }
}

extension AgendaPlano {
    /// Semana a revisar: no domingo, a semana que está acabando; na segunda, a que acabou.
    public func semanaParaRevisar(hoje: Date, calendario: Calendar = CalendarioTreino.padrao()) -> Int? {
        guard let p = posicao(de: hoje, calendario: calendario) else {
            // Depois do último dia: revisa a última semana.
            return hoje > fim ? plano.semanas.count : nil
        }
        if p.dia == 0 { return p.semana > 1 ? p.semana - 1 : nil }
        return p.semana
    }

    /// Desvios da semana. As corridas vêm de fora (o histórico mora no app): quantas foram fora
    /// do plano e, para cada treino de qualidade feito, para que lado o ritmo saiu.
    public func desvios(semana: Int, hoje: Date, corridasForaDoPlano: Int, ladosDoRitmo: [Bool?],
                        calendario: Calendar = CalendarioTreino.padrao()) -> DesvioSemana {
        var d = DesvioSemana()
        d.foraDoPlano = max(0, corridasForaDoPlano)
        d.ritmoFora = ladosDoRitmo.filter { $0 != nil }.count
        let inicioDeHoje = calendario.startOfDay(for: hoje)
        for dia in 0..<7 {
            guard let s = sessao(semana: semana, dia: dia) else { continue }
            let estado = status(semana: semana, dia: dia)
            if data(semana: semana, dia: dia, calendario: calendario) < inicioDeHoje, estado != .feita {
                d.perdidas += 1
            }
            if !s.ehForte, estado == .feita, let e = esforcos[Self.chave(semana, dia)], e >= 6 {
                d.esforcoAltoEmFaceis += 1
            }
        }
        return d
    }
}
