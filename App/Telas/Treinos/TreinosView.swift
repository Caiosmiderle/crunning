import CrunningCore
import SwiftData
import SwiftUI

/// Aba Treinos: os seus treinos, os seus modelos e os prontos, com os ritmos das suas zonas.
struct TreinosView: View {
    @Query(sort: \TreinoSalvo.atualizadoEm, order: .reverse) var salvos: [TreinoSalvo]
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage(Preferencias.provaTempo) var tempoReferencia: Double = 0
    @State var criando = false

    var body: some View {
        let zonas = ZonasDoUsuario.atuais()
        let meus = salvos.filter { !$0.ehModelo }
        let modelos = salvos.filter(\.ehModelo)
        NavigationStack {
            Tela(selo: tempoReferencia > 0 ? "Ritmos pela sua prova" : "Ritmos por esforço", iconeSelo: "speedometer", titulo: "Treinos") {
                Button {
                    criando = true
                } label: {
                    Label("Novo treino", systemImage: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Paleta.verdeLogo, in: Capsule())
                }
                .buttonStyle(.plain)
                .entradaCascata(2)

                if tempoReferencia <= 0 {
                    Text("Sem prova em Ajustes > Meus ritmos, os alvos aparecem como esforço. Faça um dos testes abaixo para ter os seus ritmos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .entradaCascata(2)
                }

                if !meus.isEmpty {
                    secao("Meus treinos")
                    ForEach(meus) { salvo in
                        if let treino = salvo.treino {
                            NavigationLink {
                                DetalheTreinoView(treino: treino, porque: nil, salvo: salvo)
                            } label: {
                                CartaoTreino(treino: treino, zonas: zonas, unidade: unidade)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !modelos.isEmpty {
                    secao("Meus modelos")
                    ForEach(modelos) { salvo in
                        if let treino = salvo.treino {
                            NavigationLink {
                                DetalheTreinoView(treino: treino, porque: nil, salvo: salvo)
                            } label: {
                                CartaoTreino(treino: treino, zonas: zonas, unidade: unidade)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                secao("Prontos")
                ForEach(ModelosProntos.todos) { pronto in
                    NavigationLink {
                        DetalheTreinoView(treino: pronto.treino, porque: pronto.porque, salvo: nil)
                    } label: {
                        CartaoTreino(treino: pronto.treino, zonas: zonas, unidade: unidade)
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $criando) {
                NavigationStack {
                    ConstrutorTreinoView(salvo: nil, inicial: nil)
                }
            }
        }
    }

    private func secao(_ titulo: String) -> some View {
        Text(titulo)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }
}

/// Cartão de um treino na lista: nome, totais estimados e a linha do tempo.
struct CartaoTreino: View {
    let treino: Treino
    let zonas: Zonas?
    let unidade: UnidadeDistancia

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(treino.tipo.cor).frame(width: 10, height: 10)
                Text(treino.nome)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            Text(TextoTreino.totais(treino, zonas: zonas, unidade: unidade))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            LinhaDoTempoTreino(blocos: treino.blocos, zonas: zonas, altura: 28)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro(raio: 24)
        .contentShape(Rectangle())
    }
}
