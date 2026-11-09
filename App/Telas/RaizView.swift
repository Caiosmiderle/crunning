import SwiftUI

enum Aba: Hashable {
    case hoje
    case plano
    case historico
    case ajustes
}

struct RaizView: View {
    @State var aba: Aba = .hoje
    @State var estado = EstadoApp.compartilhado

    var body: some View {
        ZStack {
            TabView(selection: $aba) {
                Tab("Hoje", systemImage: "figure.run", value: Aba.hoje) {
                    HojeView()
                }
                Tab("Plano", systemImage: "calendar", value: Aba.plano) {
                    PlanoView()
                }
                Tab("Histórico", systemImage: "clock.arrow.circlepath", value: Aba.historico) {
                    HistoricoView()
                }
                Tab("Ajustes", systemImage: "gearshape", value: Aba.ajustes) {
                    AjustesView()
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .accessibilityHidden(estado.gravadorAtivo != nil)

            // A corrida fica por cima das abas (e não num fullScreenCover) para aparecer
            // também quando ela já está aberta na hora em que a tela é criada: é o caso
            // da corrida retomada depois de o iOS fechar o app.
            if let gravador = estado.gravadorAtivo {
                CorridaView(gravador: gravador)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .animation(.smooth(duration: 0.35), value: estado.gravadorAtivo?.id)
        .environment(estado)
        .task { estado.restaurarCorridaPendente() }
    }
}
