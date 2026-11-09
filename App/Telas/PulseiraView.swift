import CrunningCore
import SwiftUI

/// Escolher a pulseira que transmite o batimento (Mi Band 4 a 7 com a transmissão ligada).
struct PulseiraView: View {
    @State var monitor = MonitorCardiaco.compartilhado
    @AppStorage(Preferencias.usarFC) var usar = true
    @AppStorage(Preferencias.modoDesenvolvimento) var modoDesenvolvimento = false
    @AppStorage(Preferencias.pulseiraFC) var pulseiraGuardada = ""

    var body: some View {
        Form {
            Section {
                Text("No app oficial da pulseira, ligue a opção de transmitir a frequência cardíaca para outros aparelhos. Depois toque em Procurar e escolha a sua pulseira aqui.")
                Text("Se o batimento não aparecer, comece um treino na própria pulseira: algumas só transmitem durante um treino.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Como ligar")
            } footer: {
                Text("O iPhone só recebe esse sinal com o CRUNNING na tela. Na corrida, com a tela acesa (Ajustes > Corrida), o batimento aparece; com a tela bloqueada, ele para e volta quando você abre o app.")
            }
            .font(.subheadline)

            if !pulseiraGuardada.isEmpty {
                Section {
                    LabeledContent(monitor.nomePulseira ?? L("Pulseira", "Band"), value: monitor.atual().map { "\($0) bpm" } ?? L("sem sinal", "no signal"))
                        .monospacedDigit()
                    Toggle("Usar na corrida", isOn: $usar)
                    Button("Esquecer esta pulseira", role: .destructive) {
                        monitor.esquecer()
                        pulseiraGuardada = ""
                    }
                } header: {
                    Text("Pulseira escolhida")
                }
            }

            Section {
                if monitor.semPermissao {
                    Text("Sem permissão de Bluetooth. Ligue em Ajustes do iPhone > Apps > CRUNNING.")
                        .foregroundStyle(Paleta.foraForte)
                } else if !monitor.bluetoothLigado {
                    Text("Procurando… (o Bluetooth precisa estar ligado)")
                        .foregroundStyle(.secondary)
                } else if monitor.encontradas.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Procurando pulseiras Xiaomi por perto…")
                    }
                }
                ForEach(monitor.encontradas) { item in
                    Button {
                        monitor.escolher(item)
                        pulseiraGuardada = item.id.uuidString
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.nome)
                                Spacer()
                                Text(item.bpm.map { "\($0) bpm" } ?? L("sem batimento", "no heart rate"))
                                    .monospacedDigit()
                                    .foregroundStyle(item.bpm == nil ? Color.secondary : Paleta.verdeLogo)
                                if item.id.uuidString == pulseiraGuardada {
                                    Image(systemName: "checkmark")
                                }
                            }
                            if modoDesenvolvimento {
                                Text(item.bruto)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text("Por perto")
            } footer: {
                Text(modoDesenvolvimento ? L("Os bytes são os dados de fabricante do anúncio; o batimento é o 6º byte.", "The bytes are the manufacturer data of the advertisement; heart rate is the 6th byte.") : L("Toque na sua pulseira para escolher.", "Tap your band to choose it."))
            }
        }
        .navigationTitle("Frequência cardíaca")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { monitor.ligar(procura: true) }
        .onDisappear {
            // Com uma corrida aberta (minimizada), a pulseira continua sendo ouvida.
            if EstadoApp.compartilhado.gravadorAtivo == nil { monitor.desligar() } else { monitor.pararProcura() }
        }
    }
}
