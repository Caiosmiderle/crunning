import Foundation
import Testing
@testable import CrunningCore

@Suite("Troca com o Anilha (contrato v1)")
struct TrocaAnilhaTests {
    typealias A = AgendaPlanoTests

    @Test func mapeamentoDeTipo() {
        #expect(TrocaAnilha.tipo(.longao) == "longo")
        for t in [TipoTreino.intervalado, .repeticoes, .limiar, .ritmoProva, .prova] {
            #expect(TrocaAnilha.tipo(t) == "intervalado")
        }
        for t in [TipoTreino.facil, .recuperacao, .caminhada] {
            #expect(TrocaAnilha.tipo(t) == "leve")
        }
        #expect(TrocaAnilha.tipo(nil) == "leve")
    }

    @Test func itemDeCorridaComUnidadesEFuso() throws {
        // 11/11/2026 às 19:22 em São Paulo (dados fictícios).
        let inicio = A.calendario.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 19, minute: 22))!
        let item = try #require(TrocaAnilha.corrida(
            codigo: "6F1C2B3A-0000-4000-8000-000000000001", inicio: inicio, atualizadaEm: inicio.addingTimeInterval(2700),
            distancia: 6383.27, duracaoMovimento: 2643.6, tipo: .longao, esforco: 7, esteira: false,
            planejado: (semana: 3, dia: 2), stravaID: 123, calendario: A.calendario))
        #expect(item.inicio == "2026-11-11T19:22:00-03:00")
        #expect(item.dataLocal == "2026-11-11")
        #expect(item.tipo == "longo" && item.tipoOrigem == "longao")
        #expect(item.distanciaM == 6383.3)
        #expect(item.duracaoMovimentoS == 2644)
        #expect(item.planejado == .init(semana: 3, dia: 2))
        #expect(item.stravaID == "123")
        #expect(item.apagado == false)

        let json = try #require(String(data: TrocaAnilha.codificar(TrocaAnilha.LoteCorridas(versao: 1, itens: [item])), encoding: .utf8))
        #expect(json.contains("\"origem_id\":\"6F1C2B3A-0000-4000-8000-000000000001\""))
        #expect(json.contains("\"duracao_movimento_s\":2644"))
        #expect(json.contains("\"versao\":1"))
        // Nada de coordenadas no que vai.
        // ("longo" é o tipo; o que não pode aparecer são as chaves de coordenada.)
        #expect(!json.contains("\"lat\"") && !json.contains("\"lon\"") && !json.contains("latitude"))
    }

    @Test func corridaSemDistanciaOuTempoNaoVai() {
        let agora = A.dia(0)
        #expect(TrocaAnilha.corrida(codigo: "x", inicio: agora, atualizadaEm: agora, distancia: 0, duracaoMovimento: 600,
                                    tipo: nil, esforco: nil, esteira: true, planejado: nil, stravaID: nil) == nil)
        #expect(TrocaAnilha.corrida(codigo: "", inicio: agora, atualizadaEm: agora, distancia: 5000, duracaoMovimento: 600,
                                    tipo: nil, esforco: nil, esteira: false, planejado: nil, stravaID: nil) == nil)
        // Esforço fora de 1 a 10 vira desconhecido.
        let item = TrocaAnilha.corrida(codigo: "x", inicio: agora, atualizadaEm: agora, distancia: 5000, duracaoMovimento: 1500,
                                       tipo: nil, esforco: 11, esteira: false, planejado: nil, stravaID: nil)
        #expect(item?.esforco == nil)
        #expect(item?.tipo == "leve" && item?.tipoOrigem == nil)
    }

    @Test func lapideSoComOMinimo() throws {
        let l = TrocaAnilha.apagada(codigo: "abc", em: A.dia(1), calendario: A.calendario)
        #expect(l.apagado && l.inicio == nil && l.distanciaM == nil)
        let json = try #require(String(data: TrocaAnilha.codificar(l), encoding: .utf8))
        #expect(json == "{\"apagado\":true,\"atualizado_em\":\"2026-11-03T12:00:00-03:00\",\"origem_id\":\"abc\"}")
    }

    @Test func planejadosDosProximos14Dias() {
        let agenda = AgendaPlano(plano: A.plano, inicio: A.dia(0), calendario: A.calendario)
        let lote = TrocaAnilha.planejados(agenda, hoje: A.dia(2), calendario: A.calendario)
        #expect(lote.versao == 1)
        #expect(lote.de == "2026-11-04" && lote.ate == "2026-11-17")
        #expect(!lote.itens.isEmpty)
        #expect(lote.itens.allSatisfy { $0.dataLocal >= lote.de && $0.dataLocal <= lote.ate })
        #expect(lote.itens.allSatisfy { $0.origemID.hasPrefix("plano:2026-11-02:") })
        #expect(lote.itens.allSatisfy { ["leve", "longo", "intervalado"].contains($0.tipo) })
        // O longão do plano (dia 6) vem como importante.
        #expect(lote.itens.contains { $0.tipo == "longo" && $0.importante })
        // Fora do plano: nada.
        #expect(TrocaAnilha.planejados(agenda, hoje: A.dia(-30), dias: 7, calendario: A.calendario).itens.isEmpty)
    }

    @Test func tipoDominanteDosBlocos() {
        #expect(TrocaAnilha.tipoDominante([]) == nil)
    }
}
