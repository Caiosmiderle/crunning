import Foundation
import Testing
@testable import CrunningCore

@Suite("TCX (plano B do Apple Saúde)")
struct TCXTests {
    final class Contador: NSObject, XMLParserDelegate {
        var elementos: [String: Int] = [:]
        var textos: [String: String] = [:]
        private var atual = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            elementos[elementName, default: 0] += 1
            atual = ""
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            atual += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if textos[elementName] == nil { textos[elementName] = atual.trimmingCharacters(in: .whitespacesAndNewlines) }
            atual = ""
        }
    }

    static func ler(_ xml: String) throws -> Contador {
        let contador = Contador()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = contador
        guard parser.parse() else { throw GPX.Erro.invalido }
        return contador
    }

    static let inicio = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func corridaComRota() throws {
        let amostras = (0..<10).map { i in
            AmostraTrilha(t: Double(i) * 10, lat: -20.3 + Double(i) * 0.0003, lon: -40.3, alt: 5, d: Double(i) * 33, mov: Double(i) * 10, seg: 0)
        }
        let xml = TCX.gerar(.init(nome: "6 × 400 m & cia", inicio: Self.inicio, duracaoEmMovimento: 90, distancia: 297, calorias: 21.6), amostras: amostras)
        let c = try Self.ler(xml)
        #expect(c.elementos["Trackpoint"] == 10)
        #expect(c.elementos["Lap"] == 1)
        #expect(c.textos["DistanceMeters"] == "297.0")
        #expect(c.textos["Calories"] == "22")
        #expect(c.textos["Notes"] == "6 × 400 m & cia")
        #expect(c.textos["Id"] == Self.inicio.formatted(.iso8601))
    }

    @Test func esteiraSemRota() throws {
        let xml = TCX.gerar(.init(nome: "Corrida na esteira", inicio: Self.inicio, duracaoEmMovimento: 1800, distancia: 5200, calorias: 0), amostras: [])
        let c = try Self.ler(xml)
        #expect(c.elementos["Track"] == nil)
        #expect(c.textos["TotalTimeSeconds"] == "1800.0")
        #expect(c.textos["DistanceMeters"] == "5200.0")
        #expect(c.textos["Calories"] == "0")
    }

    @Test func nomeDoArquivo() {
        let nome = TCX.nomeArquivo(inicio: Self.inicio, extensao: "tcx")
        #expect(nome.hasPrefix("crunning-20"))
        #expect(nome.hasSuffix(".tcx"))
        #expect(!nome.contains(":"))
    }
}
