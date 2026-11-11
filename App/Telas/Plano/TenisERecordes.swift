import CrunningCore
import SwiftData
import SwiftUI

/// Tênis e quilometragem de cada um (Ajustes > Tênis).
struct TenisView: View {
    @Query(sort: \Tenis.criadoEm) var tenis: [Tenis]
    @Query var corridas: [Corrida]
    @Environment(\.modelContext) var contexto
    @AppStorage(PreferenciasPlano.tenisPrincipal) var principal = ""
    @State var novoNome = ""
    @State var novoKm: Double?

    var body: some View {
        Form {
            Section {
                TextField("Nome do tênis novo", text: $novoNome)
                HStack {
                    TextField(L("Km que ele já tem (opcional)", "Km it already has (optional)"), value: $novoKm, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                    Button("Adicionar") {
                        let nome = novoNome.trimmingCharacters(in: .whitespaces)
                        guard !nome.isEmpty else { return }
                        let novo = Tenis(nome: nome, kmIniciais: novoKm ?? 0)
                        contexto.insert(novo)
                        try? contexto.save()
                        // O primeiro tênis vira o principal sozinho.
                        if PreferenciasPlano.principal == nil { principal = novo.codigo }
                        novoNome = ""
                        novoKm = nil
                    }
                    .disabled(novoNome.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Se o tênis já tinha uso antes do app, informe os km dele: entram na soma e no aviso de troca. Toda corrida usa o tênis principal. Se um dia correr com outro, troque no resumo da corrida ou depois, no detalhe dela no Histórico. O aviso de troca usa o limite que você definir (muita gente usa algo entre 500 e 800 km; não há um número com base científica).")
            }
            ForEach(tenis) { t in
                let noApp = corridas.filter { $0.tenis == t.codigo }.reduce(0) { $0 + $1.distanciaMetros } / 1000
                let km = t.kmIniciais + noApp
                Section {
                    Toggle("Tênis principal", isOn: Binding(
                        get: { principal == t.codigo || (principal.isEmpty && PreferenciasPlano.principal == t.codigo) },
                        set: { principal = $0 ? t.codigo : "" }
                    ))
                    LabeledContent("Rodados", value: Formatador.numero(km, casas: 1) + " km")
                    LabeledContent(L("Antes do app", "Before the app")) {
                        TextField("0", value: Binding(get: { t.kmIniciais }, set: { t.kmIniciais = max(0, $0) }),
                                  format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                        Text("km").foregroundStyle(.secondary)
                    }
                    if t.kmIniciais > 0 {
                        LabeledContent(L("Com o CRUNNING", "With CRUNNING"), value: Formatador.numero(noApp, casas: 1) + " km")
                            .foregroundStyle(.secondary)
                    }
                    Stepper("Avisar com \(Int(t.limiteKm)) km", value: Binding(get: { t.limiteKm }, set: { t.limiteKm = $0 }), in: 0...2000, step: 50)
                    if t.limiteKm > 0, km >= t.limiteKm {
                        Label("Passou do limite que você definiu", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Paleta.foraLeve)
                    }
                    Toggle("Aposentado", isOn: Binding(get: { t.aposentado }, set: { novo in
                        t.aposentado = novo
                        if novo, PreferenciasPlano.principal == t.codigo { principal = "" }
                    }))
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

/// Tênis da corrida (resumo e detalhe): já vem o principal; trocar vale só para esta corrida.
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
                        Text(r.data.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits)))
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
