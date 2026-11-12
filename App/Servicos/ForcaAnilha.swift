import CrunningCore
import Foundation
import Observation

/// Treinos de força do Anilha para o calendário do plano e a semana da tela Hoje. Lê pelo mesmo
/// token da troca (`GET /forca`), só o que mudou desde a última leitura, e guarda num arquivo do
/// app. Sem token, não faz nada.
@MainActor
@Observable
final class ForcaAnilha {
    static let shared = ForcaAnilha()

    private(set) var estado = EstadoForcaAnilha()
    private(set) var erro: String?
    @ObservationIgnored private var lendo = false

    private static var arquivo: URL {
        URL.applicationSupportDirectory.appending(path: "forca-anilha.json")
    }

    private init() {
        if let dados = try? Data(contentsOf: Self.arquivo),
           let salvo = try? JSONDecoder().decode(EstadoForcaAnilha.self, from: dados) {
            estado = salvo
        }
    }

    /// Feitas e previstas de um dia, no calendário do app.
    func doDia(_ data: Date) -> (feitas: [SessaoForcaAnilha], planejadas: [ForcaPlanejadaAnilha]) {
        estado.doDia(EstadoForcaAnilha.chave(data, calendario: CalendarioTreino.padrao()))
    }

    func atualizar() async {
        guard Anilha.conectado, !lendo else { return }
        lendo = true
        defer { lendo = false }
        var consulta = [URLQueryItem(name: "versao", value: "1")]
        if let cursor = estado.cursor { consulta.append(URLQueryItem(name: "desde", value: cursor)) }
        do {
            let dados = try await Anilha.chamar("GET", caminho: "forca", corpo: nil, consulta: consulta)
            let resposta = try JSONDecoder().decode(RespostaForcaAnilha.self, from: dados)
            guard estado.aplicar(resposta) else { throw Anilha.Erro.versao }
            salvar()
            erro = nil
        } catch is DecodingError {
            erro = Anilha.Erro.resposta.errorDescription
        } catch {
            erro = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Ao desconectar: o que veio do Anilha sai do iPhone.
    func limpar() {
        estado = EstadoForcaAnilha()
        erro = nil
        try? FileManager.default.removeItem(at: Self.arquivo)
    }

    private func salvar() {
        let pasta = Self.arquivo.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        if let dados = try? JSONEncoder().encode(estado) {
            try? dados.write(to: Self.arquivo, options: [.atomic, .completeFileProtection])
        }
    }
}
