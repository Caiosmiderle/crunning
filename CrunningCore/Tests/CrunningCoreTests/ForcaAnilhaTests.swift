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

    /// Contrato v1 com os detalhes aditivos, incluindo tempo, peso corporal e lápide.
    static let jsonComDetalhes = """
    {"versao":1,"cursor":"46","feitas":[
      {"origem_id":"s1","atualizado_em":"2026-11-10T21:00:00Z","apagado":false,"data_local":"2026-11-10",
       "status":"concluida","pernas":false,"series_pernas":0,"duracao_s":3600,"nome":"Ficha A",
       "link":"anilha://treino/s1","exercicios":[
        {"nome":"Supino reto com barra","grupo":"peito","series":[
          {"tipo":"aquecimento","carga_kg":20,"reps":12,"segundos":null},
          {"tipo":"trabalho","carga_kg":137.5,"reps":10,"segundos":null},
          {"tipo":"trabalho","carga_kg":null,"reps":12,"segundos":null}]},
        {"nome":"Prancha de teste","grupo":null,"series":[
          {"tipo":"trabalho","carga_kg":null,"reps":null,"segundos":45}]}]},
      {"origem_id":"apagada","atualizado_em":"2026-11-10T22:00:00Z","apagado":true,"link":null,"exercicios":[]}],
     "planejadas":[
      {"data_local":"2026-11-13","nome":"Ficha B","pernas":true,"status":"planejado",
       "ficha_id":"f1","link":"anilha://ficha/f1","exercicios":[
        {"nome":"Agachamento livre","grupo":"pernas","series":3,"reps_min":8,"reps_max":12},
        {"nome":"Avanço de teste","grupo":null,"series":3,"reps_min":10,"reps_max":10}]},
      {"data_local":"2026-11-14","nome":"Ficha C","pernas":false,"status":"planejado",
       "ficha_id":null,"link":null,"exercicios":null}]}
    """

    @Test func camposNovosAusentesContinuamOpcionais() throws {
        let resposta = try Self.resposta()
        #expect(resposta.feitas.allSatisfy { $0.link == nil && $0.exercicios == nil })
        #expect(resposta.planejadas.allSatisfy { $0.fichaID == nil && $0.link == nil && $0.exercicios == nil })
    }

    @Test func lerDetalhesDoContrato() throws {
        let resposta = try Self.resposta(Self.jsonComDetalhes)
        let feita = try #require(resposta.feitas.first)
        #expect(feita.link == "anilha://treino/s1")
        let exercicios = try #require(feita.exercicios)
        #expect(exercicios.map(\.nome) == ["Supino reto com barra", "Prancha de teste"])
        #expect(exercicios[0].grupo == "peito")
        #expect(exercicios[0].series == [
            SerieAnilha(tipo: "aquecimento", cargaKg: 20, reps: 12),
            SerieAnilha(cargaKg: 137.5, reps: 10),
            SerieAnilha(reps: 12)
        ])
        #expect(exercicios[1].grupo == nil)
        #expect(exercicios[1].series == [SerieAnilha(segundos: 45)])
        let prevista = try #require(resposta.planejadas.first)
        #expect(prevista.fichaID == "f1")
        #expect(prevista.link == "anilha://ficha/f1")
        #expect(prevista.exercicios == [
            ExercicioPrevistoAnilha(nome: "Agachamento livre", grupo: "pernas", series: 3, repsMin: 8, repsMax: 12),
            ExercicioPrevistoAnilha(nome: "Avanço de teste", series: 3, repsMin: 10, repsMax: 10)
        ])
        #expect(resposta.feitas[1].apagado)
        #expect(resposta.feitas[1].link == nil)
        #expect(resposta.feitas[1].exercicios == [])
        #expect(resposta.planejadas[1].fichaID == nil)
        #expect(resposta.planejadas[1].link == nil)
        #expect(resposta.planejadas[1].exercicios == nil)
    }

    @Test func aplicarEPersistirMantemDetalhes() throws {
        let resposta = try Self.resposta(Self.jsonComDetalhes)
        var estado = EstadoForcaAnilha()
        #expect(estado.aplicar(resposta))
        #expect(estado.doDia("2026-11-10").feitas == [resposta.feitas[0]])
        #expect(estado.doDia("2026-11-13").planejadas == [resposta.planejadas[0]])
        let dados = try JSONEncoder().encode(estado)
        #expect(try JSONDecoder().decode(EstadoForcaAnilha.self, from: dados) == estado)
        let objeto = try #require(JSONSerialization.jsonObject(with: dados) as? [String: Any])
        let feitas = try #require(objeto["feitas"] as? [String: [String: Any]])
        let exercicios = try #require(feitas["s1"]?["exercicios"] as? [[String: Any]])
        let series = try #require(exercicios.first?["series"] as? [[String: Any]])
        #expect(series[1]["carga_kg"] as? Double == 137.5)
        let planejadas = try #require(objeto["planejadas"] as? [[String: Any]])
        #expect(planejadas[0]["ficha_id"] as? String == "f1")
        let previstas = try #require(planejadas[0]["exercicios"] as? [[String: Any]])
        #expect(previstas[0]["reps_min"] as? Int == 8)
        #expect(previstas[0]["reps_max"] as? Int == 12)
    }

    @Test func arquivoAntigoSemDetalhesContinuaAbrindo() throws {
        let antigo = """
        {"cursor":"42","feitas":{"s1":{
          "origem_id":"s1","atualizado_em":"2026-11-10T21:00:00Z","apagado":false,
          "data_local":"2026-11-10","status":"concluida","pernas":true,"series_pernas":9,"nome":"Ficha A"}},
         "planejadas":[{"data_local":"2026-11-13","nome":"Ficha B","pernas":false,"status":"planejado"}]}
        """
        let estado = try JSONDecoder().decode(EstadoForcaAnilha.self, from: Data(antigo.utf8))
        #expect(estado.cursor == "42")
        let feita = try #require(estado.doDia("2026-11-10").feitas.first)
        #expect(feita.nome == "Ficha A")
        #expect(feita.link == nil && feita.exercicios == nil)
        let prevista = try #require(estado.doDia("2026-11-13").planejadas.first)
        #expect(prevista.nome == "Ficha B")
        #expect(prevista.fichaID == nil && prevista.link == nil && prevista.exercicios == nil)
    }

    @Test func linkSoAceitaTreinoOuFichaDoAnilha() {
        #expect(LinkForcaAnilha.url("anilha://treino/s1") == URL(string: "anilha://treino/s1"))
        #expect(LinkForcaAnilha.url("anilha://ficha/f1") == URL(string: "anilha://ficha/f1"))
        for link in ["https://exemplo.invalid/treino/s1", "anilha://outra/s1", "", "anilha://treino", " anilha://ficha/f1"] {
            #expect(LinkForcaAnilha.url(link) == nil)
        }
        #expect(LinkForcaAnilha.url(nil) == nil)
    }

    @Test func coachEAnaliseNaoRecebemExerciciosSeriesOuCargas() throws {
        var estado = EstadoForcaAnilha()
        estado.aplicar(try Self.resposta(Self.jsonComDetalhes))
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(secondsFromGMT: 0)!
        let hoje = try #require(calendario.date(from: DateComponents(year: 2026, month: 11, day: 11)))
        let coach = try #require(ConflitoForca.paraCoach(estado, hoje: hoje, calendario: calendario))
        #expect(!coach.feitas.isEmpty && !coach.previstas.isEmpty)
        let json = String(decoding: try JSONEncoder().encode(coach), as: UTF8.self)
        let resumo = try #require(ConflitoForca.resumoParaCoach(antesDe: hoje, forca: estado, calendario: calendario))
        for saida in [json, resumo] {
            #expect(saida.contains("Ficha A"))
            for privado in ["Supino reto com barra", "Prancha de teste", "Agachamento livre", "Avanço de teste",
                            "137.5", "137,5", "exercicios", "carga", "aquecimento", "reps", "segundos", "anilha://"] {
                #expect(!saida.contains(privado))
            }
        }
        // Os detalhes também não mudam nenhum agregado enviado à IA.
        var semDetalhes = EstadoForcaAnilha()
        semDetalhes.feitas["s1"] = SessaoForcaAnilha(
            origemID: "s1", atualizadoEm: "2026-11-10T21:00:00Z", dataLocal: "2026-11-10",
            duracaoS: 3600, nome: "Ficha A")
        semDetalhes.planejadas = [
            ForcaPlanejadaAnilha(dataLocal: "2026-11-13", nome: "Ficha B", pernas: true),
            ForcaPlanejadaAnilha(dataLocal: "2026-11-14", nome: "Ficha C", pernas: false)
        ]
        #expect(ConflitoForca.paraCoach(semDetalhes, hoje: hoje, calendario: calendario) == coach)
        #expect(ConflitoForca.resumoParaCoach(antesDe: hoje, forca: semDetalhes, calendario: calendario) == resumo)
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

    @Test func estadoAntigoReleUmaVezParaGanharDetalhe() throws {
        let antigo = #"{"cursor":"40","feitas":{},"planejadas":[]}"#
        var estado = try JSONDecoder().decode(EstadoForcaAnilha.self, from: Data(antigo.utf8))
        #expect(estado.cursor == "40")
        #expect(estado.cursorParaLeitura == nil)
        let resposta = #"{"versao":1,"cursor":"41","feitas":[],"planejadas":[]}"#
        #expect(estado.aplicar(try JSONDecoder().decode(RespostaForcaAnilha.self, from: Data(resposta.utf8))))
        #expect(estado.cursorParaLeitura == "41")
        let salvo = try JSONDecoder().decode(EstadoForcaAnilha.self, from: JSONEncoder().encode(estado))
        #expect(salvo.cursorParaLeitura == "41")
    }
}
