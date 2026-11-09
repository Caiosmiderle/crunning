import Foundation
import Testing
@testable import CrunningCore

/// Situações de tela bloqueada: o iOS para de mandar pontos quando o aparelho fica
/// parado, perde o sinal ou fecha o app no meio da corrida.
@Suite("Buracos sem pontos e app reaberto")
struct BuracosSemPontosTests {
    func ponto(_ segundos: Double, norte: Double, velocidade: Double?) -> PontoGPS {
        let p = Geo.deslocar(lat: -10, lon: -40, leste: 0, norte: norte)
        return PontoGPS(instante: t0.addingTimeInterval(segundos), latitude: p.lat, longitude: p.lon,
                        precisaoHorizontal: 5, velocidade: velocidade)
    }

    @Test func buracoParadoViraPausaDesdeOUltimoPonto() {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        var eventos: [EventoCorrida] = []
        for p in reta(inicio: t0, segundos: 300, velocidade: 3) { eventos += sessao.receber(p) }
        // O iOS ficou 60 s sem mandar pontos (aparelho parado no semáforo) e voltou no mesmo lugar.
        eventos += sessao.receber(ponto(360, norte: 901, velocidade: 0))
        #expect(sessao.estado == .pausadaAuto)
        #expect(sessao.tempoEmMovimento(em: t0.addingTimeInterval(360)) == 300)
        for p in reta(inicio: t0.addingTimeInterval(361), segundos: 300, velocidade: 3, norteInicial: 901) {
            eventos += sessao.receber(p)
        }
        let fim = t0.addingTimeInterval(661)
        sessao.finalizar(em: fim)

        #expect(eventos.contains(.pausouSozinha))
        #expect(eventos.contains(.retomouSozinha))
        #expect(sessao.tempoEmMovimento(em: fim) == 600)
        #expect(abs(sessao.distancia - 1801) < 3)
    }

    @Test func buracoCorrendoNaoViraPausa() {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        var eventos: [EventoCorrida] = []
        for p in reta(inicio: t0, segundos: 300, velocidade: 3) { eventos += sessao.receber(p) }
        // Túnel: 60 s sem sinal, mas saiu 180 m adiante (3 m/s): continuou correndo.
        for p in reta(inicio: t0.addingTimeInterval(360), segundos: 300, velocidade: 3, norteInicial: 1080) {
            eventos += sessao.receber(p)
        }
        let fim = t0.addingTimeInterval(660)
        sessao.finalizar(em: fim)

        #expect(!eventos.contains(.pausouSozinha))
        #expect(sessao.tempoEmMovimento(em: fim) == 660)
        #expect(abs(sessao.distancia - 1980) < 2)
    }

    @Test func buracoParadoSemPausaAutomaticaContaTudo() {
        var sessao = SessaoCorrida(configuracao: ConfiguracaoCorrida(pausaAutomatica: false))
        sessao.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: 300, velocidade: 3) { sessao.receber(p) }
        sessao.receber(ponto(360, norte: 901, velocidade: 0))
        #expect(sessao.estado == .correndo)
        #expect(sessao.tempoEmMovimento(em: t0.addingTimeInterval(360)) == 360)
    }

    @Test func avisoDeParadoPausaNaHora() {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: 100, velocidade: 3) { sessao.receber(p) }
        let primeiro = sessao.marcarParado(em: t0.addingTimeInterval(100))
        #expect(primeiro == [.pausouSozinha])
        #expect(sessao.estado == .pausadaAuto)
        #expect(sessao.tempoEmMovimento(em: t0.addingTimeInterval(200)) == 100)
        // Repetir o aviso não muda nada.
        let repetido = sessao.marcarParado(em: t0.addingTimeInterval(150))
        #expect(repetido.isEmpty)

        var eventos: [EventoCorrida] = []
        for p in reta(inicio: t0.addingTimeInterval(200), segundos: 100, velocidade: 3, norteInicial: 301) {
            eventos += sessao.receber(p)
        }
        #expect(eventos.first == .retomouSozinha)
        #expect(sessao.tempoEmMovimento(em: t0.addingTimeInterval(300)) == 200)
    }

    @Test func avisoDeParadoIgnoradoSemPausaAutomaticaOuPausado() {
        var semAuto = SessaoCorrida(configuracao: ConfiguracaoCorrida(pausaAutomatica: false))
        semAuto.iniciar(em: t0)
        let semAutoEventos = semAuto.marcarParado(em: t0.addingTimeInterval(10))
        #expect(semAutoEventos.isEmpty)
        #expect(semAuto.estado == .correndo)

        var pausada = SessaoCorrida()
        pausada.iniciar(em: t0)
        pausada.pausar(em: t0.addingTimeInterval(10))
        let pausadaEventos = pausada.marcarParado(em: t0.addingTimeInterval(20))
        #expect(pausadaEventos.isEmpty)
        #expect(pausada.estado == .pausadaManual)
    }

    @Test func appReabertoNoMeioContinuaCorrendo() throws {
        var sessao = SessaoCorrida()
        sessao.iniciar(em: t0)
        for p in reta(inicio: t0, segundos: 600, velocidade: 3) { sessao.receber(p) }
        // O iOS fechou o app; a cópia salva em disco é reaberta 90 s depois, com a pessoa ainda correndo.
        var reaberta = try JSONDecoder().decode(SessaoCorrida.self, from: JSONEncoder().encode(sessao))
        var eventos: [EventoCorrida] = []
        for p in reta(inicio: t0.addingTimeInterval(690), segundos: 300, velocidade: 3, norteInicial: 2070) {
            eventos += reaberta.receber(p)
        }
        let fim = t0.addingTimeInterval(990)
        reaberta.finalizar(em: fim)

        #expect(!eventos.contains(.pausouSozinha))
        #expect(reaberta.tempoEmMovimento(em: fim) == 990)
        #expect(abs(reaberta.distancia - 2970) < 2)
        #expect(reaberta.parciaisKm.count == 2)
    }
}

