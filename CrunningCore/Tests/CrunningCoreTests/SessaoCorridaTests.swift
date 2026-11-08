import Foundation
import Testing
@testable import CrunningCore

/// Pontos fictícios em linha reta para o norte, 1 por segundo.
func reta(
    inicio: Date,
    segundos: Int,
    velocidade: Double,
    norteInicial: Double = 0,
    lat0: Double = -10,
    lon0: Double = -40,
    altitude: (Int) -> Double = { _ in 100 }
) -> [PontoGPS] {
    (0...segundos).map { i in
        let posicao = Geo.deslocar(lat: lat0, lon: lon0, leste: 0, norte: norteInicial + Double(i) * velocidade)
        return PontoGPS(
            instante: inicio.addingTimeInterval(Double(i)),
            latitude: posicao.lat,
            longitude: posicao.lon,
            altitude: altitude(i),
            precisaoHorizontal: 5,
            precisaoVertical: 5,
            velocidade: velocidade
        )
    }
}

let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Suite("Geo e filtro de GPS")
struct GeoFiltroTests {
    @Test func umGrauDeLatitude() {
        let d = Geo.distancia(lat1: 0, lon1: 0, lat2: 1, lon2: 0)
        #expect(abs(d - Geo.metrosPorGrau) < 0.01)
        #expect(abs(d - 111_195) < 1)
    }

    @Test func deslocarConfereComHaversine() {
        let p = Geo.deslocar(lat: -20, lon: -40, leste: 300, norte: 400)
        let d = Geo.distancia(lat1: -20, lon1: -40, lat2: p.lat, lon2: p.lon)
        #expect(abs(d - 500) < 0.5)
    }

    @Test func filtroDescartaPontosRuins() {
        var filtro = FiltroGPS()
        let bom = PontoGPS(instante: t0, latitude: -10, longitude: -40, precisaoHorizontal: 5)
        #expect(filtro.avaliar(PontoGPS(instante: t0, latitude: -10, longitude: -40, precisaoHorizontal: 60)) == .rejeitadoPrecisao)
        #expect(filtro.avaliar(PontoGPS(instante: t0, latitude: -10, longitude: -40, precisaoHorizontal: -1)) == .rejeitadoPrecisao)
        #expect(filtro.avaliar(bom) == .aceito)
        #expect(filtro.avaliar(bom) == .rejeitadoTempo)
        let salto = Geo.deslocar(lat: -10, lon: -40, leste: 300, norte: 0)
        #expect(filtro.avaliar(PontoGPS(instante: t0.addingTimeInterval(1), latitude: salto.lat, longitude: salto.lon, precisaoHorizontal: 5)) == .rejeitadoSalto)
        let normal = Geo.deslocar(lat: -10, lon: -40, leste: 3, norte: 0)
        #expect(filtro.avaliar(PontoGPS(instante: t0.addingTimeInterval(1), latitude: normal.lat, longitude: normal.lon, precisaoHorizontal: 5)) == .aceito)
    }
}

@Suite("Gravação da corrida")
struct SessaoCorridaTests {
    @Test func linhaRetaEmRitmoConstante() {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        var eventos: [EventoCorrida] = []
        // 1001 s a 3 m/s = 3003 m (folga para a soma de ponto flutuante não cair em 2999,99 m).
        for p in reta(inicio: t0, segundos: 1001, velocidade: 3) { eventos += sessao.receber(p) }
        sessao.finalizar(em: t0.addingTimeInterval(1001))

        #expect(abs(sessao.distancia - 3003) < 1)
        #expect(sessao.tempoEmMovimento(em: t0.addingTimeInterval(1001)) == 1001)
        #expect(sessao.parciaisKm.count == 3)
        for duracao in sessao.parciaisKm { #expect(abs(duracao - 1000.0 / 3) < 0.6) }
        #expect(abs((sessao.ritmoMedio(em: t0.addingTimeInterval(1001)) ?? 0) - 1000.0 / 3) < 0.5)
        #expect(!eventos.contains(.pausouSozinha))
        #expect(eventos.filter { if case .parcial = $0 { true } else { false } }.count == 3)
    }

    @Test func ritmoAtualDosUltimosSegundos() {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: 100, velocidade: 3) { sessao.receber(p) }
        let ritmo = sessao.ritmoAtual(em: t0.addingTimeInterval(100))
        #expect(abs((ritmo ?? 0) - 1000.0 / 3) < 1)
        // 30 s sem nenhum ponto novo: ritmo atual some.
        #expect(sessao.ritmoAtual(em: t0.addingTimeInterval(130)) == nil)
    }

