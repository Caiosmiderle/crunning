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
        EstadoApp.compartilhado.restaurarCorridaPendente()
        return true
    }
}
