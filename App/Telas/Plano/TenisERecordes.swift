import CrunningCore
import SwiftData
import SwiftUI

/// Tênis e quilometragem de cada um (Ajustes > Tênis).
struct TenisView: View {
    @Query(sort: \Tenis.criadoEm) var tenis: [Tenis]
    @Query var corridas: [Corrida]
    @Environment(\.modelContext) var contexto
    @State var novoNome = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Nome do tênis novo", text: $novoNome)
                    Button("Adicionar") {
                        let nome = novoNome.trimmingCharacters(in: .whitespaces)
                        guard !nome.isEmpty else { return }
                        contexto.insert(Tenis(nome: nome))
                        try? contexto.save()
                        novoNome = ""
                    }
                    .disabled(novoNome.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("No fim de cada corrida você escolhe o tênis. O aviso de troca usa o limite que você definir (muita gente usa algo entre 500 e 800 km; não há um número com base científica).")
            }
            ForEach(tenis) { t in
                let km = corridas.filter { $0.tenis == t.codigo }.reduce(0) { $0 + $1.distanciaMetros } / 1000
                Section {
                    LabeledContent("Rodados", value: Formatador.numero(km, casas: 1) + " km")
                    Stepper("Avisar com \(Int(t.limiteKm)) km", value: Binding(get: { t.limiteKm }, set: { t.limiteKm = $0 }), in: 0...2000, step: 50)
                    if t.limiteKm > 0, km >= t.limiteKm {
                        Label("Passou do limite que você definiu", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Paleta.foraLeve)
                    }
                    Toggle("Aposentado", isOn: Binding(get: { t.aposentado }, set: { t.aposentado = $0 }))
                } header: {
                    Text(t.nome)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { FundoView() }
        .navigationTitle("Tênis")
    }
}

/// Escolha do tênis no resumo da corrida.
struct SeletorTenis: View {
    @Binding var codigo: String?
    @Query(filter: #Predicate<Tenis> { !$0.aposentado }, sort: \Tenis.criadoEm) var tenis: [Tenis]

    var body: some View {
        if !tenis.isEmpty {
            Picker("Tênis", selection: $codigo) {
                Text("Nenhum").tag(String?.none)
                ForEach(tenis) { t in Text(t.nome).tag(Optional(t.codigo)) }
            }
            .pickerStyle(.menu)
        }
    }
}

/// Melhores tempos em 1 km, 5 km, 10 km, meia e maratona, achados dentro de qualquer corrida.
struct CartaoRecordes: View {
    let corridas: [Corrida]
    @State var melhores: [(nome: String, tempo: TimeInterval, data: Date)] = []
    @State var calculado = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recordes pessoais", systemImage: "trophy")
                .font(.headline)
            if !calculado {
                ProgressView()
            } else if melhores.isEmpty {
                Text("Aparecem quando houver corridas com GPS de pelo menos 1 km.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(melhores, id: \.nome) { r in
                    HStack {
                        Text(r.nome).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(Formatador.duracao(r.tempo)).font(.subheadline.monospacedDigit().weight(.semibold))
                        Text(r.data.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits).locale(.ptBR)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
                Text("Pelo tempo em movimento, em qualquer trecho de qualquer corrida (corridas de exemplo e simuladas ficam de fora).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
        .task(id: corridas.count) { calcular() }
    }

    private func calcular() {
        var lista: [(nome: String, tempo: TimeInterval, data: Date)] = []
        let validas = corridas.filter { !$0.exemplo && !$0.simulada && !$0.esteira && $0.distanciaMetros >= 1000 }
        let trilhas = validas.map { ($0.inicio, $0.carregarAmostras()) }
        for (nome, metros) in Recordes.distancias {
            var melhor: (TimeInterval, Date)?
            for (data, amostras) in trilhas {
                if let t = Recordes.melhorTempo(amostras, distancia: metros), melhor.map({ t < $0.0 }) ?? true { melhor = (t, data) }
            }
            if let melhor { lista.append((nome, melhor.0, melhor.1)) }
        }
        melhores = lista
        calculado = true
    }
}
