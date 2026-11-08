import CrunningCore
import SwiftUI

struct AjustesView: View {
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage(Preferencias.tema) var tema: Tema = .escuro
    @AppStorage(Preferencias.modoDesenvolvimento) var modoDesenvolvimento = false

    var body: some View {
        let saude = Servicos.saude.disponibilidade
        NavigationStack {
            Form {
                Section("Unidades") {
                    Picker("Distância", selection: $unidade) {
                        ForEach(UnidadeDistancia.allCases) { unidade in
                            Text(unidade.nome).tag(unidade)
                        }
                    }
                }

                Section("Aparência") {
                    Picker("Tema", selection: $tema) {
                        ForEach(Tema.allCases) { tema in
                            Text(tema.nome).tag(tema)
                        }
                    }
                }

                Section {
                    LabeledContent("Modo", value: saude.titulo)
                    Text(saude.detalhe)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Apple Saúde")
                }

                Section {
                    LabeledContent("Chave da API", value: "Numa próxima versão")
                    Text("A chave fica só no Keychain do iPhone. O Coach recebe apenas dados agregados (volume, ritmos médios, esforço), nunca rota, GPS ou dados do Saúde.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Coach de IA")
                }

                Section {
                    Toggle("Modo de desenvolvimento", isOn: $modoDesenvolvimento)
                    Text("Mostra ferramentas de teste, como gerar corridas de exemplo com dados fictícios no Histórico.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Desenvolvimento")
                }

                Section {
                    LabeledContent("Versão", value: Self.versao)
                    Text("O CRUNNING não é aconselhamento médico. Em caso de dor, doença ou dúvida sobre a sua saúde, procure um profissional.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Sobre")
                }
            }
            .scrollContentBackground(.hidden)
            .background { FundoView() }
            .navigationTitle("Ajustes")
        }
    }

    static var versao: String {
        let info = Bundle.main.infoDictionary
        let versao = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(versao) (build \(build))"
    }
}