    @Test func pausaManualNaoContaTempoNemDistancia() {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: 200, velocidade: 3) { sessao.receber(p) }
        sessao.pausar(em: t0.addingTimeInterval(200))
        // Andou 300 m pausado: ignorado.
        for p in reta(inicio: t0.addingTimeInterval(201), segundos: 99, velocidade: 3, norteInicial: 603) { sessao.receber(p) }
        sessao.retomar(em: t0.addingTimeInterval(300))
        for p in reta(inicio: t0.addingTimeInterval(300), segundos: 200, velocidade: 3, norteInicial: 900) { sessao.receber(p) }
        sessao.finalizar(em: t0.addingTimeInterval(500))

        #expect(abs(sessao.distancia - 1200) < 1)
        #expect(sessao.tempoEmMovimento(em: t0.addingTimeInterval(500)) == 400)
        #expect(sessao.tempoTotal(em: t0.addingTimeInterval(999)) == 500)
        #expect(Set(sessao.amostras.map(\.seg)) == [0, 1])
    }

    @Test func pausaAutomaticaNaParadaComTremido() {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        var eventos: [EventoCorrida] = []
        for p in reta(inicio: t0, segundos: 300, velocidade: 3) { eventos += sessao.receber(p) }
        // 60 s parado num semáforo, com o GPS tremendo até ~1,7 m para cada lado.
        let parado = Geo.deslocar(lat: -10, lon: -40, leste: 0, norte: 900)
        for i in 1...60 {
            let tremido = Geo.deslocar(lat: parado.lat, lon: parado.lon,
                                       leste: Double(i % 3 - 1) * 1.2, norte: Double((i / 2) % 3 - 1) * 1.2)
            eventos += sessao.receber(PontoGPS(instante: t0.addingTimeInterval(Double(300 + i)),
                                               latitude: tremido.lat, longitude: tremido.lon,
                                               precisaoHorizontal: 5, velocidade: 0.05))
        }
        for p in reta(inicio: t0.addingTimeInterval(361), segundos: 300, velocidade: 3, norteInicial: 900) {
            eventos += sessao.receber(p)
        }
        let fim = t0.addingTimeInterval(661)
        sessao.finalizar(em: fim)

        #expect(eventos.contains(.pausouSozinha))
        #expect(eventos.contains(.retomouSozinha))
        let movimento = sessao.tempoEmMovimento(em: fim)
        #expect(movimento > 590 && movimento < 615)
        #expect(abs(sessao.distancia - 1800) < 40)
        #expect(sessao.tempoTotal(em: fim) == 661)
    }

    @Test func semPausaAutomaticaContaTudo() {
        var sessao = SessaoCorrida(configuracao: ConfiguracaoCorrida(pausaAutomatica: false))
        sessao.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: 100, velocidade: 3) { sessao.receber(p) }
        for i in 1...60 {
            let p = Geo.deslocar(lat: -10, lon: -40, leste: 0, norte: 300)
            sessao.receber(PontoGPS(instante: t0.addingTimeInterval(Double(100 + i)), latitude: p.lat, longitude: p.lon, precisaoHorizontal: 5, velocidade: 0))
        }
        #expect(sessao.estado == .correndo)
        #expect(sessao.tempoEmMovimento(em: t0.addingTimeInterval(160)) == 160)
    }

    @Test func sessaoSalvaEmDiscoContinuaIgual() throws {
        var original = SessaoCorrida()
        original.iniciar(em: t0)
        let pontos = reta(inicio: t0, segundos: 600, velocidade: 3.2)
        for p in pontos.prefix(300) { original.receber(p) }

        let dados = try JSONEncoder().encode(original)
        var recuperada = try JSONDecoder().decode(SessaoCorrida.self, from: dados)
        for p in pontos.dropFirst(300) {
            original.receber(p)
            recuperada.receber(p)
        }
        #expect(recuperada.distancia == original.distancia)
        #expect(recuperada.amostras == original.amostras)
        #expect(recuperada.parciaisKm == original.parciaisKm)
        #expect(recuperada.estado == .correndo)
    }

    @Test func pontosAntesDeIniciarSaoIgnorados() {
        var sessao = SessaoCorrida()
        for p in reta(inicio: t0, segundos: 30, velocidade: 3) { sessao.receber(p) }
        #expect(sessao.distancia == 0)
        #expect(sessao.amostras.isEmpty)
    }

    @Test func subidaIgnoraRuidoDoAltimetro() {
        var subindo = SessaoCorrida()
        subindo.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: 300, velocidade: 3, altitude: { Double($0) * 0.1 }) { subindo.receber(p) }
        #expect(subindo.subida >= 27 && subindo.subida <= 30.5)

        var plano = SessaoCorrida()
        plano.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: 300, velocidade: 3, altitude: { $0 % 2 == 0 ? 101 : 99 }) { plano.receber(p) }
        #expect(plano.subida == 0)
    }
}

