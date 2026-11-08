import CrunningCore
import SwiftData
import SwiftUI

/// Fim da corrida: números, mapa, parciais, esforço percebido, e salvar ou descartar.
struct ResumoCorridaView: View {
    let gravador: GravadorCorrida
    @Environment(EstadoApp.self) var estadoApp
    @Environment(\.modelContext) var contexto
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @State var esforco: Int?
    @State var confirmandoDescarte = false

    var body: some View {
        let sessao = gravador.sessao
        let fim = sessao.fim ?? gravador.agora
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Selo(texto: gravador.simulada ? "Simulação" : "Corrida livre", icone: "checkmark.circle.fill")
                    Text("Corrida concluída")
                        .font(.system(.largeTitle, design: .default, weight: .light))
                        .tracking(-0.8)

                    Grid(horizontalSpacing: 16, verticalSpacing: 14) {
                        GridRow {
                            Metrica(titulo: "Distância", valor: Formatador.distancia(sessao.distancia, unidade: unidade))
                            Metrica(titulo: "Tempo em movimento", valor: Formatador.duracao(sessao.tempoEmMovimento(em: fim)))
                        }
                        GridRow {
                            Metrica(titulo: "Ritmo médio", valor: sessao.ritmoMedio(em: fim).map { Formatador.ritmo(segundosPorKm: $0, unidade: unidade) + " " + unidade.siglaRitmo } ?? "--:--")
                            Metrica(titulo: "Subida", valor: "\(Int(sessao.subida.rounded())) m")
                        }
                    }
                    .padding(20)
                    .cartaoVidro()

                    if sessao.amostras.count >= 2 {
                        MapaTrilha(amostras: sessao.amostras)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    let parciais = Parciais.calcular(sessao.amostras, comprimento: unidade.metros)
                    if !parciais.isEmpty {
                        ListaParciais(parciais: parciais, unidade: unidade)
                            .padding(20)
                            .cartaoVidro()
                    }

                    SeletorEsforco(valor: $esforco)
                        .padding(20)
                        .cartaoVidro()

                    Button {
                        gravador.salvar(em: contexto, esforco: esforco)
                        estadoApp.gravadorAtivo = nil
                    } label: {
                        Text("Salvar corrida")
                            .font(.headline)
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Paleta.verdeLogo, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Button("Descartar", role: .destructive) {
                        confirmandoDescarte = true
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .background { FundoView() }
            .confirmationDialog("Descartar esta corrida?", isPresented: $confirmandoDescarte, titleVisibility: .visible) {
                Button("Descartar corrida", role: .destructive) {
                    gravador.descartar()
                    estadoApp.gravadorAtivo = nil
                }
            } message: {
                Text("Ela não vai para o histórico e não dá para desfazer.")
            }
        }
    }
}

/// Ao abrir o app, se ficou uma corrida sem salvar (o iOS fechou o app no meio).
struct RecuperarCorridaView: View {
    let salva: SessaoSalva
    @Environment(EstadoApp.self) var estadoApp
    @Environment(\.modelContext) var contexto
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros

    var body: some View {
        let sessao = salva.sessao
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Paleta.verdeLogo)
            Text("Corrida não terminada")
                .font(.title2.weight(.semibold))
            Text("O app foi fechado no meio de uma corrida de \(Formatador.distancia(sessao.distancia, unidade: unidade)) e \(Formatador.duracao(sessao.tempoEmMovimento(em: salva.salvaEm))) em movimento.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !salva.simulada && sessao.estado != .finalizada {
                Button {
                    estadoApp.continuar(salva)
                } label: {
                    Text("Continuar a corrida")
                        .font(.headline)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Paleta.verdeLogo, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Button {
                estadoApp.salvarComoEsta(salva, em: contexto)
            } label: {
                Text("Salvar como está")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.glass)
            Button("Descartar", role: .destructive) {
                estadoApp.descartarRecuperacao()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
