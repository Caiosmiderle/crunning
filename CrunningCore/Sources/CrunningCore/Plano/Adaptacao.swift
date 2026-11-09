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
            return .seguir("Siga o plano. Não junte o treino perdido com outro.")

        case let .ausencia(dias):
            guard dias > 5 else { return .seguir("Até 5 dias parado: siga o plano normalmente.") }
            let fator = fatorRetomada(diasParado: dias)
            let porEsforco = dias >= 28
            let pct = Int((fator * 100).rounded())
            let ritmos = porEsforco ? " Até fazer um novo teste, corra pelo esforço, não pelo ritmo." : ""
            return .retomar(fatorInicial: fator, ritmosPorEsforco: porEsforco,
                            mensagem: "Volte com \(pct)% do volume de antes e suba aos poucos, até 25% por semana.\(ritmos)")

        case let .doenca(febre, abaixo):
            if febre || abaixo {
                let medico = febre ? " Com febre, procure um médico." : ""
                return .parar(procurarMedico: febre, mensagem: "Com sintomas abaixo do pescoço ou febre, não corra até melhorar.\(medico)")
            }
            return .opcionalLeve("Só nariz e garganta: se quiser, corrida leve e curta. Pare se piorar.")

        case let .provaMudou(semanas):
            return .reajustarPlano(semanasAteProva: semanas,
                                   mensagem: "O plano é refeito para a nova data, mantendo o polimento e todas as travas.")

        case let .foraDoRitmo(seguidos, maisRapido):
            guard seguidos >= 3 else { return .seguir("Um treino fora do ritmo é normal. Siga o plano.") }
            let lado = maisRapido ? "mais rápidos" : "mais lentos"
            return .perguntarAjusteDeRitmos(maisRapido: maisRapido,
                                            mensagem: "Seus últimos \(seguidos) treinos de qualidade saíram \(lado) que a faixa. Quer ajustar os ritmos?")

        case let .esforcoAltoEmFaceis(seguidas, esforco):
            guard seguidas >= 2, esforco >= 6 else { return .seguir("Esforço dentro do esperado. Siga o plano.") }
            return .proporAlivio("As últimas corridas fáceis pareceram pesadas. Que tal uma semana de alívio?")

        case let .dor(mudaAPassada, persiste):
            if mudaAPassada || persiste {
                return .pararPorDor("Pare de correr, reduza a carga e procure um profissional. A volta é por caminhada e corrida, sem treino por cima da dor.")
            }
            return .seguir("Dor leve que some no aquecimento: siga com atenção. Se mudar a passada ou persistir, pare.")
        }
    }
}
