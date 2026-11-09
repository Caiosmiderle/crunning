import CrunningCore
import UIKit

/// Roda em toda abertura do processo, inclusive quando o iOS reabre o app em
/// segundo plano, sem tela, para entregar localização no meio de uma corrida.
/// É aqui que a corrida pendente volta a gravar, antes de qualquer tela existir.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Idioma do iPhone (português ou inglês) para os textos do motor e números.
        Idioma.atual = Idioma.doSistema(Bundle.main.preferredLocalizations)
        Formatador.separadorDecimal = Idioma.atual == .ingles ? "." : ","
        EstadoApp.compartilhado.restaurarCorridaPendente()
        return true
    }
}
