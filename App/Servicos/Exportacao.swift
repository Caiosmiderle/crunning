import CrunningCore
import Foundation

/// Plano B do Apple Saúde: arquivos GPX e TCX das corridas, para importar num app que grava
/// no Saúde (o HealthFit importa os dois) ou em outro serviço.
enum Exportacao {
    /// Peso em Ajustes (kg), só para estimar a energia; 0 = não informado.
    static var pesoKg: Double {
        UserDefaults.standard.double(forKey: Preferencias.pesoKg)
    }

    /// Quilocalorias pela tabela de METs (docs/CIENCIA.md, "Calorias"); nil sem peso.
    static func calorias(distancia: Double, duracaoEmMovimento: TimeInterval) -> Double? {
        let peso = pesoKg
        guard peso > 0, distancia > 0, duracaoEmMovimento > 0 else { return nil }
        let kmh = distancia / duracaoEmMovimento * 3.6
        return Calorias.estimar(.corrida, velocidadeKmH: kmh, pesoKg: peso, duracaoSegundos: duracaoEmMovimento)
    }

    /// Escreve o TCX (sempre) e o GPX (se houver rota) numa pasta temporária.
    static func arquivos(de corrida: Corrida, amostras: [AmostraTrilha]? = nil) -> (tcx: URL?, gpx: URL?) {
        let pontos = amostras ?? corrida.carregarAmostras()
        let pasta = FileManager.default.temporaryDirectory.appending(path: "exportacao", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)

        let resumo = TCX.Resumo(
            nome: corrida.titulo, inicio: corrida.inicio, duracaoEmMovimento: corrida.duracaoEmMovimento,
            distancia: corrida.distanciaMetros,
            calorias: calorias(distancia: corrida.distanciaMetros, duracaoEmMovimento: corrida.duracaoEmMovimento) ?? 0
        )
        let urlTCX = pasta.appending(path: TCX.nomeArquivo(inicio: corrida.inicio, extensao: "tcx"))
        let tcx = (try? TCX.gerar(resumo, amostras: pontos).write(to: urlTCX, atomically: true, encoding: .utf8)) != nil ? urlTCX : nil

        var gpx: URL?
        if pontos.count >= 2 {
            let urlGPX = pasta.appending(path: TCX.nomeArquivo(inicio: corrida.inicio, extensao: "gpx"))
            let xml = GPX.gerar(nome: corrida.titulo, inicio: corrida.inicio, amostras: pontos)
            if (try? xml.write(to: urlGPX, atomically: true, encoding: .utf8)) != nil { gpx = urlGPX }
        }
        return (tcx, gpx)
    }

    /// TCX de várias corridas (exportar o histórico inteiro de uma vez).
    static func todas(_ corridas: [Corrida]) -> [URL] {
        corridas.compactMap { arquivos(de: $0).tcx }
    }
}
