import CrunningCore
import SwiftData
import SwiftUI

struct HistoricoView: View {
    @Query(sort: \Corrida.inicio, order: .reverse) var corridas: [Corrida]
    @Environment(\.modelContext) var contexto
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage(Preferencias.modoDesenvolvimento) var modoDesenvolvimento = false
    @State var arquivosExportados: [URL] = []

    var body: some View {
        NavigationStack {
            Tela(
                selo: corridas.count == 1 ? L("1 corrida", "1 run") : L("\(corridas.count) corridas", "\(corridas.count) runs"),
                iconeSelo: "clock.arrow.circlepath",
                titulo: L("Histórico", "History")
            ) {
                if corridas.isEmpty {
                    cartaoVazio
                        .entradaCascata(2)
                } else {
                    CartaoRecordes(corridas: corridas)
                        .entradaCascata(2)
                    ForEach(corridas) { corrida in
                        NavigationLink(value: corrida) {
                            LinhaCorrida(corrida: corrida, unidade: unidade)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Apagar corrida", systemImage: "trash", role: .destructive) {
                                contexto.delete(corrida)
                                try? contexto.save()
                            }
                        }
                    }
                }
                if !corridas.isEmpty {
                    if arquivosExportados.isEmpty {
                        Button("Preparar exportação de todas (TCX)", systemImage: "square.and.arrow.up.on.square") {
                            arquivosExportados = Exportacao.todas(corridas)
                        }
                        .buttonStyle(.glass)
                        .padding(.top, 8)
                    } else {
                        ShareLink(items: arquivosExportados) {
                            Label("Exportar \(arquivosExportados.count) arquivos TCX", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.glass)
                        .padding(.top, 8)
                    }
                }
                if modoDesenvolvimento {
                    Button("Gerar corrida de exemplo", systemImage: "wand.and.stars") {
                        contexto.insert(Corrida.deExemplo())
                        try? contexto.save()
                    }
                    .buttonStyle(.glass)
                    .padding(.top, 8)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Corrida.self) { corrida in
                DetalheCorridaView(corrida: corrida)
            }
        }
    }

    private var cartaoVazio: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "figure.run.circle")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            Text("Nenhuma corrida ainda")
                .font(.title3.weight(.semibold))
            Text("Suas corridas aparecem aqui, com mapa, parciais e gráficos. Para testar a tela agora, ligue o modo de desenvolvimento em Ajustes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }
}

struct LinhaCorrida: View {
    let corrida: Corrida
    let unidade: UnidadeDistancia

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(TipoTreino.facil.cor)
                .frame(width: 6, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(corrida.titulo)
                    .font(.headline)
                Text(corrida.inicio.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatador.distancia(corrida.distanciaMetros, unidade: unidade))
                    .font(.headline)
                    .monospacedDigit()
                Text(Formatador.ritmo(segundosPorKm: corrida.ritmoMedioSegundosPorKm, unidade: unidade) + " " + unidade.siglaRitmo)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .cartaoVidro(raio: 22)
        .accessibilityElement(children: .combine)
    }
}
