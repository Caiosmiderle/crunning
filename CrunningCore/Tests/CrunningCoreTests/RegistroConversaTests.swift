import Foundation
import Testing
@testable import CrunningCore

@Suite("Histórico de conversas do coach")
struct RegistroConversaTests {
    typealias M = RegistroConversa.Mensagem

    @Test func recorteComecaPeloUsuario() {
        // 25 mensagens alternadas, começando pelo usuário (textos fictícios).
        let msgs = (0..<25).map { M(papel: $0 % 2 == 0 ? "user" : "assistant", texto: "m\($0)") }
        let r = RegistroConversa.recorte(msgs, maximo: 20)
        // As 20 últimas começariam pela m5 (assistant): ela cai e sobra a partir da m6.
        #expect(r.first?.papel == "user")
        #expect(r.first?.texto == "m6")
        #expect(r.last?.texto == "m24")
        #expect(r.count == 19)
        // Conversa curta vai inteira.
        #expect(RegistroConversa.recorte(Array(msgs.prefix(3))) == Array(msgs.prefix(3)))
        #expect(RegistroConversa.recorte([]).isEmpty)
        #expect(RegistroConversa.recorte([M(papel: "assistant", texto: "oi")]).isEmpty)
    }

    @Test func tituloPelaPrimeiraFalaDoUsuario() {
        let falas = [
            RegistroConversa.Fala(doCoach: true, texto: "Olá"),
            RegistroConversa.Fala(doCoach: false, texto: "Viajo semana que vem\ne volto no domingo"),
        ]
        #expect(RegistroConversa.titulo(falas) == "Viajo semana que vem e volto no domingo")
        let longo = [RegistroConversa.Fala(doCoach: false, texto: String(repeating: "a", count: 100))]
        let t = RegistroConversa.titulo(longo, limite: 20)
        #expect(t.count == 20 && t.hasSuffix("…"))
        #expect(RegistroConversa.titulo([]) == "")
    }

    @Test func idaEVoltaEmJSON() throws {
        let falas = [RegistroConversa.Fala(doCoach: false, texto: "troca o longão para sábado", instante: Date(timeIntervalSince1970: 1_800_000_000))]
        let dados = try #require(RegistroConversa.codificar(falas))
        #expect(RegistroConversa.decodificar([RegistroConversa.Fala].self, de: dados) == falas)
        #expect(RegistroConversa.decodificar([RegistroConversa.Fala].self, de: nil) == nil)
    }
}
