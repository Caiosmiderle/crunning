import CrunningCore
import SwiftData
import SwiftUI

/// Construtor de treino: texto rápido com pré-visualização ao vivo, linha do tempo tocável,
/// blocos que se arrastam para reordenar, atalhos para adicionar e totais estimados.
struct ConstrutorTreinoView: View {
    let salvo: TreinoSalvo?
    let inicial: Treino?
    @Environment(\.modelContext) var contexto
    @Environment(\.dismiss) var fechar
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros

    @State var nome = ""
    @State var blocos: [Bloco] = []
    @State var texto = ""
    @State var textoGerado: String?
    @State var erro: String?
    @State var ehModelo = false
    @State var editandoPasso: SelecaoPasso?
    @State var editandoRepeticao: SelecaoPasso?
    @State var carregou = false

    struct SelecaoPasso: Identifiable {
        let bloco: Int
        let passo: Int?
        var id: String { "\(bloco)-\(passo ?? -1)" }
    }

    var body: some View {
        let zonas = ZonasDoUsuario.atuais()
        Form {
            Section("Nome") {
                TextField(nomeSugerido, text: $nome)
            }

            Section {
                TextField("10min fácil + 6x(400m forte / 90s trote) + 10min fácil", text: $texto, axis: .vertical)
                    .lineLimit(2...6)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.body.monospaced())
            } header: {
                Text("Texto rápido")
            } footer: {
                if let erro {
                    Text(erro).foregroundStyle(Paleta.foraForte)
                } else {
                    Text("Use + entre os trechos e 6x(...) para repetir. Intensidades: fácil, trote, caminhada, maratona, limiar, forte, rápido, prova.")
                }
            }

            if !blocos.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        LinhaDoTempoTreino(blocos: blocos, zonas: zonas, espessura: 16, alturaToque: 44) { bloco, passo in
                            abrirEditor(bloco: bloco, passo: passo)
                        }
                        Text(TextoTreino.totais(treinoAtual, zonas: zonas, unidade: unidade))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Linha do tempo")
                } footer: {
                    Text("Toque num trecho para editar.")
                }
            }

            Section {
                ForEach(blocos.indices, id: \.self) { i in
                    linhaBloco(i, zonas: zonas)
                        .contentShape(Rectangle())
                        .onTapGesture { abrirEditor(bloco: i, passo: nil) }
                        .contextMenu {
                            Button("Duplicar", systemImage: "plus.square.on.square") {
                                blocos.insert(blocos[i], at: i + 1)
                                sincronizarTexto()
                            }
                            Button("Apagar", systemImage: "trash", role: .destructive) {
                                blocos.remove(at: i)
                                sincronizarTexto()
                            }
                        }
                }
                .onMove { origem, destino in
                    blocos.move(fromOffsets: origem, toOffset: destino)
                    sincronizarTexto()
                }
                .onDelete { indices in
                    blocos.remove(atOffsets: indices)
                    sincronizarTexto()
                }
            } header: {
                HStack {
                    Text("Blocos")
                    Spacer()
                    if !blocos.isEmpty { EditButton().font(.footnote) }
                }
            }

            Section("Adicionar") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    atalho("Aquecimento", "flame", .passo(Passo(.aquecimento, .tempo(600), .facil)))
                    atalho("Tiro", "bolt.fill", .passo(Passo(.trabalho, .distancia(400), .intervalado)))
                    atalho("Ritmo", "speedometer", .passo(Passo(.trabalho, .tempo(1200), .limiar)))
                    atalho("Recuperação", "arrow.down.heart", .passo(Passo(.recuperacao, .tempo(120), .facil)))
                    atalho("Desaquecimento", "wind", .passo(Passo(.desaquecimento, .tempo(600), .facil)))
                    atalho("Repetição", "repeat", .repetir(vezes: 4, passos: [
                        Passo(.trabalho, .distancia(400), .intervalado), Passo(.recuperacao, .tempo(90), .facil),
                    ]))
                }
                .buttonStyle(.plain)
            }

            Section {
                Toggle("Guardar em Meus modelos", isOn: $ehModelo)
            } footer: {
                Text("Modelos são bases para montar treinos parecidos (duplique e ajuste).")
            }
        }
        .scrollContentBackground(.hidden)
        .background { FundoView() }
        .navigationTitle(salvo == nil ? "Novo treino" : "Editar treino")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { fechar() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { salvar() }
                    .disabled(blocos.isEmpty)
            }
        }
        .onAppear(perform: carregar)
        .onChange(of: texto) { _, novo in interpretar(novo) }
        .sheet(item: $editandoPasso) { selecao in
            NavigationStack {
                EditorPassoView(inicial: passo(selecao) ?? Passo(.trabalho, .tempo(600), .facil), zonas: zonas) { novo in
                    trocar(selecao, por: novo)
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $editandoRepeticao) { selecao in
            if let repeticao = repeticao(selecao) {
                NavigationStack {
                    EditorRepeticaoView(vezes: repeticao.vezes, passos: repeticao.passos, zonas: zonas) { novasVezes, novosPassos in
                        guard blocos.indices.contains(selecao.bloco) else { return }
                        blocos[selecao.bloco] = .repetir(vezes: novasVezes, passos: novosPassos)
                        sincronizarTexto()
                    }
                }
            }
        }
    }

    // MARK: Partes

    private var nomeSugerido: String {
        blocos.isEmpty ? "Nome do treino" : Treino.tipoInferido(blocos).nome
    }

    private var treinoAtual: Treino {
        let nomeFinal = nome.trimmingCharacters(in: .whitespaces).isEmpty ? nomeSugerido : nome.trimmingCharacters(in: .whitespaces)
        // O modelo de origem (que marca um teste, por exemplo) só vale se os blocos não mudaram.
        let origem = (inicial?.blocos == blocos) ? inicial?.modeloID : nil
        let dose = (inicial?.blocos == blocos) ? inicial?.dose : nil
        return Treino(nome: nomeFinal, tipo: Treino.tipoInferido(blocos), blocos: blocos, modeloID: origem, dose: dose)
    }

    @ViewBuilder
    private func linhaBloco(_ i: Int, zonas: Zonas?) -> some View {
        switch blocos[i] {
        case let .passo(p):
            LinhaPasso(passo: p, zonas: zonas, unidade: unidade)
        case let .repetir(vezes, passos):
            VStack(alignment: .leading, spacing: 6) {
                Label("\(vezes) vezes", systemImage: "repeat")
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(passos.enumerated()), id: \.offset) { _, p in
                    LinhaPasso(passo: p, zonas: zonas, unidade: unidade)
                }
            }
        }
    }

    private func atalho(_ titulo: String, _ icone: String, _ bloco: Bloco) -> some View {
        Button {
            blocos.append(bloco)
            sincronizarTexto()
        } label: {
            Label(titulo, systemImage: icone)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: Ações

    private func carregar() {
        guard !carregou else { return }
        carregou = true
        if let inicial {
            nome = inicial.nome
            blocos = inicial.blocos
            ehModelo = salvo?.ehModelo ?? false
            sincronizarTexto()
        }
    }

    private func interpretar(_ novo: String) {
        guard novo != textoGerado else { return }
        switch TextoRapido.resultado(novo) {
        case let .success(lidos):
            blocos = lidos
            erro = nil
        case let .failure(e):
            erro = novo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : e.mensagem
        }
    }

    /// O texto acompanha as mudanças feitas pelos controles (sem reinterpretar).
    private func sincronizarTexto() {
        let gerado = TextoRapido.texto(blocos)
        textoGerado = gerado
        texto = gerado
        erro = nil
    }

    private func abrirEditor(bloco: Int, passo: Int?) {
        guard blocos.indices.contains(bloco) else { return }
        switch blocos[bloco] {
        case .passo:
            editandoPasso = SelecaoPasso(bloco: bloco, passo: nil)
        case .repetir:
            if let passo {
                editandoPasso = SelecaoPasso(bloco: bloco, passo: passo)
            } else {
                editandoRepeticao = SelecaoPasso(bloco: bloco, passo: nil)
            }
        }
    }

    private func passo(_ s: SelecaoPasso) -> Passo? {
        guard blocos.indices.contains(s.bloco) else { return nil }
        switch blocos[s.bloco] {
        case let .passo(p): return p
        case let .repetir(_, passos):
            guard let i = s.passo, passos.indices.contains(i) else { return nil }
            return passos[i]
        }
    }

    private func repeticao(_ s: SelecaoPasso) -> (vezes: Int, passos: [Passo])? {
        guard blocos.indices.contains(s.bloco), case let .repetir(vezes, passos) = blocos[s.bloco] else { return nil }
        return (vezes, passos)
    }

    private func trocar(_ s: SelecaoPasso, por novo: Passo) {
        guard blocos.indices.contains(s.bloco) else { return }
        switch blocos[s.bloco] {
        case .passo:
            blocos[s.bloco] = .passo(novo)
        case let .repetir(vezes, passos):
            guard let i = s.passo, passos.indices.contains(i) else { return }
            var lista = passos
            lista[i] = novo
            blocos[s.bloco] = .repetir(vezes: vezes, passos: lista)
        }
        sincronizarTexto()
    }

    private func salvar() {
        let treino = treinoAtual
        if let salvo {
            salvo.atualizar(treino)
            salvo.ehModelo = ehModelo
        } else {
            contexto.insert(TreinoSalvo(treino: treino, ehModelo: ehModelo))
        }
        try? contexto.save()
        fechar()
    }
}
