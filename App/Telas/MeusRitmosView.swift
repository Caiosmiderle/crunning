import CrunningCore
import SwiftUI

/// Prova de referência → VDOT, faixas de ritmo e tempos previstos (docs/CIENCIA.md, "Ritmos").
struct MeusRitmosView: View {
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage(Preferencias.provaDistancia) var distancia: Double = 5000
    @AppStorage(Preferencias.provaTempo) var tempo: Double = 0
    @AppStorage(Preferencias.idade) var idade = 0
    @AppStorage(Preferencias.fcMaximaMedida) var fcMedida = 0
    @State var horas = 0
    @State var minutos = 0
    @State var segundos = 0

    struct Distancia: Hashable {
        let nome: String
        let metros: Double
    }

    static let distancias: [Distancia] = [
        Distancia(nome: "3 km", metros: 3000), Distancia(nome: "5 km", metros: 5000),
        Distancia(nome: "10 km", metros: 10_000), Distancia(nome: "15 km", metros: 15_000),
        Distancia(nome: "Meia maratona", metros: 21_097.5), Distancia(nome: "Maratona", metros: 42_195),
    ]
    static let previsoes: [Distancia] = [
        Distancia(nome: "5 km", metros: 5000), Distancia(nome: "10 km", metros: 10_000),
        Distancia(nome: "Meia maratona", metros: 21_097.5), Distancia(nome: "Maratona", metros: 42_195),
    ]
    static let intensidades: [Intensidade] = [.facil, .maratona, .limiar, .intervalado, .repeticoes]

    var zonas: Zonas? {
        tempo > 0 ? Zonas(distanciaMetros: distancia, tempoSegundos: tempo) : nil
    }

