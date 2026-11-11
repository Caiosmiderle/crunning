import CrunningCore
import SwiftData
import SwiftUI

/// Análise pós-treino do treinador de IA, no detalhe da corrida. Só chama a API quando você toca
/// no botão; a resposta fica salva na corrida, com o custo que a API informou.
struct CartaoAnaliseTreino: View {
    let corrida: Corrida
    @Environment(\.modelContext) var contexto
    @State var salva: AnaliseSalva?
    @State var trabalhando = false
    @State var erro: String?

    init(corrida: Corrida) {
        self.corrida = corrida
        _salva = State(initialValue: corrida.carregarAnalise())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(L("Análise do treinador", "Coach's analysis"), systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                if let salva, !trabalhando { selo(salva.analise.execucao) }
            }

            if trabalhando {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L("Analisando o treino…", "Analyzing the workout…"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let salva {
                conteudo(salva)
            } else {
                convite
            }

            if let erro {
                Text(erro)
                    .font(.caption)
                    .foregroundStyle(Paleta.foraForte)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Partes

    @ViewBuilder
    private var convite: some View {
        if Chaveiro.temChave || ClienteClaude.simulado {
            Button(L("Analisar este treino", "Analyze this workout"), systemImage: "sparkles") { analisar() }
                .buttonStyle(.glass)
            Text(L("Usa o Claude Opus 5.5 com a sua chave: alguns centavos de dólar por análise, e o custo exato aparece aqui depois. Vão só dados agregados (etapas, tempos, pace, batimentos e esforço), nunca a rota.",
                   "Uses Claude Opus 5.5 with your key: a few US cents per analysis, and the exact cost shows here afterwards. Only aggregated data is sent (steps, times, pace, heart rate and effort), never the route."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(L("Salve a sua chave da API em Ajustes > Coach de IA para pedir a análise deste treino.",
                   "Save your API key in Settings > AI Coach to ask for an analysis of this workout."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func conteudo(_ salva: AnaliseSalva) -> some View {
        let a = salva.analise
        return VStack(alignment: .leading, spacing: 14) {
            Text(a.resumo)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if !a.positivos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(a.positivos, id: \.self) { p in
                        Label {
                            Text(p).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Paleta.verdeLogo)
                        }
                    }
                }
            }

            if !a.ajustes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("O que ajustar", "What to adjust"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(a.ajustes, id: \.self) { ajuste in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ajuste.oQueAconteceu)
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Label {
                                Text(ajuste.comoFazer).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("Na próxima vez", "Next time"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(a.proximaVez)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text(rodape(salva))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if Chaveiro.temChave || ClienteClaude.simulado {
                    Button(L("Refazer", "Redo")) { analisar() }
                        .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private func selo(_ execucao: String) -> some View {
        let (texto, cor): (String, Color) = switch execucao {
        case "boa": (L("No plano", "On plan"), Paleta.verdeLogo)
        case "fora_do_plano": (L("Fora do plano", "Off plan"), Paleta.foraForte)
        default: (L("Quase no plano", "Close to plan"), Paleta.foraLeve)
        }
        return Text(texto)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(cor.opacity(0.18), in: Capsule())
            .foregroundStyle(cor)
    }

    /// "Claude Opus 5.5 · 1.512 tokens de entrada + 1.843 de saída · US$ 0,0429".
    private func rodape(_ salva: AnaliseSalva) -> String {
        if salva.simulada { return L("Resposta simulada (sem gastar a API).", "Simulated reply (no API spend).") }
        guard let uso = salva.uso else { return "" }
        var partes = [uso.nomeModelo,
                      L("\(uso.entrada.formatted()) tokens de entrada + \(uso.saida.formatted()) de saída",
                        "\(uso.entrada.formatted()) input tokens + \(uso.saida.formatted()) output")]
        if let custo = uso.custoUSD {
            partes.append((uso.comFallback ? "≈ " : "") + "US$ " + Formatador.numero(custo, casas: custo < 0.01 ? 4 : 3))
        }
        return partes.joined(separator: " · ")
    }

    private func analisar() {
        trabalhando = true
        erro = nil
        Task {
            do {
                salva = try await AnaliseTreinoIA.analisar(corrida, em: contexto)
            } catch {
                erro = error.localizedDescription
            }
            trabalhando = false
        }
    }
}
