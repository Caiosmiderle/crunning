import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Exportar e ler GPX 1.1 (o formato que Strava, Garmin e outros apps importam).
public enum GPX {
    public enum Erro: Error, Equatable {
        case invalido
        case semPontos
    }

    /// GPX da corrida: um `<trkseg>` por trecho (pausas manuais quebram o trecho).
    public static func gerar(nome: String, inicio: Date, amostras: [AmostraTrilha]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="CRUNNING" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata><name>\(escapar(nome))</name><time>\(inicio.formatted(.iso8601))</time></metadata>
          <trk>
            <name>\(escapar(nome))</name>
            <type>running</type>

        """
        var segmentoAtual: Int?
        for amostra in amostras {
            if amostra.seg != segmentoAtual {
                if segmentoAtual != nil { xml += "    </trkseg>\n" }
                xml += "    <trkseg>\n"
                segmentoAtual = amostra.seg
            }
            let instante = inicio.addingTimeInterval(amostra.t)
            xml += "      <trkpt lat=\"\(String(format: "%.7f", amostra.lat))\" lon=\"\(String(format: "%.7f", amostra.lon))\">"
            if let alt = amostra.alt { xml += "<ele>\(String(format: "%.1f", alt))</ele>" }
            xml += "<time>\(instante.formatted(.iso8601))</time></trkpt>\n"
        }
        if segmentoAtual != nil { xml += "    </trkseg>\n" }
        xml += "  </trk>\n</gpx>\n"
        return xml
    }

    /// Lê os pontos de um GPX (trkpt ou rtept). Sem horários, cria horários a 5:30/km
    /// a partir de `inicioSemHorario` (útil para simular uma rota desenhada).
    public static func ler(_ dados: Data, inicioSemHorario: Date = Date(timeIntervalSince1970: 1_767_225_600)) throws -> [PontoGPS] {
        let leitor = LeitorGPX()
        let parser = XMLParser(data: dados)
        parser.delegate = leitor
        guard parser.parse() else { throw Erro.invalido }
        var pontos = leitor.pontos
        guard !pontos.isEmpty else { throw Erro.semPontos }
        if pontos.contains(where: { $0.instante == .distantPast }) {
            var acumulado = 0.0
            for i in pontos.indices {
                if i > 0 { acumulado += Geo.distancia(pontos[i - 1], pontos[i]) }
                pontos[i].instante = inicioSemHorario.addingTimeInterval(acumulado / 1000 * 330)
            }
        }
        return pontos.sorted { $0.instante < $1.instante }
    }

    static func escapar(_ texto: String) -> String {
        texto
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func lerData(_ texto: String) -> Date? {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = try? Date(limpo, strategy: .iso8601) { return data }
        return try? Date(limpo, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}

final class LeitorGPX: NSObject, XMLParserDelegate {
    var pontos: [PontoGPS] = []
    private var atual: PontoGPS?
    private var texto = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        texto = ""
        let nome = elementName.lowercased()
        if nome == "trkpt" || nome == "rtept",
           let lat = attributeDict["lat"].flatMap(Double.init),
           let lon = attributeDict["lon"].flatMap(Double.init) {
            atual = PontoGPS(instante: .distantPast, latitude: lat, longitude: lon, precisaoHorizontal: 5)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        texto += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let nome = elementName.lowercased()
        switch nome {
        case "ele":
            atual?.altitude = Double(texto.trimmingCharacters(in: .whitespacesAndNewlines))
        case "time":
            if atual != nil, let data = GPX.lerData(texto) { atual?.instante = data }
        case "trkpt", "rtept":
            if let ponto = atual { pontos.append(ponto) }
            atual = nil
        default:
            break
        }
        texto = ""
    }
}
