import CrunningCore
import SwiftUI

struct PlanoView: View {
    var body: some View {
        NavigationStack {
            Tela(selo: "Sem plano ativo", iconeSelo: "calendar", titulo: "Plano") {
                faixaDaSemana
                    .entradaCascata(2)
                cartaoExplicacao
                    .entradaCascata(3)
                NavigationLink {
                    PreviaPlanoView()
                } label: {
                    cartaoPrevia
                }
                .buttonStyle(.plain)
                .entradaCascata(3)
                legendaDeCores
                    .entradaCascata(4)
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
                    Text(dia.formatted(.dateTime.weekday(.narrow).locale(.ptBR)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(dia.formatted(.dateTime.day().locale(.ptBR)))
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
            Text("O calendário com o plano até a prova chega numa próxima versão. O motor que monta o plano já está pronto: veja uma prévia abaixo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }

    private var cartaoPrevia: some View {
        HStack(spacing: 14) {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundStyle(Paleta.verdeLogo)
            VStack(alignment: .leading, spacing: 4) {
                Text("Prévia do motor de treino")
                    .font(.headline)
                Text("Monte um plano de teste e veja as fases, os treinos e as travas.")
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
