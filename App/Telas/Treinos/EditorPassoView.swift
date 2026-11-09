import CrunningCore
import SwiftUI

/// Folha de um trecho, com controles grandes: parte do treino, tempo ou distância e intensidade
/// (com o ritmo das suas zonas ao lado).
struct EditorPassoView: View {
    let inicial: Passo
    let zonas: Zonas?
    var aoSalvar: (Passo) -> Void
    @Environment(\.dismiss) var fechar
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros

    @State var funcao: FuncaoPasso = .trabalho
    @State var porTempo = true
    @State var horas = 0
    @State var minutos = 10
    @State var segundos = 0
    @State var quilometros = 0
    @State var metros = 400
    @State var intensidade: Intensidade = .facil
    @State var carregou = false

    static let funcoes: [(FuncaoPasso, String)] = [
        (.aquecimento, L("Aquecer", "Warm up")), (.trabalho, L("Trabalho", "Work")), (.recuperacao, L("Pausa", "Recovery")), (.desaquecimento, L("Desaquecer", "Cool down")),
    ]

    var body: some View {
        Form {
            Section("Parte do treino") {
                Picker("Parte", selection: $funcao) {
                    ForEach(Self.funcoes, id: \.0) { Text($0.1).tag($0.0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Quanto") {
                Picker("Medida", selection: $porTempo) {
                    Text("Tempo").tag(true)
                    Text("Distância").tag(false)
                }
                .pickerStyle(.segmented)
                if porTempo {
                    HStack(spacing: 0) {
                        roda($horas, valores: Array(0...5), sufixo: "h")
                        roda($minutos, valores: Array(0...59), sufixo: "min")
                        roda($segundos, valores: Array(stride(from: 0, through: 55, by: 5)), sufixo: "s")
                    }
                    .frame(height: 150)
                } else {
                    HStack(spacing: 0) {
                        roda($quilometros, valores: Array(0...42), sufixo: "km")
                        roda($metros, valores: Array(stride(from: 0, through: 950, by: 50)), sufixo: "m")
                    }
                    .frame(height: 150)
                }
            }

            Section {
                ForEach(Intensidade.allCases) { i in
                    Button {
                        intensidade = i
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(Passo(funcao, medida, i).tipoParaCor.cor).frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(i.nome).font(.body.weight(.medium)).foregroundStyle(Color.primary)
                                Text(TextoTreino.alvo(Passo(funcao, medida, i), zonas: zonas, unidade: unidade))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if intensidade == i {
                                Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(Paleta.verdeLogo)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(intensidade == i ? .isSelected : [])
                }
            } header: {
                Text("Intensidade")
            } footer: {
                Text(zonas == nil ? L("Sem prova em Meus ritmos: o alvo vai por esforço (0 a 10).", "No race in My paces: the target goes by effort (0 to 10).") : L("Ritmos calculados pela sua prova de referência.", "Paces calculated from your reference race."))
            }
        }
        .scrollContentBackground(.hidden)
        .background { FundoView() }
        .navigationTitle(EtapaExecucao.nome(Passo(funcao, medida, intensidade)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { fechar() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") {
                    aoSalvar(Passo(funcao, medida, intensidade))
                    fechar()
                }
                .disabled(valorMedida <= 0)
            }
        }
        .onAppear(perform: carregar)
    }

    private var valorMedida: Double {
        porTempo ? Double(horas * 3600 + minutos * 60 + segundos) : Double(quilometros * 1000 + metros)
    }

    private var medida: Medida {
        porTempo ? .tempo(max(1, valorMedida)) : .distancia(max(1, valorMedida))
    }

    private func roda(_ valor: Binding<Int>, valores: [Int], sufixo: String) -> some View {
        Picker(sufixo, selection: valor) {
            ForEach(valores, id: \.self) { Text("\($0) \(sufixo)").tag($0) }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func carregar() {
        guard !carregou else { return }
        carregou = true
        funcao = inicial.funcao
        intensidade = inicial.intensidade
        switch inicial.medida {
        case let .tempo(t):
            porTempo = true
            let total = Int(t.rounded())
            horas = min(5, total / 3600)
            minutos = (total % 3600) / 60
            segundos = (total % 60) / 5 * 5
        case let .distancia(d):
            porTempo = false
            let total = Int(d.rounded())
            quilometros = min(42, total / 1000)
            metros = (total % 1000) / 50 * 50
        }
    }
}

/// Folha de uma repetição: quantas vezes e os trechos que se repetem.
struct EditorRepeticaoView: View {
    let vezes: Int
    let passos: [Passo]
    let zonas: Zonas?
    var aoSalvar: (Int, [Passo]) -> Void
    @Environment(\.dismiss) var fechar
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros

    @State var quantas = 4
    @State var lista: [Passo] = []
    @State var editando: Int?
    @State var carregou = false

    var body: some View {
        Form {
            Section {
                Stepper("\(quantas) vezes", value: $quantas, in: 1...30)
                    .font(.title3.weight(.semibold))
            }
            Section {
                ForEach(lista.indices, id: \.self) { i in
                    LinhaPasso(passo: lista[i], zonas: zonas, unidade: unidade)
                        .contentShape(Rectangle())
                        .onTapGesture { editando = i }
                }
                .onMove { lista.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { lista.remove(atOffsets: $0) }
                Button("Adicionar trecho", systemImage: "plus") {
                    lista.append(Passo(.recuperacao, .tempo(60), .facil))
                }
            } header: {
                HStack {
                    Text("Trechos que se repetem")
                    Spacer()
                    EditButton().font(.footnote)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { FundoView() }
        .navigationTitle("Repetição")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { fechar() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") {
                    aoSalvar(quantas, lista)
                    fechar()
                }
                .disabled(lista.isEmpty)
            }
        }
        .sheet(item: Binding(
            get: { editando.map { IndiceEditado(id: $0) } },
            set: { editando = $0?.id }
        )) { item in
            NavigationStack {
                EditorPassoView(inicial: lista.indices.contains(item.id) ? lista[item.id] : Passo(.trabalho, .tempo(60), .facil), zonas: zonas) { novo in
                    if lista.indices.contains(item.id) { lista[item.id] = novo }
                }
            }
        }
        .onAppear {
            guard !carregou else { return }
            carregou = true
            quantas = vezes
            lista = passos
        }
    }

    struct IndiceEditado: Identifiable {
        let id: Int
    }
}
