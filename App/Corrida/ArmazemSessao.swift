import CrunningCore
import Foundation

/// Corrida em andamento salva em disco, para recuperar se o iOS fechar o app.
struct SessaoSalva: Codable, Sendable, Identifiable {
    var sessao: SessaoCorrida
    var simulada: Bool
    /// Último instante conhecido da gravação (relógio da corrida).
    var salvaEm: Date

    var id: Date { salvaEm }
}

/// Grava e lê a corrida em andamento. Tudo passa por uma fila serial, então um
/// salvamento atrasado nunca recria o arquivo depois de ele ser apagado.
enum ArmazemSessao {
    private static let fila = DispatchQueue(label: "io.github.caiosmiderle.crunning.sessao", qos: .utility)
    static let arquivo = URL.applicationSupportDirectory.appending(path: "sessao-em-andamento.json")

    static func salvar(_ sessao: SessaoSalva) {
        fila.async {
            do {
                try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
                let dados = try JSONEncoder().encode(sessao)
                // Gravável com a tela bloqueada (depois do primeiro desbloqueio).
                try dados.write(to: arquivo, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch {
                // Sem espaço ou erro de disco: a corrida segue na memória.
            }
        }
    }

    static func carregar() -> SessaoSalva? {
        fila.sync {
            guard let dados = try? Data(contentsOf: arquivo) else { return nil }
            return try? JSONDecoder().decode(SessaoSalva.self, from: dados)
        }
    }

    static func apagar() {
        fila.async {
            try? FileManager.default.removeItem(at: arquivo)
        }
    }
}

/// Rota usada no modo de simulação: um .gpx importado ou a rota de exemplo gerada.
enum Simulacao {
    static let arquivoGPX = URL.applicationSupportDirectory.appending(path: "simulacao.gpx")

    static var temGPXImportado: Bool {
        FileManager.default.fileExists(atPath: arquivoGPX.path(percentEncoded: false))
    }

    static func pontos() -> [PontoGPS] {
        if let dados = try? Data(contentsOf: arquivoGPX), let pontos = try? GPX.ler(dados), pontos.count >= 2 {
            return pontos
        }
        return RotaSimulada.gerar(inicio: .now, semente: UInt64.random(in: 1...UInt64.max))
    }

    /// Valida e guarda o .gpx escolhido. Devolve quantos pontos ele tem.
    static func importar(_ dados: Data) throws -> Int {
        let pontos = try GPX.ler(dados)
        guard pontos.count >= 2 else { throw GPX.Erro.semPontos }
        try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        try dados.write(to: arquivoGPX, options: .atomic)
        return pontos.count
    }

    static func usarRotaDeExemplo() {
        try? FileManager.default.removeItem(at: arquivoGPX)
    }
}
