import CrunningCore
import SwiftUI
import UniformTypeIdentifiers

struct AjustesView: View {
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage(Preferencias.tema) var tema: Tema = .escuro
    @AppStorage(Preferencias.modoDesenvolvimento) var modoDesenvolvimento = false
    @AppStorage(Preferencias.pausaAutomatica) var pausaAutomatica = true
    @AppStorage(Preferencias.telaAcesa) var telaAcesa = true
    @AppStorage(Preferencias.simularGPS) var simularGPS = false
    @AppStorage(Preferencias.velocidadeSimulacao) var velocidadeSimulacao = 10.0
    @State var importandoGPX = false
    @State var temGPXImportado = Simulacao.temGPXImportado
    @State var mensagemSimulacao: String?

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

                Section {
                    Toggle("Pausa automática", isOn: $pausaAutomatica)
                    Toggle("Manter a tela acesa", isOn: $telaAcesa)
                    Text("A pausa automática para o tempo quando você para (semáforo, por exemplo) e volta sozinha quando você anda. Com a tela acesa a bateria dura menos; com ela apagada, a gravação continua igual.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Corrida")
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
                    Text("Mostra ferramentas de teste: gerar corridas de exemplo no Histórico e simular o GPS.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if modoDesenvolvimento {
                        Toggle("Simular GPS", isOn: $simularGPS)
                        if simularGPS {
                            Picker("Velocidade", selection: $velocidadeSimulacao) {
                                Text("Tempo real").tag(1.0)
                                Text("5x").tag(5.0)
                                Text("10x").tag(10.0)
                                Text("20x").tag(20.0)
                            }
                            LabeledContent("Rota", value: temGPXImportado ? "GPX importado" : "Volta de exemplo (fictícia)")
                            Button("Importar um GPX para simular") { importandoGPX = true }
                            if temGPXImportado {
                                Button("Voltar para a rota de exemplo") {
                                    Simulacao.usarRotaDeExemplo()
                                    temGPXImportado = false
                                    mensagemSimulacao = nil
                                }
                            }
                            Text(mensagemSimulacao ?? "Com a simulação ligada, \"Correr agora\" reproduz a rota como se fosse o GPS, para testar a tela de corrida sem sair de casa. O GPS de verdade também liga (pede a permissão de localização), só para a simulação continuar com a tela bloqueada; os pontos dele não entram na corrida.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
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
            .fileImporter(isPresented: $importandoGPX, allowedContentTypes: Self.tiposGPX) { resultado in
                importarGPX(resultado)
            }
        }
    }

    static let tiposGPX: [UTType] = [UTType(filenameExtension: "gpx") ?? .xml, .xml]

    private func importarGPX(_ resultado: Result<URL, any Error>) {
        guard case let .success(url) = resultado else { return }
        let acesso = url.startAccessingSecurityScopedResource()
        defer { if acesso { url.stopAccessingSecurityScopedResource() } }
        do {
            let pontos = try Simulacao.importar(Data(contentsOf: url))
            temGPXImportado = true
            mensagemSimulacao = "Rota importada: \(pontos) pontos. Ela fica só no iPhone."
        } catch {
            mensagemSimulacao = "Esse arquivo não parece um GPX com pontos de rota."
        }
    }

    static var versao: String {
        let info = Bundle.main.infoDictionary
        let versao = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(versao) (build \(build))"
    }
}
