import Foundation
import Testing
@testable import CrunningCore

@Suite("Força vinda do Anilha (GET /forca, v1)")
struct ForcaAnilhaTests {
    /// Resposta no formato do contrato (dados fictícios).
    static let json = """
    {"versao":1,"cursor":"42","feitas":[
      {"origem_id":"s1","atualizado_em":"2026-11-10T21:00:00.000Z","apagado":false,"data_local":"2026-11-10",
       "inicio":"2026-11-10T20:00:00.000Z","fim":"2026-11-10T21:00:00.000Z","status":"concluida",
       "pernas":true,"series_pernas":9,"esforco":null,"duracao_s":3600,"nome":"Pernas A"},
      {"origem_id":"s2","atualizado_em":"2026-11-11T12:00:00.000Z","apagado":false,"data_local":"2026-11-11",
       "inicio":null,"fim":null,"status":"parcial","pernas":false,"series_pernas":0,"esforco":null,
       "duracao_s":null,"nome":"Peito e tríceps"}],
     "planejadas":[
      {"data_local":"2026-11-13","nome":"Costas","pernas":false,"status":"planejado"},
      {"data_local":"2026-11-11","nome":"Peito e tríceps","pernas":false,"status":"feito"},
      {"data_local":"2026-11-14","nome":"Pernas B","pernas":true,"status":"pulado"}]}
    """

    static func resposta(_ texto: String = json) throws -> RespostaForcaAnilha {
        try JSONDecoder().decode(RespostaForcaAnilha.self, from: Data(texto.utf8))
    }

    @Test func lerRespostaDoContrato() throws {
        var estado = EstadoForcaAnilha()
        #expect(estado.aplicar(try Self.resposta()))
        #expect(estado.cursor == "42")
        let dia = estado.doDia("2026-11-10")
        #expect(dia.feitas.map(\.nome) == ["Pernas A"])
        #expect(dia.feitas.first?.pernas == true)
        #expect(dia.feitas.first?.seriesPernas == 9)
        #expect(dia.planejadas.isEmpty)
    }

    @Test func previstaSoAbertaESemFeitaNoDia() throws {
        var estado = EstadoForcaAnilha()
        estado.aplicar(try Self.resposta())
        #expect(estado.doDia("2026-11-13").planejadas.map(\.nome) == ["Costas"])
        // Pulada não aparece; dia com sessão feita mostra a feita, não a previsão.
        #expect(estado.doDia("2026-11-14").planejadas.isEmpty)
        #expect(estado.doDia("2026-11-11").planejadas.isEmpty)
        #expect(estado.doDia("2026-11-11").feitas.map(\.status) == ["parcial"])
    }

    @Test func lapideApagaEVersaoAntigaNaoVolta() throws {
        var estado = EstadoForcaAnilha()
        estado.aplicar(try Self.resposta())
        let lapide = """
        {"versao":1,"cursor":"43","feitas":[{"origem_id":"s1","atualizado_em":"2026-11-12T08:00:00.000Z",
         "apagado":true,"data_local":"2026-11-10","inicio":null,"fim":null,"status":"concluida","pernas":true,
         "series_pernas":9,"esforco":null,"duracao_s":null,"nome":"Pernas A"}],"planejadas":[]}
        """
        estado.aplicar(try Self.resposta(lapide))
        #expect(estado.doDia("2026-11-10").feitas.isEmpty)
        // A edição antiga chega atrasada: a lápide mais nova vence.
        estado.aplicar(try Self.resposta())
        #expect(estado.doDia("2026-11-10").feitas.isEmpty)
        #expect(estado.cursor == "42")
    }

    @Test func lapideMinimaTambemVale() throws {
        var estado = EstadoForcaAnilha()
        estado.aplicar(try Self.resposta())
        let minima = """
        {"versao":1,"cursor":"44","feitas":[{"origem_id":"s2","atualizado_em":"2026-11-12T09:00:00Z","apagado":true}],"planejadas":[]}
        """
        estado.aplicar(try Self.resposta(minima))
        #expect(estado.doDia("2026-11-11").feitas.isEmpty)
    }

    @Test func edicaoMaisNovaSubstitui() throws {
        var estado = EstadoForcaAnilha()
        estado.aplicar(try Self.resposta())
        let nova = """
        {"versao":1,"cursor":"45","feitas":[{"origem_id":"s2","atualizado_em":"2026-11-12T10:00:00.000Z",
         "apagado":false,"data_local":"2026-11-11","status":"concluida","pernas":true,"series_pernas":3,
         "nome":"Peito e tríceps"}],"planejadas":[]}
        """
        estado.aplicar(try Self.resposta(nova))
        let s = try #require(estado.doDia("2026-11-11").feitas.first)
        #expect(s.status == "concluida")
        #expect(s.seriesPernas == 3)
        // Planejadas chegam inteiras: a resposta vazia limpa as anteriores.
        #expect(estado.planejadas.isEmpty)
    }

    @Test func versaoDesconhecidaNaoMuda() throws {
        var estado = EstadoForcaAnilha()
        let v2 = #"{"versao":2,"cursor":"9","feitas":[],"planejadas":[]}"#
        #expect(!estado.aplicar(try Self.resposta(v2)))
        #expect(estado == EstadoForcaAnilha())
    }

    @Test func chaveDoDiaNoFuso() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        // 23:30 de 12/11 em São Paulo já é 13/11 em UTC: vale o dia local.
        let data = cal.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 23, minute: 30))!
        #expect(EstadoForcaAnilha.chave(data, calendario: cal) == "2026-11-12")
    }

    @Test func estadoSobreviveAoArquivo() throws {
        var estado = EstadoForcaAnilha()
        estado.aplicar(try Self.resposta())
        let dados = try JSONEncoder().encode(estado)
        #expect(try JSONDecoder().decode(EstadoForcaAnilha.self, from: dados) == estado)
    }
}