@Suite("Parciais, séries e trechos do mapa")
struct AnaliseTests {
    func amostrasRetas(segundos: Int, velocidade: Double) -> [AmostraTrilha] {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: segundos, velocidade: velocidade) { sessao.receber(p) }
        return sessao.amostras
    }

    @Test func parciaisPorKmEMilha() {
        let amostras = amostrasRetas(segundos: 1100, velocidade: 3)   // 3,3 km a 5:33/km
        let km = Parciais.calcular(amostras)
        #expect(km.count == 4)
        #expect(km.prefix(3).allSatisfy { $0.completa && abs($0.duracao - 1000.0 / 3) < 0.6 })
        #expect(km.last?.completa == false)
        #expect(abs((km.last?.distancia ?? 0) - 300) < 1)
        #expect(abs((km.last?.ritmo ?? 0) - 1000.0 / 3) < 1)

        let milhas = Parciais.calcular(amostras, comprimento: 1609.344)
        #expect(milhas.count == 3)
        #expect(abs(milhas[0].duracao - 1609.344 / 3) < 0.6)
    }

    @Test func serieDeRitmoConstante() {
        let serie = Series.ritmo(amostrasRetas(segundos: 600, velocidade: 2.5))
        #expect(!serie.isEmpty)
        #expect(serie.allSatisfy { abs($0.valor - 400) < 2 })
    }

    @Test func serieDeAltitudeExisteQuandoHaAltitude() {
        let serie = Series.altitude(amostrasRetas(segundos: 300, velocidade: 3))
        #expect(serie.count >= 18)
        #expect(serie.allSatisfy { $0.valor == 100 })
    }

    @Test func trechosCobremARotaSemLigarPausas() {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: 300, velocidade: 3) { sessao.receber(p) }
        sessao.pausar(em: t0.addingTimeInterval(300))
        sessao.retomar(em: t0.addingTimeInterval(400))
        for p in reta(inicio: t0.addingTimeInterval(400), segundos: 300, velocidade: 3, norteInicial: 1500) { sessao.receber(p) }

        let trechos = Trechos.dividir(sessao.amostras, quantidade: 20)
        #expect(!trechos.isEmpty)
        // Nenhum trecho junta pontos antes e depois da pausa (salto de ~600 m).
        for trecho in trechos {
            for (a, b) in zip(trecho.coordenadas, trecho.coordenadas.dropFirst()) {
                #expect(Geo.distancia(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon) < 50)
            }
        }
        #expect(trechos.compactMap(\.ritmo).allSatisfy { abs($0 - 1000.0 / 3) < 2 })
    }
}

