import Foundation
import Testing
@testable import CrunningCore

@Suite("Texto rápido do construtor")
struct TextoRapidoTests {
    static let exemplo: [Bloco] = [
        .passo(Passo(.aquecimento, .tempo(600), .facil)),
        .repetir(vezes: 6, passos: [
            Passo(.trabalho, .distancia(400), .intervalado),
            Passo(.recuperacao, .tempo(90), .facil),
        ]),
        .passo(Passo(.desaquecimento, .tempo(600), .facil)),
    ]

    @Test func exemploDoConstrutor() throws {
        let blocos = try TextoRapido.interpretar("10min fácil + 6x(400m forte / 90s trote) + 10min fácil")
        #expect(blocos == Self.exemplo)
    }

    @Test(arguments: [
        "10 min leve + 6 x 400 m tiro / 1:30 trote + 10' facil",
        "10min facil, 6x(400m forte/90s trote), 10min facil",
        "10 minutos fácil + 6×(400 metros forte / 1min30s trote) + 10 min fácil",
        "10min aquecimento + 6 vezes (400m intervalado / 90 seg trote) + 10min desaquecimento",
        "10min facil\n6x(400m forte / 90s trote)\n10min facil",
        "10MIN FÁCIL + 6X(400M FORTE / 90S TROTE) + 10MIN FÁCIL",
    ])
    func variacoes(texto: String) throws {
        #expect(try TextoRapido.interpretar(texto) == Self.exemplo)
    }

    @Test func medidas() throws {
        func medida(_ texto: String) throws -> Medida {
            let blocos = try TextoRapido.interpretar(texto)
            guard case let .passo(p) = try #require(blocos.first) else { throw ErroTextoRapido("não é passo") }
            return p.medida
        }
        #expect(try medida("1h30 fácil") == .tempo(5400))
        #expect(try medida("1h 15min fácil") == .tempo(4500))
        #expect(try medida("2min30s rápido") == .tempo(150))
        #expect(try medida("2'30\" rápido") == .tempo(150))
        #expect(try medida("1:05:00 fácil") == .tempo(3900))
        #expect(try medida("1,5km limiar") == .distancia(1500))
        #expect(try medida("1.5 km limiar") == .distancia(1500))
        #expect(try medida("5k") == .distancia(5000))
        #expect(try medida("800m") == .distancia(800))
        #expect(try medida("fácil 40 min") == .tempo(2400))
    }

    @Test func intensidades() throws {
        func intensidade(_ texto: String) throws -> Intensidade {
            guard case let .passo(p) = try #require(try TextoRapido.interpretar(texto).first) else { throw ErroTextoRapido("não é passo") }
            return p.intensidade
        }
        #expect(try intensidade("20min") == .facil)
        #expect(try intensidade("20min caminhada") == .caminhada)
        #expect(try intensidade("20min no limiar") == .limiar)
        #expect(try intensidade("20min tempo") == .limiar)
        #expect(try intensidade("10km ritmo de maratona") == .maratona)
        #expect(try intensidade("5km ritmo de prova") == .prova)
        #expect(try intensidade("1km muito forte") == .repeticoes)
        #expect(try intensidade("3min vo2") == .intervalado)
    }

