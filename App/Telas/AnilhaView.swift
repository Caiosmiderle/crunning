import CrunningCore
import SwiftUI

/// Ajustes > Conexões > Anilha: colar o token gerado no Anilha, ver o estado e desconectar.
struct AnilhaView: View {
    @State var texto = ""
    @State var conectado = Anilha.conectado
    @State var mensagem: String?
    @State var enviando = false
    @State var pendentes = 0
    @AppStorage(Anilha.Chaves.ultimoEnvio) var ultimoEnvio: Double = 0
    @AppStorage(Anilha.Chaves.ultimoErro) var ultimoErro: String = ""
    @AppStorage(Preferencias.modoDesenvolvimento) var modoDesenvolvimento = false
    @AppStorage(Anilha.Chaves.endereco) var endereco = ""

    var body: some View {
        Form {
            Section {
                Text("O Anilha usa as suas corridas e os treinos dos próximos 14 dias para ajustar a musculação, por exemplo, sugerir mudar o treino de perna antes de um longão. Ele sempre pergunta antes de mudar.")
                    .font(.subheadline)
                Label("Vão só resumos: dia, tipo, distância, tempo, esforço e o dia do plano. Nunca rota, GPS, batimentos, nome ou o que você escreve.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if conectado {
                Section("Estado") {
                    LabeledContent("Conexão", value: L("ativa", "active"))
                    LabeledContent("Último envio", value: ultimoEnvio > 0 ? Date(timeIntervalSince1970: ultimoEnvio).formatted(.dateTime.day().month().hour().minute()) : "—")
                    LabeledContent("Na fila", value: "\(pendentes)")
                    if !ultimoErro.isEmpty {
                        Text(ultimoErro).font(.caption).foregroundStyle(Paleta.foraForte)
                    }
                    Button {
                        Task { await enviar() }
                    } label: {
                        HStack {
                            Text("Enviar agora")
                            if enviando { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(enviando)
                    Button("Mandar as corridas dos últimos 90 dias") {
                        Task {
                            enviando = true
                            await EnvioAnilha.enfileirarRecentes()
                            enviando = false
                            pendentes = EnvioAnilha.pendentes
                        }
                    }
                    .disabled(enviando)
                }
                Section {
                    Button("Desconectar", role: .destructive) {
                        Anilha.desconectar()
                        ForcaAnilha.shared.limpar()
                        conectado = false
                        mensagem = L("Desconectado. O que já foi para o Anilha continua lá; para apagar, revogue o token no Anilha e apague as corridas lá.", "Disconnected. What already went to Anilha stays there; to remove it, revoke the token in Anilha and delete the runs there.")
                    }
                } footer: {
                    Text("Para cortar do lado do Anilha, revogue o token em Você > Conexões > CRUNNING.")
                }
            } else {
                Section {
                    SecureField("anl_…", text: $texto)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                    Button("Conectar") {
                        if Anilha.salvarToken(texto) {
                            texto = ""
                            conectado = true
                            mensagem = L("Conectado. As próximas corridas vão sozinhas; dá para mandar as dos últimos 90 dias abaixo.", "Connected. Next runs go on their own; you can send the last 90 days below.")
                            Task { await enviar() }
                        } else {
                            mensagem = L("Isso não parece um token do Anilha (começa com anl_).", "That doesn't look like an Anilha token (it starts with anl_).")
                        }
                    }
                    .disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Token do Anilha")
                } footer: {
                    Text("No Anilha: Você > Conexões > CRUNNING > Gerar token. Ele aparece uma vez só; copie e cole aqui. Fica só no Keychain deste iPhone.")
                }
            }

            if let mensagem {
                Section { Text(mensagem).font(.footnote) }
            }

            if modoDesenvolvimento {
                Section {
                    TextField(Anilha.enderecoPadrao, text: $endereco)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.caption.monospaced())
                } header: {
                    Text("Endereço (desenvolvimento)")
                } footer: {
                    Text("Vazio usa o Anilha publicado. Serve para testar contra o servidor local do Anilha na mesma rede.")
                }
            }
        }
        .navigationTitle("Anilha")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { pendentes = EnvioAnilha.pendentes }
    }

    private func enviar() async {
        enviando = true
        await EnvioAnilha.processar()
        enviando = false
        pendentes = EnvioAnilha.pendentes
    }
}