@Suite("Diagnóstico do GPS")
struct DiagnosticoGPSTests {
    @Test func contaPontosEMaiorBuraco() {
        var d = DiagnosticoGPS()
        for i in 0..<10 { d.registrarPonto(em: t0.addingTimeInterval(Double(i)), segundoPlano: false) }
        for i in 10..<30 { d.registrarPonto(em: t0.addingTimeInterval(Double(i)), segundoPlano: true) }
        d.registrarPonto(em: t0.addingTimeInterval(29 + 40), segundoPlano: true)
        d.registrarPonto(em: t0.addingTimeInterval(69 + 5), segundoPlano: false)

        #expect(d.pontosPrimeiroPlano == 11)
        #expect(d.pontosSegundoPlano == 21)
        #expect(d.pontos == 32)
        #expect(d.maiorIntervalo == 40)
        #expect(d.inicioMaiorIntervalo == t0.addingTimeInterval(29))
        #expect(d.intervalosLongos == 1)
        #expect(d.temProblema)
    }

    @Test func semBuracosNemAvisosNaoTemProblema() {
        var d = DiagnosticoGPS()
        d.registrar(.segundoPlano, em: t0)
        for i in 0..<100 { d.registrarPonto(em: t0.addingTimeInterval(Double(i)), segundoPlano: true) }
        d.registrar(.primeiroPlano, em: t0.addingTimeInterval(100))
        d.registrar(.parado, em: t0.addingTimeInterval(101))
        #expect(!d.temProblema)
    }

    @Test func avisoRepetidoSemPontoContaUmaVez() {
        var d = DiagnosticoGPS()
        d.registrar(.semSinal, em: t0)
        d.registrar(.semSinal, em: t0.addingTimeInterval(1))
        d.registrar(.semSinal, em: t0.addingTimeInterval(2))
        #expect(d.quantas(.semSinal) == 1)
        d.registrarPonto(em: t0.addingTimeInterval(3), segundoPlano: true)
        d.registrar(.semSinal, em: t0.addingTimeInterval(4))
        #expect(d.quantas(.semSinal) == 2)
        #expect(d.temProblema)
    }

    @Test func limiteDeEventos() {
        var d = DiagnosticoGPS()
        for i in 0..<(DiagnosticoGPS.maximoEventos + 20) {
            d.registrar(i % 2 == 0 ? .segundoPlano : .primeiroPlano, em: t0.addingTimeInterval(Double(i)))
        }
        #expect(d.eventos.count == DiagnosticoGPS.maximoEventos)
        #expect(d.eventosDescartados == 20)
    }

    @Test func salvaECarregaIgual() throws {
        var d = DiagnosticoGPS()
        d.registrar(.reaberto, em: t0)
        d.registrarPonto(em: t0, segundoPlano: true)
        d.registrarPonto(em: t0.addingTimeInterval(20), segundoPlano: true)
        let volta = try JSONDecoder().decode(DiagnosticoGPS.self, from: JSONEncoder().encode(d))
        #expect(volta == d)
        #expect(volta.quantas(.reaberto) == 1)
    }
}
