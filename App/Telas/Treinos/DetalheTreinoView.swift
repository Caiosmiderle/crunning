import CrunningCore
import SwiftData
import SwiftUI

/// Um treino antes de começar: linha do tempo, blocos com os seus ritmos, o porquê,
/// opções (esteira, aquecimento guiado) e o botão de começar.
struct DetalheTreinoView: View {
    let treino: Treino
    let porque: String?
    let salvo: TreinoSalvo?
    @Environment(EstadoApp.self) var estadoApp
    @Environment(\.modelContext) var contexto
    @Environment(\.dismiss) var fechar
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage(Preferencias.aquecimentoGuiado) var aquecimentoPadrao = true
    @State var esteira = false
    @State var aquecimentoGuiado: Bool?
    @State var editando = false
    @State var confirmandoApagar = false
    @State var mensagem: String?

    /// O salvo pode ter sido editado depois de a tela abrir.
    private var atual: Treino { salvo?.treino ?? treino }

    var body: some View {
        let treino = atual
        let zonas = ZonasDoUsuario.atuais()
        let rotina = ExecucaoTreino.rotinaIndicada(para: treino)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Selo(texto: treino.tipo.nome, icone: "figure.run")
                Text(treino.nome)
                    .font(.system(.largeTitle, design: .default, weight: .light))
                    .tracking(-0.8)
                Text(TextoTreino.totais(treino, zonas: zonas, unidade: unidade))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)

                LinhaDoTempoTreino(blocos: treino.blocos, zonas: zonas)
                    .padding(18)
                    .cartaoVidro(raio: 24)

                ListaBlocos(blocos: treino.blocos, zonas: zonas, unidade: unidade)
                    .padding(18)
                    .cartaoVidro(raio: 24)

                if let porque {
                    Text(porque)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cartaoVidro(raio: 24)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Na esteira", isOn: $esteira)
                    if esteira {
                        Text("Sem GPS: trechos por distância viram tempo pelo seu ritmo-alvo, e a distância total você digita no fim.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let rotina {
                        Toggle("Aquecimento guiado", isOn: Binding(
                            get: { aquecimentoGuiado ?? aquecimentoPadrao },
                            set: { aquecimentoGuiado = $0 }
                        ))
                        Text("\(rotina.nome), cerca de \(Int((rotina.duracaoEstimada / 60).rounded())) min: mobilidade dinâmica, educativos e acelerações depois do trote, com voz e cronômetro. \(Aquecimento.completa.porque)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
                .cartaoVidro(raio: 24)

                if let mensagem {
                    Label(mensagem, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.verdeLogo)
                }

                Button {
                    estadoApp.abrirTreino(treino, esteira: esteira, aquecimentoGuiado: rotina == nil ? false : (aquecimentoGuiado ?? aquecimentoPadrao))
                } label: {
                    Label("Começar", systemImage: "play.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Paleta.verdeLogo, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { FundoView() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let salvo {
                        Button("Editar", systemImage: "pencil") { editando = true }
                        Button("Duplicar", systemImage: "plus.square.on.square") { duplicar() }
                        Button(salvo.ehModelo ? "Tirar dos modelos" : "Salvar como modelo", systemImage: "square.stack.3d.up") {
                            salvo.ehModelo.toggle()
                            try? contexto.save()
                            mensagem = salvo.ehModelo ? "Agora está em Meus modelos." : "Saiu de Meus modelos."
                        }
                        Button("Apagar", systemImage: "trash", role: .destructive) { confirmandoApagar = true }
                    } else {
                        Button("Salvar nos meus treinos", systemImage: "square.and.arrow.down") { salvarCopia(modelo: false) }
                        Button("Salvar como modelo", systemImage: "square.stack.3d.up") { salvarCopia(modelo: true) }
                        Button("Salvar e editar", systemImage: "pencil") { editando = true }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Opções do treino")
            }
        }
        .sheet(isPresented: $editando) {
            NavigationStack {
                ConstrutorTreinoView(salvo: salvo, inicial: atual)
            }
        }
        .confirmationDialog("Apagar este treino?", isPresented: $confirmandoApagar, titleVisibility: .visible) {
            Button("Apagar treino", role: .destructive) {
                if let salvo {
                    contexto.delete(salvo)
                    try? contexto.save()
                }
                fechar()
            }
        } message: {
            Text("As corridas já feitas com ele continuam no histórico.")
        }
    }

    private func duplicar() {
        var copia = atual
        copia.nome = atual.nome + " (cópia)"
        contexto.insert(TreinoSalvo(treino: copia, ehModelo: salvo?.ehModelo ?? false))
        try? contexto.save()
        mensagem = "Cópia criada em Meus treinos."
    }

    private func salvarCopia(modelo: Bool) {
        contexto.insert(TreinoSalvo(treino: atual, ehModelo: modelo))
        try? contexto.save()
        mensagem = modelo ? "Salvo em Meus modelos." : "Salvo em Meus treinos."
    }
}