    var body: some View {
        Form {
            Section {
                Picker("Distância", selection: $distancia) {
                    ForEach(Self.distancias, id: \.metros) { Text($0.nome).tag($0.metros) }
                }
                HStack(spacing: 4) {
                    Text("Tempo")
                    Spacer()
                    seletor($horas, ate: 6, sufixo: "h")
                    seletor($minutos, ate: 59, sufixo: "min")
                    seletor($segundos, ate: 59, sufixo: "s")
                }
                if tempo > 0 {
                    Button("Apagar a prova de referência", role: .destructive) {
                        horas = 0; minutos = 0; segundos = 0
                    }
                }
            } header: {
                Text("Prova recente")
            } footer: {
                Text("Uma prova ou um teste forte das últimas 6 semanas. Os ritmos de todos os treinos saem daqui.")
            }

            Section {
                LabeledContent("Idade") {
                    TextField("anos", value: $idade, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("FC máxima medida") {
                    TextField("bpm (opcional)", value: $fcMedida, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                if let fc = ZonasDoUsuario.fcMaxima() {
                    LabeledContent("FC máxima usada", value: "\(Int(fc.valor.rounded())) bpm" + (fc.estimada ? " (estimada)" : ""))
                    ForEach([Intensidade.caminhada, .facil, .maratona, .limiar, .intervalado]) { intensidade in
                        if let zona = FrequenciaCardiaca.zona(intensidade, fcMaxima: fc.valor) {
                            LabeledContent(intensidade == .caminhada ? "Caminhada e recuperação" : intensidade.nome, value: zona.texto)
                                .monospacedDigit()
                        }
                    }
                }
            } header: {
                Text("Frequência cardíaca")
            } footer: {
                Text("Com a idade, a FC máxima é estimada por 208 − 0,7 × idade (Tanaka e colegas, 2001), com erro de cerca de 10 bpm; se você souber a sua, de um teste ou de uma prova forte, informe e ela vale no lugar. Zonas de Daniels em % da FC máxima: fácil 65–79%, maratona 80–90%, limiar 88–92%, intervalado 98–100%. Tiros curtos e repetições vão pelo ritmo: o batimento demora a subir. Fica só no iPhone.")
            }

            if tempo > 0, zonas == nil {
                Section {
                    Text("Esse tempo está fora da faixa em que o cálculo funciona. Confira a distância e o tempo.")
                        .foregroundStyle(.secondary)
                }
            }

            if let zonas {
                Section {
                    LabeledContent("VDOT", value: Formatador.numero(zonas.vdot, casas: 1))
                } footer: {
                    Text("Índice de Daniels e Gilbert: estima o que a prova diz do seu condicionamento. Não é o VO2máx de laboratório.")
                }

                Section {
                    ForEach(Self.intensidades) { intensidade in
                        linhaRitmo(intensidade, faixa: zonas.faixa(intensidade))
                    }
                } header: {
                    Text("Seus ritmos")
                } footer: {
                    Text("No fácil, comece pelo lado mais lento da faixa. Faixas de Daniels; fontes em CIENCIA.md.")
                }

                Section {
                    ForEach(Self.previsoes, id: \.metros) { prova in
                        let previsto = zonas.tempoPrevisto(distanciaMetros: prova.metros)
                        let riegel = Riegel.tempo(referenciaSegundos: tempo, distanciaReferencia: distancia, distanciaAlvo: prova.metros)
                        LabeledContent(prova.nome) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Formatador.duracao(previsto)).monospacedDigit()
                                Text("Riegel: " + Formatador.duracao(riegel))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                } header: {
                    Text("Tempos previstos")
                } footer: {
                    Text("Previsão pelo VDOT. A de Riegel aparece só para comparar: em corredores recreativos ela costuma ser otimista na maratona.")
                }
            } else {
                Section {
                    ForEach(Self.intensidades) { intensidade in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(intensidade.nome).font(.body.weight(.medium))
                                Spacer()
                                Text("esforço \(intensidade.esforco.lowerBound) a \(intensidade.esforco.upperBound)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(intensidade.testeDaFala)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Sem prova: pelo esforço")
                } footer: {
                    Text("Esforço percebido de 0 a 10 e teste da fala. Quando tiver uma prova ou um teste, informe acima.")
                }
            }
        }
        .navigationTitle("Meus ritmos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let total = Int(tempo.rounded())
            horas = total / 3600
            minutos = total % 3600 / 60
            segundos = total % 60
        }
        .onChange(of: horas) { atualizarTempo() }
        .onChange(of: minutos) { atualizarTempo() }
        .onChange(of: segundos) { atualizarTempo() }
    }

    private func atualizarTempo() {
        tempo = Double(horas * 3600 + minutos * 60 + segundos)
    }

    private func seletor(_ valor: Binding<Int>, ate maximo: Int, sufixo: String) -> some View {
        Picker(sufixo, selection: valor) {
            ForEach(0...maximo, id: \.self) { Text("\($0) \(sufixo)").tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    private func linhaRitmo(_ intensidade: Intensidade, faixa: FaixaRitmo) -> some View {
        HStack {
            Circle()
                .fill(cor(intensidade))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(intensidade.nome).font(.body.weight(.medium))
                Text(intensidade.testeDaFala)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(textoFaixa(faixa))
                .font(.body.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }

    private func textoFaixa(_ faixa: FaixaRitmo) -> String {
        let lento = Formatador.ritmo(segundosPorKm: faixa.lento, unidade: unidade)
        let rapido = Formatador.ritmo(segundosPorKm: faixa.rapido, unidade: unidade)
        return lento == rapido ? lento + " " + unidade.siglaRitmo : "\(lento) a \(rapido) \(unidade.siglaRitmo)"
    }

    private func cor(_ intensidade: Intensidade) -> Color {
        switch intensidade {
        case .caminhada: TipoTreino.caminhada.cor
        case .facil: TipoTreino.facil.cor
        case .maratona, .prova: TipoTreino.ritmoProva.cor
        case .limiar: TipoTreino.limiar.cor
        case .intervalado: TipoTreino.intervalado.cor
        case .repeticoes: TipoTreino.repeticoes.cor
        }
    }
}
