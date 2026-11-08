import CrunningCore
import SwiftData
import SwiftUI

struct HistoricoView: View {
    @Query(sort: \Corrida.inicio, order: .reverse) var corridas: [Corrida]
    @Environment(\.modelContext) var contexto
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage(Preferencias.modoDesenvolvimento) var modoDesenvolvimento = false

    var body: some View {
        NavigationStack {
            Tela(
                selo: corridas.count == 1 ? "1 corrida" : "\(corridas.count) corridas",
                iconeSelo: "clock.arrow.circlepath",
                titulo: "Histórico"
            ) {
                if corridas.isEmpty {
                    cartaoVazio
                        .entradaCascata(2)
                } else {
                    ForEach(corridas) { corrida in
                        LinhaCorrida(corrida: corrida, unidade: unidade)
                            .contextMenu {
                                Button("Apagar corrida", systemImage: "trash", role: .destructive) {
                                    contexto.delete(corrida)
                                }
                            }
                    }
                }
                if modoDesenvolvimento {
                    Button("Gerar corrida de exemplo", systemImage: "wand.and.stars") {
                        contexto.insert(Corrida.deExemplo())
                    }
                    .buttonStyle(.glass)
                    .padding(.top, 8)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
                Text(corrida.inicio.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(.ptBR)))
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
