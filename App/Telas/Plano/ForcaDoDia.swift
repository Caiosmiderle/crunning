import CrunningCore
import SwiftUI

/// O treino de força do Anilha num dia do plano: feito (halter cheio) ou previsto (halter vazado),
/// com a marca "perna" quando teve membros inferiores. Sem conexão com o Anilha, não aparece.
struct ForcaDoDia: View {
    let data: Date

    static let corPerna = Color.orange

    var body: some View {
        let dia = ForcaAnilha.shared.doDia(data)
        if !dia.feitas.isEmpty || !dia.planejadas.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(dia.feitas) { s in
                    linha(s.nome ?? L("Treino de força", "Strength workout"), feito: true,
                          pernas: s.pernas == true, estado: s.status == "parcial" ? L("parcial", "partial") : L("feito", "done"))
                }
                ForEach(Array(dia.planejadas.enumerated()), id: \.offset) { _, p in
                    linha(p.nome, feito: false, pernas: p.pernas, estado: L("previsto", "planned"))
                }
            }
        }
    }

    private func linha(_ nome: String, feito: Bool, pernas: Bool, estado: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: feito ? "dumbbell.fill" : "dumbbell")
                .foregroundStyle(pernas ? AnyShapeStyle(Self.corPerna) : AnyShapeStyle(.secondary))
            Text(nome).lineLimit(1)
            if pernas {
                Text(L("perna", "legs"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Self.corPerna)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Self.corPerna.opacity(0.15), in: Capsule())
            }
            Spacer(minLength: 4)
            Text(estado)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Anilha: ", "Anilha: ") + nome + (pernas ? L(", com perna", ", with legs") : "") + ", " + estado)
    }

    /// Resumo para a grade do mês e a faixa da semana.
    struct Marca {
        var feita = false
        var prevista = false
        var pernas = false

        static let nenhuma = Marca()

        var icone: String? { feita ? "dumbbell.fill" : (prevista ? "dumbbell" : nil) }

        var rotulo: String {
            guard feita || prevista else { return "" }
            return (feita ? L(", força feita no Anilha", ", strength done in Anilha") : L(", força prevista no Anilha", ", strength planned in Anilha"))
                + (pernas ? L(" (perna)", " (legs)") : "")
        }
    }

    @MainActor
    static func marca(_ data: Date) -> Marca {
        let dia = ForcaAnilha.shared.doDia(data)
        return Marca(feita: !dia.feitas.isEmpty, prevista: !dia.planejadas.isEmpty,
                     pernas: dia.feitas.contains { $0.pernas == true } || dia.planejadas.contains { $0.pernas })
    }
}
