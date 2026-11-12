import Foundation

/// O que vai para a análise pós-treino por IA: só dados agregados da corrida (etapas, tempos,
/// pace, batimentos por etapa, esforço). Nunca rota, coordenadas, horário ou dados do Saúde.
/// Opcionais nulos não vão no JSON.
public struct ResumoTreinoIA: Codable, Sendable, Equatable {
    public struct Corredor: Codable, Sendable, Equatable {
        public var nivel: String?
        public var idade: Int?
        public var fcMaxima: Int?
        public var fcMaximaMedida: Bool?
        public var vdot: Double?

        public init(nivel: String? = nil, idade: Int? = nil, fcMaxima: Int? = nil, fcMaximaMedida: Bool? = nil, vdot: Double? = nil) {
            self.nivel = nivel
            self.idade = idade
            self.fcMaxima = fcMaxima
            self.fcMaximaMedida = fcMaximaMedida
            self.vdot = vdot
        }
    }

    public struct Feito: Codable, Sendable, Equatable {
        public var tempo: String?
        public var distanciaM: Int?
        public var pace: String?
        public var fcMedia: Int?
        public var fcMaxima: Int?
        public var fcNoFim: Int?
        public var observacao: String?
    }

    public struct Etapa: Codable, Sendable, Equatable {
        public var etapa: String
        public var planejado: String
        public var feito: Feito
    }

    public struct ParcialKm: Codable, Sendable, Equatable {
        public var km: Int
        public var tempo: String
        public var pace: String
        public var completa: Bool
    }

    public struct Totais: Codable, Sendable, Equatable {
        public var distanciaKm: Double
        public var tempoEmMovimento: String
        public var tempoTotal: String
        public var pace: String
        public var subidaM: Int?
        public var fcMedia: Int?
        public var fcMaxima: Int?
    }

    public struct Anterior: Codable, Sendable, Equatable {
        public var diasAtras: Int
        public var nome: String
        /// Tempos (ou paces) dos trechos principais, na ordem.
        public var trechosPrincipais: String?
        public var esforcoPercebido: Int?

        public init(diasAtras: Int, nome: String, trechosPrincipais: String?, esforcoPercebido: Int?) {
            self.diasAtras = diasAtras
            self.nome = nome
            self.trechosPrincipais = trechosPrincipais
            self.esforcoPercebido = esforcoPercebido
        }
    }

    /// Limites para o pedido não crescer sem controle (treinos longos, corridas de 50 km).
    public static let maximoEtapas = 80
    public static let maximoParciais = 50

    public var treino: String
    public var plano: String?
    public var esteira: Bool
    public var corredor: Corredor?
    public var esforcoPercebido: Int?
    public var etapas: [Etapa]
    public var parciais: [ParcialKm]
    public var totais: Totais
    public var ultimoTreinoParecido: Anterior?
    /// Força registrada no Anilha até 2 dias antes (nome da ficha, dias antes, séries de perna).
    public var forcaRecente: String?

    public init(
        treino: String, plano: String?, esteira: Bool, corredor: Corredor?, esforco: Int?,
        resultados: [ResultadoEtapa], fc: [AmostraFC], inicioCorrida: Date, parciais: [Parcial],
        distancia: Double, tempoEmMovimento: TimeInterval, tempoTotal: TimeInterval, subida: Double,
        anterior: Anterior?
    ) {
        self.treino = treino
        self.plano = plano
        self.esteira = esteira
        self.corredor = corredor
        esforcoPercebido = esforco
        let fcOrdenada = fc.filter { FrequenciaCardiaca.faixaValida.contains($0.bpm) }.sorted { $0.t < $1.t }
        etapas = Array(Self.etapas(resultados, fc: fcOrdenada, inicioCorrida: inicioCorrida, esteira: esteira).prefix(Self.maximoEtapas))
        // Treino por etapas já diz tudo; a corrida livre vai pelas parciais de km.
        self.parciais = etapas.isEmpty && !esteira
            ? parciais.prefix(Self.maximoParciais).map {
                ParcialKm(km: $0.numero, tempo: Formatador.duracao($0.duracao), pace: Formatador.ritmo(segundosPorKm: $0.ritmo), completa: $0.completa)
            }
            : []
        let resumoFC = FrequenciaCardiaca.resumo(fcOrdenada)
        totais = Totais(
            distanciaKm: (distancia / 10).rounded() / 100,
            tempoEmMovimento: Formatador.duracao(tempoEmMovimento),
            tempoTotal: Formatador.duracao(tempoTotal),
            pace: distancia > 0 ? Formatador.ritmo(segundosPorKm: tempoEmMovimento / distancia * 1000) : "--:--",
            subidaM: esteira || subida < 1 ? nil : Int(subida.rounded()),
            fcMedia: resumoFC?.media,
            fcMaxima: resumoFC?.maxima
        )
        ultimoTreinoParecido = anterior
    }