    @Test func funcoesPelaPosicao() throws {
        // Corrida contínua fácil: tudo é trabalho.
        #expect(try TextoRapido.interpretar("40min fácil") == [.passo(Passo(.trabalho, .tempo(2400), .facil))])
        // Progressivo: o começo fácil longo é trabalho, não aquecimento.
        #expect(try TextoRapido.interpretar("6km fácil + 3km maratona") == [
            .passo(Passo(.trabalho, .distancia(6000), .facil)),
            .passo(Passo(.trabalho, .distancia(3000), .maratona)),
        ])
        // Trote entre dois trechos fortes é recuperação.
        #expect(try TextoRapido.interpretar("2km fácil + 1km forte + 2min trote + 1km forte + 1km fácil") == [
            .passo(Passo(.aquecimento, .distancia(2000), .facil)),
            .passo(Passo(.trabalho, .distancia(1000), .intervalado)),
            .passo(Passo(.recuperacao, .tempo(120), .facil)),
            .passo(Passo(.trabalho, .distancia(1000), .intervalado)),
            .passo(Passo(.desaquecimento, .distancia(1000), .facil)),
        ])
        // Caminhada e corrida: a corrida é o trabalho, a caminhada é a pausa.
        #expect(try TextoRapido.interpretar("5min caminhada + 8x(1min trote / 90s caminhada) + 5min caminhada") == [
            .passo(Passo(.aquecimento, .tempo(300), .caminhada)),
            .repetir(vezes: 8, passos: [Passo(.trabalho, .tempo(60), .facil), Passo(.recuperacao, .tempo(90), .caminhada)]),
            .passo(Passo(.desaquecimento, .tempo(300), .caminhada)),
        ])
        // Sem intensidade na repetição: o primeiro passo é tiro, o segundo é trote.
        #expect(try TextoRapido.interpretar("8x(200m / 200m)") == [
            .repetir(vezes: 8, passos: [Passo(.trabalho, .distancia(200), .intervalado), Passo(.recuperacao, .distancia(200), .facil)]),
        ])
        // Descanso parado entre tiros.
        #expect(try TextoRapido.interpretar("4x(1km limiar / 1min descanso)") == [
            .repetir(vezes: 4, passos: [Passo(.trabalho, .distancia(1000), .limiar), Passo(.recuperacao, .tempo(60), .caminhada)]),
        ])
    }

    @Test(arguments: [
        ("", "Escreva"),
        ("400 forte", "unidade"),
        ("6x", "repetir"),
        ("10min voando", "Não entendi"),
        ("3x(2x(200m / 200m) / 3min trote)", "Repetição dentro"),
        ("6x(400m forte / 90s trote", "fechar"),
        ("10min 5km fácil", "tempo ou distância"),
        ("60x(100m / 100m)", "repetições"),
        ("10min fácil 5min forte", "Um trecho por vez"),
    ])
    func errosExplicados(texto: String, trecho: String) {
        switch TextoRapido.resultado(texto) {
        case .success: Issue.record("Aceitou \"\(texto)\"")
        case let .failure(erro): #expect(erro.mensagem.contains(trecho), "\(texto): \(erro.mensagem)")
        }
    }

    @Test func escreveOTexto() {
        #expect(TextoRapido.texto(Self.exemplo) == "10min aquecimento + 6x(400m forte / 1min30s trote) + 10min desaquecimento")
        #expect(TextoRapido.textoMedida(.distancia(21_097.5)) == "21,0975km")
        #expect(TextoRapido.textoMedida(.tempo(3900)) == "1h5min")
    }

    /// O texto de qualquer modelo do motor volta ao mesmo treino (medidas e intensidades).
    @Test func idaEVoltaComOsModelos() throws {
        let doses: [TipoDose: [Double]] = [
            .distanciaTotal: [3000, 8000, 21_097.5, 42_195],
            .distanciaDeTrabalho: [2000, 4800, 8000],
            .minutosDeTrabalho: [6, 12, 20],
            .ciclos: [4, 8],
        ]
        for modelo in Modelos.todos {
            for dose in doses[modelo.tipoDose] ?? [] {
                let original = modelo.treino(dose: dose)
                let texto = TextoRapido.texto(original.blocos)
                let lido = Treino(nome: "", tipo: original.tipo, blocos: try TextoRapido.interpretar(texto))
                let a = original.passosExpandidos, b = lido.passosExpandidos
                #expect(a.count == b.count, "\(modelo.id) \(dose): \(texto)")
                for (x, y) in zip(a, b) {
                    #expect(x.intensidade == y.intensidade, "\(modelo.id) \(dose): \(texto)")
                    switch (x.medida, y.medida) {
                    case let (.tempo(t1), .tempo(t2)): #expect(abs(t1 - t2) < 0.5, "\(modelo.id): \(texto)")
                    case let (.distancia(d1), .distancia(d2)): #expect(abs(d1 - d2) < 0.5, "\(modelo.id): \(texto)")
                    default: Issue.record("\(modelo.id) \(dose): medida trocou em \(texto)")
                    }
                }
            }
        }
    }

    /// Nos modelos com aquecimento e desaquecimento escritos, as funções também voltam iguais.
    @Test func idaEVoltaComFuncoes() throws {
        let treinos = [
            Modelos.fartlek.treino(dose: 12), Modelos.escada.treino(dose: 3600), Modelos.intervalado800.treino(dose: 4000),
            Modelos.cruise.treino(dose: 4800), Modelos.subidas.treino(dose: 8), Modelos.limiarContinuo.treino(dose: 5000),
            Modelos.ritmoMaratona.treino(dose: 10_000), Modelos.repeticoes200.treino(dose: 2000), Modelos.facil.treino(dose: 8000),
            Modelos.caminhadaCorrida(correrSegundos: 60, caminharSegundos: 90, ciclos: 8),
        ]
        for treino in treinos {
            let texto = TextoRapido.texto(treino.blocos)
            #expect(try TextoRapido.interpretar(texto) == treino.blocos, "\(treino.nome): \(texto)")
        }
    }

    @Test func tipoDoTreinoMontado() throws {
        #expect(Treino.tipoInferido(Self.exemplo) == .intervalado)
        #expect(Treino.tipoInferido(try TextoRapido.interpretar("40min fácil")) == .facil)
        #expect(Treino.tipoInferido(try TextoRapido.interpretar("10min fácil + 20min limiar + 10min fácil")) == .limiar)
        #expect(Treino.tipoInferido(try TextoRapido.interpretar("8x(200m rápido / 200m trote)")) == .repeticoes)
    }
}
