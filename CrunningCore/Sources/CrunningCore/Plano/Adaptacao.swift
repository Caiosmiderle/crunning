import Foundation

/// Situações que pedem uma decisão sobre o plano (docs/CIENCIA.md, "Adaptação do plano").
public enum Situacao: Sendable, Equatable {
    case perdeuTreino
    case ausencia(dias: Int)
    case doenca(febre: Bool, sintomasAbaixoDoPescoco: Bool)
    case provaMudou(semanasAteProva: Int)
    /// Treinos de qualidade seguidos fora da faixa de ritmo, todos para o mesmo lado.
    case foraDoRitmo(treinosSeguidos: Int, maisRapido: Bool)
    /// Corridas fáceis seguidas com esforço percebido alto.
    case esforcoAltoEmFaceis(seguidas: Int, esforco: Int)
    case dor(mudaAPassada: Bool, persiste: Bool)
}

/// O que o app propõe. Nada muda no plano sem a pessoa confirmar.
public enum Recomendacao: Sendable, Equatable {
    case seguir(String)
    case retomar(fatorInicial: Double, ritmosPorEsforco: Bool, mensagem: String)
    case parar(procurarMedico: Bool, mensagem: String)
    case opcionalLeve(String)
    case reajustarPlano(semanasAteProva: Int, mensagem: String)
    case perguntarAjusteDeRitmos(maisRapido: Bool, mensagem: String)
    case proporAlivio(String)
    case pararPorDor(String)

    public var mensagem: String {
        switch self {
        case let .seguir(m), let .opcionalLeve(m), let .proporAlivio(m), let .pararPorDor(m): m
        case let .retomar(_, _, m), let .parar(_, m), let .reajustarPlano(_, m), let .perguntarAjusteDeRitmos(_, m): m
        }
    }
}

public enum Adaptacao {
    /// Volume da primeira semana depois de uma pausa, em relação ao de antes.
    /// Depois dela, o volume sobe até 25% por semana até voltar ao que já fazia.
    public static func fatorRetomada(diasParado: Int) -> Double {
        switch diasParado {
        case ...5: 1.0
        case 6...13: 0.75
        case 14...27: 0.50
        default: 0.33
        }
    }

    public static func avaliar(_ situacao: Situacao) -> Recomendacao {
        switch situacao {
        case .perdeuTreino:
            return .seguir(L("Siga o plano. Não junte o treino perdido com outro.",
                             "Follow the plan. Don't combine the missed workout with another one."))

        case let .ausencia(dias):
            guard dias > 5 else { return .seguir(L("Até 5 dias parado: siga o plano normalmente.",
                                                   "Up to 5 days off: follow the plan as usual.")) }
            let fator = fatorRetomada(diasParado: dias)
            let porEsforco = dias >= 28
            let pct = Int((fator * 100).rounded())
            let ritmos = porEsforco ? L(" Até fazer um novo teste, corra pelo esforço, não pelo ritmo.",
                                        " Until you do a new test, run by effort, not by pace.") : ""
            return .retomar(fatorInicial: fator, ritmosPorEsforco: porEsforco,
                            mensagem: L("Volte com \(pct)% do volume de antes e suba aos poucos, até 25% por semana.\(ritmos)",
                                        "Come back with \(pct)% of your previous volume and build up gradually, up to 25% per week.\(ritmos)"))

        case let .doenca(febre, abaixo):
            if febre || abaixo {
                let medico = febre ? L(" Com febre, procure um médico.", " With a fever, see a doctor.") : ""
                return .parar(procurarMedico: febre, mensagem: L("Com sintomas abaixo do pescoço ou febre, não corra até melhorar.\(medico)",
                                                                 "With symptoms below the neck or a fever, don't run until you feel better.\(medico)"))
            }
            return .opcionalLeve(L("Só nariz e garganta: se quiser, corrida leve e curta. Pare se piorar.",
                                   "Only nose and throat: if you want, a short, easy run. Stop if it gets worse."))

        case let .provaMudou(semanas):
            return .reajustarPlano(semanasAteProva: semanas,
                                   mensagem: L("O plano é refeito para a nova data, mantendo o polimento e todas as travas.",
                                               "The plan is rebuilt for the new date, keeping the taper and all the safety limits."))

        case let .foraDoRitmo(seguidos, maisRapido):
            guard seguidos >= 3 else { return .seguir(L("Um treino fora do ritmo é normal. Siga o plano.",
                                                        "One workout off pace is normal. Follow the plan.")) }
            let lado = maisRapido ? L("mais rápidos", "faster") : L("mais lentos", "slower")
            return .perguntarAjusteDeRitmos(maisRapido: maisRapido,
                                            mensagem: L("Seus últimos \(seguidos) treinos de qualidade saíram \(lado) que a faixa. Quer ajustar os ritmos?",
                                                        "Your last \(seguidos) quality workouts were \(lado) than the target range. Want to adjust your paces?"))

        case let .esforcoAltoEmFaceis(seguidas, esforco):
            guard seguidas >= 2, esforco >= 6 else { return .seguir(L("Esforço dentro do esperado. Siga o plano.",
                                                                      "Effort as expected. Follow the plan.")) }
            return .proporAlivio(L("As últimas corridas fáceis pareceram pesadas. Que tal uma semana de alívio?",
                                   "Your last easy runs felt hard. How about a recovery week?"))

        case let .dor(mudaAPassada, persiste):
            if mudaAPassada || persiste {
                return .pararPorDor(L("Pare de correr, reduza a carga e procure um profissional. A volta é por caminhada e corrida, sem treino por cima da dor.",
                                      "Stop running, reduce the load and see a professional. Come back with walk-run sessions, never training through the pain."))
            }
            return .seguir(L("Dor leve que some no aquecimento: siga com atenção. Se mudar a passada ou persistir, pare.",
                             "Mild pain that goes away during the warm-up: keep going carefully. If it changes your stride or persists, stop."))
        }
    }
}
