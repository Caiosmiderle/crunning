import CrunningCore
import SwiftUI

/// Sugestão de aquecimento para os treinos fortes, mostrada antes de começar (no detalhe do treino
/// e na tela de corrida, antes de deslizar). Fica fora do relógio: tempo, distância e ritmo do
/// treino só contam a partir do início. O trote leve do começo do treino completa o aquecimento.
struct SugestaoAquecimento: View {
    let rotina: RotinaAquecimento
    @State var aberto: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Antes de começar", systemImage: "figure.flexibility")
                .font(.headline)
            Text("\(rotina.nome), cerca de \(minutos) min, fora do tempo do treino. É sugestão: faça antes de deslizar para começar. Toque num exercício para ver como fazer.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(exercicios) { e in
                DisclosureGroup(isExpanded: Binding(get: { aberto == e.id }, set: { aberto = $0 ? e.id : nil })) {
                    Text(e.comoFazer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack {
                        Text(e.nome)
                            .font(.subheadline)
                        Spacer(minLength: 8)
                        Text(Fala.medidaExercicio(e.medida))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if exercicios.contains(where: { $0.id == "aceleracoes" }) {
                Text("As acelerações rendem mais com o corpo já quente: se preferir, faça-as no fim do trote do treino.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DisclosureGroup("Por quê") {
                Text(rotina.porque + " Fontes: " + rotina.fontes.joined(separator: "; ") + ".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline)
        }
    }

    /// Sem o trote: ele é o começo do próprio treino.
    private var exercicios: [ExercicioAquecimento] {
        rotina.etapas.flatMap(\.exercicios).filter { $0.id != "trote" }
    }

    private var minutos: Int {
        max(1, Int((exercicios.reduce(0) { $0 + $1.duracaoEstimada } / 60).rounded()))
    }
}
