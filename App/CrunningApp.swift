import CrunningCore
import SwiftData
import SwiftUI

@main
struct CrunningApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegado
    @AppStorage(Preferencias.tema) var tema: Tema = .escuro

    var body: some Scene {
        WindowGroup {
            RaizView()
                .preferredColorScheme(tema.esquema)
        }
        .modelContainer(for: [Corrida.self, TreinoSalvo.self, PlanoAtivo.self, Tenis.self])
    }
}

/// Chaves das preferências simples (UserDefaults).
enum Preferencias {
    static let tema = "tema"
    static let unidade = "unidade"
    static let modoDesenvolvimento = "modoDesenvolvimento"
    static let pausaAutomatica = "pausaAutomatica"
    static let telaAcesa = "telaAcesa"
    static let simularGPS = "simularGPS"
    static let velocidadeSimulacao = "velocidadeSimulacao"
    /// Prova de referência para os ritmos (metros e segundos; tempo 0 = sem prova).
    static let provaDistancia = "provaDistancia"
    static let provaTempo = "provaTempo"
    /// Avisos durante a corrida (fase 5).
    static let avisoVoz = "avisoVoz"
    static let avisoContagem = "avisoContagem"
    static let avisoBipe = "avisoBipe"
    static let avisoRitmo = "avisoRitmo"
    static let avisoVibracao = "avisoVibracao"
    static let avisoParciais = "avisoParciais"
    static let aquecimentoGuiado = "aquecimentoGuiado"
    /// Peso (kg) só para estimar a energia no TCX e no detalhe; fica no iPhone.
    static let pesoKg = "pesoKg"
    /// Treinos do plano no app Calendário (fase 9).
    static let sincronizarCalendario = "sincronizarCalendario"
    /// Pulseira que transmite o batimento (identificador do iOS e nome) e se usa na corrida.
    static let pulseiraFC = "pulseiraFC"
    static let nomePulseiraFC = "nomePulseiraFC"
    static let usarFC = "usarFC"
    /// Enviar cada corrida ao Strava ao salvar (com a conta conectada).
    static let stravaAutomatico = "stravaAutomatico"
    /// Idade (para estimar a FC máxima) e FC máxima medida (tem prioridade). Ficam no iPhone.
    static let idade = "idade"
    static let fcMaximaMedida = "fcMaximaMedida"
    /// Modo de desenvolvimento: o coach responde com textos fixos, sem gastar a API.
    static let simularCoach = "simularCoach"
}

enum Tema: String, CaseIterable, Identifiable {
    case escuro
    case claro
    case sistema

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .escuro: L("Escuro", "Dark")
        case .claro: L("Claro", "Light")
        case .sistema: L("Igual ao iPhone", "Same as iPhone")
        }
    }

    var esquema: ColorScheme? {
        switch self {
        case .escuro: .dark
        case .claro: .light
        case .sistema: nil
        }
    }
}

