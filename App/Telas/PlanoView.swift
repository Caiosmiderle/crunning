import CrunningCore
import SwiftData
import SwiftUI

struct PlanoView: View {
    @Query var ativos: [PlanoAtivo]

    var body: some View {
        if let ativo = ativos.first {
            NavigationStack {
                PlanoAtivoView(ativo: ativo)
                    .toolbar(.hidden, for: .navigationBar)
            }
        } else {
            semPlano
        }
    }

    private var semPlano: some View {
        NavigationStack {
            Tela(selo: L("Sem plano ativo", "No active plan"), iconeSelo: "calendar", titulo: L("Plano", "Plan")) {
                faixaDaSemana
                    .entradaCascata(2)
                cartaoExplicacao
                    .entradaCascata(3)
                OpcoesDePlano()
                    .entradaCascata(3)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var faixaDaSemana: some View {
        let calendario = CalendarioTreino.padrao()
        let dias = CalendarioTreino.diasDaSemana(contendo: .now, calendario: calendario)
        return HStack(spacing: 6) {
            ForEach(dias, id: \.self) { dia in
                let ehHoje = calendario.isDateInToday(dia)
                VStack(spacing: 6) {
                    Text(dia.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(dia.formatted(.dateTime.day()))
                        .font(.system(.headline, design: .rounded))
                        .monospacedDigit()
                    Circle()
                        .fill(ehHoje ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    if ehHoje {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(ehHoje ? .isSelected : [])
            }
        }
        .padding(8)
        .cartaoVidro(raio: 24)
    }

    private var cartaoExplicacao: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Seu plano aparece aqui")
                .font(.title3.weight(.semibold))
            Text("Monte um plano na prévia abaixo, confira (e peça a análise do coach, se quiser) e toque em \"Usar este plano\". Ele vira o calendário desta aba e o treino do dia na aba Hoje.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }
}

/// Montar um plano com o coach, a prévia do motor e a legenda de cores. Aparece na aba Plano sem
/// plano e, com um plano ativo, embaixo dele ("Criar outro plano"), para nada sumir.
struct OpcoesDePlano: View {
    var comPlanoAtivo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if comPlanoAtivo {
                Text("Criar outro plano")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            NavigationLink {
                CriarPlanoCoachView()
            } label: {
                cartao(
                    icone: "bubble.left.and.text.bubble.right",
                    titulo: L("Montar o plano com o coach", "Build the plan with the coach"),
                    texto: comPlanoAtivo
                        ? L("Responda as perguntas de novo. O plano atual só é trocado se você tocar em \"Usar este plano\".", "Answer the questions again. The current plan is only replaced if you tap \"Use this plan\".")
                        : L("Responda algumas perguntas; o coach escolhe os parâmetros e o motor monta com as travas.", "Answer a few questions; the coach picks the parameters and the engine builds it within the safety limits.")
                )
            }
            .buttonStyle(.plain)
            NavigationLink {
                PreviaPlanoView()
            } label: {
                cartao(
                    icone: "wand.and.stars",
                    titulo: L("Prévia do motor de treino", "Training engine preview"),
                    texto: L("Monte um plano de teste e veja as fases, os treinos e as travas.", "Build a test plan and see the phases, the workouts and the safety limits.")
                )
            }
            .buttonStyle(.plain)
            legendaDeCores
        }
    }

    private func cartao(icone: String, titulo: String, texto: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icone)
                .font(.title2)
                .foregroundStyle(Paleta.verdeLogo)
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo)
                    .font(.headline)
                Text(texto)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
        .contentShape(Rectangle())
    }

    private var legendaDeCores: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cores dos treinos")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                ForEach(TipoTreino.allCases) { tipo in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(tipo.cor)
                            .frame(width: 22, height: 10)
                        Text(tipo.nome)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }
}
