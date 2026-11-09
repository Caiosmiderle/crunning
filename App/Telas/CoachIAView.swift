import SwiftUI

/// Onde a chave da API da Anthropic é colada e guardada no Keychain.
struct CoachIAView: View {
    @State var chave = ""
    @State var salva = Chaveiro.temChave
    @State var falhou = false

    var body: some View {
        Form {
            Section {
                if salva {
                    Label("Chave salva neste iPhone", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Paleta.verdeLogo)
                    Button("Apagar a chave", role: .destructive) {
                        Chaveiro.apagar()
                        salva = false
                    }
                } else {
                    SecureField("sk-ant-...", text: $chave)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                    Button("Salvar no Keychain") {
                        let limpa = chave.trimmingCharacters(in: .whitespacesAndNewlines)
                        if Chaveiro.salvar(limpa) {
                            chave = ""
                            salva = true
                            falhou = false
                        } else {
                            falhou = true
                        }
                    }
                    .disabled(chave.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if falhou {
                        Text("Não deu para salvar no Keychain. Tente de novo.")
                            .foregroundStyle(Paleta.foraForte)
                    }
                }
            } header: {
                Text("Chave da API da Anthropic")
            } footer: {
                Text("Crie a chave em console.anthropic.com, de preferência com um limite de gasto. Ela fica só no Keychain deste iPhone: não vai para o GitHub, para o .ipa nem para registros do app.")
            }

            Section("O que é enviado") {
                Text("Só o resumo do plano: objetivo, semanas, nível, volumes e os treinos de cada dia. Nunca rota, GPS, nome ou dados do Saúde.")
                Text("Cada análise usa o Claude Sonnet 5.5 e custa poucos centavos de dólar na sua conta da Anthropic.")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .navigationTitle("Coach de IA")
        .navigationBarTitleDisplayMode(.inline)
    }
}
