import AuthenticationServices
import SwiftUI

/// Liga o CRUNNING ao Strava com o app que você cria na sua conta. Client ID e Client Secret
/// ficam no Keychain; a autorização é feita por você, na página do Strava.
struct StravaView: View {
    @Environment(\.webAuthenticationSession) var sessaoWeb
    @AppStorage(Preferencias.stravaAutomatico) var automatico = true
    @State var clientID = ""
    @State var clientSecret = ""
    @State var temCredenciais = Strava.credenciais != nil
    @State var conectado = Strava.conectado
    @State var trabalhando = false
    @State var mensagem: String?

    var body: some View {
        Form {
            if !temCredenciais {
                Section {
                    Text("1. No computador ou no Safari, abra strava.com/settings/api e crie um app (nome: CRUNNING; site: qualquer endereço; Authorization Callback Domain: localhost).")
                    Text("2. Copie o Client ID e o Client Secret do app e cole aqui.")
                    Text("3. Toque em Conectar e autorize com a sua conta.")
                    if let url = URL(string: "https://www.strava.com/settings/api") {
                        Link("Abrir strava.com/settings/api", destination: url)
                    }
                } header: {
                    Text("Como ligar")
                } footer: {
                    Text("A API do Strava exige assinatura para criar o app. Um app novo só autentica a sua própria conta, que é o que o CRUNNING precisa.")
                }

                Section {
                    TextField("Client ID (só números)", text: $clientID)
                        .keyboardType(.numberPad)
                    SecureField("Client Secret", text: $clientSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Salvar no Keychain") {
                        Strava.salvarCredenciais(.init(clientID: idLimpo, clientSecret: segredoLimpo))
                        clientID = ""
                        clientSecret = ""
                        temCredenciais = Strava.credenciais != nil
                    }
                    .disabled(idLimpo.isEmpty || idLimpo.contains { !$0.isNumber } || segredoLimpo.isEmpty)
                } header: {
                    Text("Credenciais do seu app")
                } footer: {
                    Text("Ficam só no Keychain deste iPhone: não vão para o GitHub, para o .ipa nem para registros do app.")
                }
            } else {
                Section {
                    if conectado {
                        Label("Conectado ao Strava", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Paleta.verdeLogo)
                        Toggle("Enviar cada corrida ao salvar", isOn: $automatico)
                        Button("Desconectar", role: .destructive) {
                            trabalhando = true
                            Task {
                                await Strava.desconectar()
                                conectado = Strava.conectado
                                trabalhando = false
                            }
                        }
                    } else {
                        Button {
                            conectar()
                        } label: {
                            Label("Conectar ao Strava", systemImage: "link")
                        }
                    }
                    if trabalhando { ProgressView() }
                    if let mensagem {
                        Text(mensagem)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Conta")
                } footer: {
                    Text("O CRUNNING só envia (TCX com rota, tempo, distância e batimentos; esteira marcada como treino indoor). Ele não lê nada do Strava, e nada do Strava vai para o Coach de IA. A visibilidade da atividade segue o padrão de privacidade da sua conta no Strava. Corridas simuladas não são enviadas.")
                }

                Section {
                    Button("Trocar as credenciais", role: .destructive) {
                        Task {
                            await Strava.desconectar()
                            Strava.apagarCredenciais()
                            temCredenciais = false
                            conectado = false
                        }
                    }
                }
            }
        }
        .navigationTitle("Strava")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var idLimpo: String { clientID.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var segredoLimpo: String { clientSecret.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func conectar() {
        trabalhando = true
        mensagem = nil
        Task {
            do {
                try await Strava.conectar(com: sessaoWeb)
                mensagem = "Pronto. As próximas corridas vão para o Strava ao salvar; as antigas têm o botão Enviar ao Strava no detalhe."
            } catch let erro as ASWebAuthenticationSessionError where erro.code == .canceledLogin {
                mensagem = nil
            } catch {
                mensagem = error.localizedDescription
            }
            conectado = Strava.conectado
            trabalhando = false
        }
    }
}
