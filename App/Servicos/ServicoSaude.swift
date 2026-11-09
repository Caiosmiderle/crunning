import CrunningCore
import Foundation
import HealthKit

/// Em que modo o app está em relação ao Apple Saúde (mostrado em Ajustes).
enum DisponibilidadeSaude: Equatable, Sendable {
    /// Permissão do Saúde presente na instalação: corridas viram HKWorkout com rota (fase 7).
    case ativa
    /// Instalado com Apple ID gratuito: o perfil não traz a permissão do Saúde.
    case semPermissaoNaInstalacao
    /// Aparelho sem Apple Saúde (por exemplo, iPad).
    case aparelhoSemSaude

    var titulo: String {
        switch self {
        case .ativa: L("Gravando no Apple Saúde", "Saving to Apple Health")
        case .semPermissaoNaInstalacao: L("Histórico local + TCX/GPX", "Local history + TCX/GPX")
        case .aparelhoSemSaude: L("Saúde indisponível", "Health unavailable")
        }
    }

    var detalhe: String {
        switch self {
        case .ativa:
            L("Cada corrida concluída vira um treino no Apple Saúde, com distância, duração, energia e rota.", "Every finished run becomes a workout in Apple Health, with distance, duration, energy and route.")
        case .semPermissaoNaInstalacao:
            L("Com Apple ID gratuito, a Apple não libera o Saúde para apps instalados por fora. As corridas ficam no histórico do app e saem em TCX (distância, tempo, energia e rota; também na esteira) ou GPX para outro app.", "With a free Apple ID, Apple does not allow Health for sideloaded apps. Runs stay in the app history and can be exported as TCX (distance, time, energy and route; treadmill too) or GPX to another app.")
        case .aparelhoSemSaude:
            L("Este aparelho não tem o app Saúde. As corridas ficam no histórico do app.", "This device does not have the Health app. Runs stay in the app history.")
        }
    }
}

/// Tudo que fala com o Apple Saúde passa por aqui, para o app nunca depender dele.
protocol ServicoSaude: Sendable {
    var disponibilidade: DisponibilidadeSaude { get }
}

/// Modo atual (Apple ID gratuito, sem a permissão do Saúde no perfil).
/// A versão que grava HKWorkout entra na fase 7, se houver conta paga.
struct ServicoSaudeLocal: ServicoSaude {
    var disponibilidade: DisponibilidadeSaude {
        HKHealthStore.isHealthDataAvailable() ? .semPermissaoNaInstalacao : .aparelhoSemSaude
    }
}

enum Servicos {
    static let saude: any ServicoSaude = ServicoSaudeLocal()
}
