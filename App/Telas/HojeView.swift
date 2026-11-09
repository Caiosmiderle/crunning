import CrunningCore
import SwiftData
import SwiftUI

struct HojeView: View {
    @Query(sort: \Corrida.inicio, order: .reverse) var corridas: [Corrida]
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @Environment(EstadoApp.self) var estadoApp
    @Binding var aba: Aba
    @Query var ativos: [PlanoAtivo]

    var body: some View {
        NavigationStack {
            Tela(
                selo: Self.dataDeHoje(),
                iconeSelo: "sun.max.fill",
                titulo: Self.saudacao(),
                subtitulo: nil,
                mostrarMarca: true
            ) {
                Group {
                    if let ativo = ativos.first {
                        CartoesPlanoHoje(ativo: ativo, aba: $aba)
                    } else {
                        cartaoTreinoDoDia
                    }
                }
                .entradaCascata(2)
                cartaoSemana
                    .entradaCascata(3)
                Button {
                    estadoApp.abrirCorridaLivre()
                } label: {
                    Label("Correr agora", systemImage: "figure.run")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Paleta.verdeLogo, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Abre a tela de corrida livre com GPS")
                .padding(.top, 8)
                .entradaCascata(4)
                HStack(spacing: 12) {
                    Button {
                        aba = .treinos
                    } label: {
                        Label("Treinos", systemImage: "square.stack.3d.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.glass)
                    Button {
                        estadoApp.abrirCorridaLivre(esteira: true)
                    } label: {
                        Label("Na esteira", systemImage: "figure.run.treadmill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.glass)
                    .accessibilityHint("Corrida sem GPS; a distância você digita no fim")
                }
                .entradaCascata(4)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var cartaoTreinoDoDia: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Treino de hoje", systemImage: "figure.run")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Nada planejado")
                .font(.title2.weight(.semibold))
            Text("Sem plano em uso. Monte um na aba Plano > Prévia e toque em \"Usar este plano\", ou escolha um treino em Treinos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }

    private var cartaoSemana: some View {
        let semana = corridasDaSemana
        let distancia = semana.reduce(0.0) { $0 + $1.distanciaMetros }
        let tempo = semana.reduce(0.0) { $0 + $1.duracaoEmMovimento }
        return VStack(alignment: .leading, spacing: 14) {
            Text("Esta semana")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                numero(Formatador.numero(Formatador.distanciaNaUnidade(distancia, unidade: unidade), casas: 1), legenda: unidade.sigla)
                Spacer()
                numero("\(semana.count)", legenda: semana.count == 1 ? "corrida" : "corridas")
                Spacer()
                numero(Formatador.duracao(tempo), legenda: "em movimento")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }

    private func numero(_ valor: String, legenda: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(valor)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(legenda)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var corridasDaSemana: [Corrida] {
        let inicio = CalendarioTreino.inicioDaSemana(.now)
        return corridas.filter { $0.inicio >= inicio }
    }

    static func dataDeHoje() -> String {
        let texto = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.ptBR))
        return texto.prefix(1).uppercased() + texto.dropFirst()
    }

    static func saudacao() -> String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Bom dia"
        case 12..<18: "Boa tarde"
        default: "Boa noite"
        }
    }
}