@Suite("GPX e rota simulada")
struct GPXSimulacaoTests {
    @Test func gpxIdaEVolta() throws {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: 120, velocidade: 3) { sessao.receber(p) }
        sessao.pausar(em: t0.addingTimeInterval(120))
        sessao.retomar(em: t0.addingTimeInterval(150))
        for p in reta(inicio: t0.addingTimeInterval(150), segundos: 60, velocidade: 3, norteInicial: 500) { sessao.receber(p) }

        let xml = GPX.gerar(nome: "Treino <teste> & \"aspas\"", inicio: t0, amostras: sessao.amostras)
        #expect(xml.contains("Treino &lt;teste&gt; &amp; &quot;aspas&quot;"))
        #expect(xml.components(separatedBy: "<trkseg>").count - 1 == 2)

        let lidos = try GPX.ler(Data(xml.utf8))
        #expect(lidos.count == sessao.amostras.count)
        for (ponto, amostra) in zip(lidos, sessao.amostras) {
            #expect(abs(ponto.latitude - amostra.lat) < 1e-6)
            #expect(abs(ponto.longitude - amostra.lon) < 1e-6)
            #expect(abs(ponto.instante.timeIntervalSince(t0.addingTimeInterval(amostra.t))) < 1)
        }
    }

    @Test func gpxSemHorarioGanhaHorarios() throws {
        let xml = """
        <gpx><rte>
        <rtept lat="-10.0" lon="-40.0"></rtept>
        <rtept lat="-10.001" lon="-40.0"></rtept>
        <rtept lat="-10.002" lon="-40.0"></rtept>
        </rte></gpx>
        """
        let pontos = try GPX.ler(Data(xml.utf8))
        #expect(pontos.count == 3)
        #expect(pontos[1].instante > pontos[0].instante)
        #expect(pontos[2].instante > pontos[1].instante)
    }

    @Test func gpxInvalidoOuVazio() {
        #expect(throws: GPX.Erro.self) { try GPX.ler(Data("isto não é xml".utf8)) }
        #expect(throws: GPX.Erro.semPontos) { try GPX.ler(Data("<gpx></gpx>".utf8)) }
    }

    @Test func rotaSimuladaPrevisivel() {
        let a = RotaSimulada.gerar(inicio: t0, semente: 7)
        let b = RotaSimulada.gerar(inicio: t0, semente: 7)
        #expect(a == b)
        #expect(a.count == Int(RotaSimulada.duracaoTotal))
        #expect(RotaSimulada.gerar(inicio: t0, semente: 8) != a)
    }

    @Test(arguments: [1, 2, 3, 42, 99] as [UInt64])
    func motorSobreARotaSimulada(semente: UInt64) {
        let pontos = RotaSimulada.gerar(inicio: t0, semente: semente)
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        var eventos: [EventoCorrida] = []
        for p in pontos { eventos += sessao.receber(p) }
        let fim = pontos.last!.instante
        sessao.finalizar(em: fim)

        // Distância "verdadeira" do perfil: soma de duração x velocidade.
        let esperada = RotaSimulada.perfil.reduce(0) { $0 + $1.0 * $1.1 }
        #expect(sessao.distancia > esperada * 0.97 && sessao.distancia < esperada * 1.06)
        #expect(eventos.contains(.pausouSozinha))
        #expect(sessao.tempoEmMovimento(em: fim) < sessao.tempoTotal(em: fim) - 8)
        #expect(sessao.parciaisKm.count == Int(sessao.distancia / 1000))
    }
}
