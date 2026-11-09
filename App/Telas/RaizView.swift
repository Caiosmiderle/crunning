import SwiftUI

enum Aba: Hashable {
    case hoje
    case treinos
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
                    HojeView(aba: $aba)
                }
                Tab("Treinos", systemImage: "square.stack.3d.up", value: Aba.treinos) {
                    TreinosView()
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
            .modifier(AcessorioCorrida(estado: estado))
            .accessibilityHidden(estado.gravadorAtivo != nil && !estado.corridaMinimizada)

            // A corrida fica por cima das abas (e não num fullScreenCover) para aparecer
            // também quando ela já está aberta na hora em que a tela é criada: é o caso
            // da corrida retomada depois de o iOS fechar o app. Minimizada, ela vira a
            // barra acima das abas (AcessorioCorrida) e continua gravando.
            if let gravador = estado.gravadorAtivo, !estado.corridaMinimizada {
                CorridaView(gravador: gravador)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .animation(.smooth(duration: 0.35), value: estado.gravadorAtivo?.id)
        .animation(.smooth(duration: 0.35), value: estado.corridaMinimizada)
        .environment(estado)
        .task { estado.restaurarCorridaPendente() }
    }
}
