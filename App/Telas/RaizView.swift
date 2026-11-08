import SwiftUI

enum Aba: Hashable {
    case hoje
    case plano
    case historico
    case ajustes
}

struct RaizView: View {
    @State var aba: Aba = .hoje
    @State var estado = EstadoApp()

    var body: some View {
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
        .environment(estado)
        .fullScreenCover(item: $estado.gravadorAtivo) { gravador in
            CorridaView(gravador: gravador)
                .environment(estado)
        }
        .sheet(item: $estado.sessaoParaRecuperar) { salva in
            RecuperarCorridaView(salva: salva)
                .environment(estado)
        }
        .task { estado.verificarSessaoPendente() }
    }
}
