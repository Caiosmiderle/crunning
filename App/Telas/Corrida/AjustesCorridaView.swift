import SwiftUI

/// Os avisos da corrida. Aparecem em Ajustes e no botão de ajustes da tela de corrida; a
/// corrida aberta lê de novo a cada mudança (GravadorCorrida observa as preferências).
struct ControlesAvisos: View {
    @AppStorage(Preferencias.avisoVoz) var voz = true
    @AppStorage(Preferencias.avisoBipe) var bipe = true
    @AppStorage(Preferencias.avisoContagem) var contagem = true
    @AppStorage(Preferencias.avisoRitmo) var ritmo = true
    @AppStorage(Preferencias.avisoVibracao) var vibracao = true
    @AppStorage(Preferencias.avisoParciais) var parciais = 1

    var body: some View {
        Toggle("Voz", isOn: $voz)
        Toggle("Bipe na troca de etapa", isOn: $bipe)
        Toggle("Contagem regressiva (3, 2, 1)", isOn: $contagem)
        Toggle("Avisar ritmo fora da faixa", isOn: $ritmo)
        Toggle("Vibração na troca de etapa", isOn: $vibracao)
        Picker("Parcial falada", selection: $parciais) {
            Text("Desligada").tag(0)
            Text("A cada km").tag(1)
            Text("A cada 2 km").tag(2)
            Text("A cada 5 km").tag(5)
        }
    }
}

/// Folha aberta pela engrenagem da tela de corrida: muda os avisos sem parar o treino.
struct AjustesNaCorridaView: View {
    @Environment(\.dismiss) var fechar
    @AppStorage(Preferencias.telaAcesa) var telaAcesa = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ControlesAvisos()
                    Button("Testar a voz", systemImage: "speaker.wave.2") {
                        Locutor.compartilhado.falar("Tiro 1 de 6. 400 metros, ritmo 4 e 15 por quilômetro.", interromper: true)
                    }
                } footer: {
                    Text("Vale na hora e fica salvo para as próximas corridas (é o mesmo de Ajustes > Avisos durante a corrida). Sem o bipe, a contagem regressiva continua na tela e na voz.")
                }
                Section {
                    Toggle("Manter a tela acesa", isOn: $telaAcesa)
                }
            }
            .navigationTitle("Avisos da corrida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { fechar() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