    // MARK: Peças

    static func etapas(_ resultados: [ResultadoEtapa], fc: [AmostraFC], inicioCorrida: Date, esteira: Bool) -> [Etapa] {
        resultados.filter { !$0.ehExercicio }.map { r in
            var nome = r.nome
            if let rep = r.repeticao, let total = r.totalRepeticoes { nome += " \(rep)/\(total)" }
            var feito = Feito()
            if r.situacao != .naoFeita {
                if r.duracao > 0 { feito.tempo = Formatador.duracao(r.duracao) }
                if !esteira, r.distancia >= 1 { feito.distanciaM = Int(r.distancia.rounded()) }
                feito.pace = r.ritmo.map { Formatador.ritmo(segundosPorKm: $0) }
                if let inicio = r.inicio, let fim = r.fim {
                    let t0 = inicio.timeIntervalSince(inicioCorrida)
                    let t1 = fim.timeIntervalSince(inicioCorrida)
                    if let resumo = FrequenciaCardiaca.resumo(fc.filter { $0.t >= t0 && $0.t <= t1 }) {
                        feito.fcMedia = resumo.media
                        feito.fcMaxima = resumo.maxima
                    }
                    if r.funcao == .recuperacao {
                        feito.fcNoFim = FrequenciaCardiaca.valor(em: t1, fc, tolerancia: 10)
                    }
                }
            }
            switch r.situacao {
            case .feita: break
            case .parcial: feito.observacao = L("encerrada antes do fim", "ended before the end")
            case .pulada: feito.observacao = L("pulada pelo corredor antes do fim", "skipped by the runner before the end")
            case .naoFeita: feito.observacao = L("não feita", "not done")
            }
            return Etapa(etapa: nome, planejado: planejado(r.planejado, faixa: r.faixa), feito: feito)
        }
    }

    /// "400 m em 1:40–1:44 (pace 4:10–4:20)", "12:00 (pace 5:40–6:15)".
    static func planejado(_ medida: Medida, faixa: FaixaRitmo?) -> String {
        let paceFaixa = faixa.map { Formatador.ritmo(segundosPorKm: $0.rapido) + "–" + Formatador.ritmo(segundosPorKm: $0.lento) }
        switch medida {
        case let .tempo(t):
            return Formatador.duracao(t) + (paceFaixa.map { " (pace \($0))" } ?? "")
        case let .distancia(d):
            let texto = d < 1000 ? "\(Int(d.rounded())) m"
                : Formatador.numero(d / 1000, casas: d.truncatingRemainder(dividingBy: 1000) == 0 ? 0 : 1) + " km"
            guard let faixa, let paceFaixa else { return texto }
            let tempos = Formatador.duracao(d / 1000 * faixa.rapido) + "–" + Formatador.duracao(d / 1000 * faixa.lento)
            return texto + L(" em ", " in ") + tempos + " (pace \(paceFaixa))"
        }
    }

    /// Tempos dos trechos principais de um treino anterior: tempo nos trechos por distância,
    /// pace nos trechos por tempo. nil sem trechos principais registrados.
    public static func trechosPrincipais(_ resultados: [ResultadoEtapa]) -> String? {
        let trechos = resultados.filter { $0.funcao == .trabalho && $0.situacao != .naoFeita && $0.duracao > 0 }
        guard !trechos.isEmpty else { return nil }
        return trechos.prefix(30).map { r -> String in
            if case .distancia = r.planejado { return Formatador.duracao(r.duracao) }
            return r.ritmo.map { Formatador.ritmo(segundosPorKm: $0) + "/km" } ?? Formatador.duracao(r.duracao)
        }.joined(separator: ", ")
    }

    /// JSON compacto e com chaves em ordem (o mesmo resumo gera sempre o mesmo texto).
    public func json() throws -> String {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try codificador.encode(self), as: UTF8.self)
    }
}
