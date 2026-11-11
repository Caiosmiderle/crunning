import CrunningCore
import Foundation
import SwiftData

/// Uma corrida gravada. Todo campo tem valor padrão para o SwiftData migrar
/// sozinho quando surgirem campos novos (a fase 3 acrescentou trilha, subida,
/// esforço e simulada, e a 0.3.1 o diagnóstico, sem perder as corridas antigas).
@Model
final class Corrida {
    var inicio: Date = Date.now
    var duracaoTotal: TimeInterval = 0
    var duracaoEmMovimento: TimeInterval = 0
    var distanciaMetros: Double = 0
    var titulo: String = "Corrida livre"
    /// Gerada pelo modo de desenvolvimento, com dados fictícios.
    var exemplo: Bool = false
    /// Pontos da rota ([AmostraTrilha] em JSON), guardados fora do banco por serem grandes.
    @Attribute(.externalStorage) var trilha: Data? = nil
    var subidaMetros: Double = 0
    /// Esforço percebido de 1 a 10 (escala CR10), respondido no fim.
    var esforcoPercebido: Int? = nil
    /// Gravada com o GPS simulado.
    var simulada: Bool = false
    /// Como o GPS se comportou ([DiagnosticoGPS] em JSON; sem coordenadas).
    var diagnostico: Data? = nil
    /// Treino executado por blocos: planejado x realizado ([ResultadoEtapa] em JSON).
    var blocos: Data? = nil
    /// Corrida na esteira: sem rota, distância digitada no fim.
    var esteira: Bool = false
    /// Sessão do plano que esta corrida cumpriu (semana 1..n, dia 0 = segunda).
    var planoSemana: Int? = nil
    var planoDia: Int? = nil
    /// Código do tênis usado (Tenis.codigo).
    var tenis: String? = nil
    /// Batimentos da pulseira ([AmostraFC] em JSON); média e máxima à parte.
    @Attribute(.externalStorage) var frequencia: Data? = nil
    var fcMedia: Int? = nil
    var fcMaxima: Int? = nil
    /// Atividade criada no Strava, ou o erro do último envio.
    var stravaAtividade: Int64? = nil
    var stravaErro: String? = nil
    /// Na fila de envio ao Strava (sai quando a atividade é criada ou o Strava recusa o arquivo).
    var stravaPendente: Bool = false
    /// Análise pós-treino do treinador de IA ([AnaliseSalva] em JSON), com o custo que a API informou.
    var analiseIA: Data? = nil

    init(
        inicio: Date,
        duracaoTotal: TimeInterval,
        duracaoEmMovimento: TimeInterval,
        distanciaMetros: Double,
        titulo: String = L("Corrida livre", "Free run"),
        exemplo: Bool = false
    ) {
        self.inicio = inicio
        self.duracaoTotal = duracaoTotal
        self.duracaoEmMovimento = duracaoEmMovimento
        self.distanciaMetros = distanciaMetros
        self.titulo = titulo
        self.exemplo = exemplo
    }

    /// Segundos por quilômetro, sobre o tempo em movimento.
    var ritmoMedioSegundosPorKm: Double {
        guard distanciaMetros > 0 else { return 0 }
        return duracaoEmMovimento / (distanciaMetros / 1000)
    }

    /// Decodifica a rota (custa alguns milissegundos: chamar uma vez por tela).
    func carregarAmostras() -> [AmostraTrilha] {
        guard let trilha else { return [] }
        return (try? JSONDecoder().decode([AmostraTrilha].self, from: trilha)) ?? []
    }

    func carregarResultados() -> [ResultadoEtapa] {
        guard let blocos else { return [] }
        return (try? JSONDecoder().decode([ResultadoEtapa].self, from: blocos)) ?? []
    }

    func carregarFC() -> [AmostraFC] {
        guard let frequencia else { return [] }
        return (try? JSONDecoder().decode([AmostraFC].self, from: frequencia)) ?? []
    }

    func carregarAnalise() -> AnaliseSalva? {
        guard let analiseIA else { return nil }
        return try? JSONDecoder().decode(AnaliseSalva.self, from: analiseIA)
    }

    func carregarDiagnostico() -> DiagnosticoGPS? {
        guard let diagnostico else { return nil }
        return try? JSONDecoder().decode(DiagnosticoGPS.self, from: diagnostico)
    }

    /// Monta a corrida a partir da gravação terminada.
    static func de(
        sessao: SessaoCorrida, simulada: Bool, esforco: Int?, agora: Date, diagnostico: DiagnosticoGPS? = nil,
        execucao: ExecucaoTreino? = nil, esteira: Bool = false, distanciaEsteira: Double? = nil,
        fc: [AmostraFC] = []
    ) -> Corrida {
        let fim = sessao.fim ?? agora
        let titulo = execucao?.treino.nome ?? (esteira ? L("Corrida na esteira", "Treadmill run") : simulada ? L("Corrida simulada", "Simulated run") : L("Corrida livre", "Free run"))
        let corrida = Corrida(
            inicio: sessao.inicio ?? fim,
            duracaoTotal: sessao.tempoTotal(em: fim),
            duracaoEmMovimento: sessao.tempoEmMovimento(em: fim),
            distanciaMetros: esteira ? max(0, distanciaEsteira ?? 0) : sessao.distancia,
            titulo: titulo
        )
        corrida.esteira = esteira
        corrida.blocos = execucao.flatMap { try? JSONEncoder().encode($0.resultados) }
        corrida.subidaMetros = sessao.subida
        corrida.esforcoPercebido = esforco
        corrida.simulada = simulada
        corrida.trilha = try? JSONEncoder().encode(sessao.amostras)
        corrida.diagnostico = diagnostico.flatMap { try? JSONEncoder().encode($0) }
        if let resumo = FrequenciaCardiaca.resumo(fc) {
            corrida.frequencia = try? JSONEncoder().encode(fc)
            corrida.fcMedia = resumo.media
            corrida.fcMaxima = resumo.maxima
        }
        return corrida
    }

    /// Corrida fictícia completa (com rota, parciais e altitude), gravada pelo
    /// próprio motor sobre a rota simulada, para testar as telas sem sair de casa.
    static func deExemplo(agora: Date = .now) -> Corrida {
        let diasAtras = Double(Int.random(in: 0...6))
        let inicio = agora.addingTimeInterval(-diasAtras * 86_400 - RotaSimulada.duracaoTotal - 600)
        let pontos = RotaSimulada.gerar(inicio: inicio, semente: UInt64.random(in: 1...UInt64.max))
        var sessao = SessaoCorrida()
        sessao.iniciar(em: inicio)
        for ponto in pontos { sessao.receber(ponto) }
        sessao.finalizar(em: pontos.last?.instante ?? inicio)
        let corrida = Corrida.de(sessao: sessao, simulada: true, esforco: Int.random(in: 4...8), agora: agora)
        corrida.titulo = L("Corrida de exemplo", "Sample run")
        corrida.exemplo = true
        return corrida
    }
}
