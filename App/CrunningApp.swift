import SwiftData
import SwiftUI

@main
struct CrunningApp: App {
    @AppStorage(Preferencias.tema) var tema: Tema = .escuro

    var body: some Scene {
        WindowGroup {
            RaizView()
                .preferredColorScheme(tema.esquema)
        }
        .modelContainer(for: [Corrida.self])
    }
}

/// Chaves das preferências simples (UserDefaults).
enum Preferencias {
    static let tema = "tema"
    static let unidade = "unidade"
    static let modoDesenvolvimento = "modoDesenvolvimento"
}

enum Tema: String, CaseIterable, Identifiable {
    case escuro
    case claro
    case sistema

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .escuro: "Escuro"
        case .claro: "Claro"
        case .sistema: "Igual ao iPhone"
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

extension Locale {
    /// O app é todo em português; datas e números seguem pt-BR mesmo se o iPhone estiver em outro idioma.
    static let ptBR = Locale(identifier: "pt_BR")
}
