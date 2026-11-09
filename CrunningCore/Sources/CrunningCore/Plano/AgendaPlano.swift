import Foundation

/// O que aconteceu com uma sessão do plano.
public enum StatusSessao: String, Codable, Sendable {
    case planejada
    case feita
    case perdida
}

/// O plano em uso, preso ao calendário: a semana 1 começa na segunda `inicio`.
/// Guarda o que foi feito ou perdido em cada dia, para o Hoje, o calendário e a adaptação.
public struct AgendaPlano: Codable, Sendable, Equatable {
    public var plano: Plano
    public var inicio: Date
    /// "semana-dia" -> status (sem chave = planejada).
    public var registros: [String: StatusSessao]
    /// Esforço percebido das corridas feitas pelo plano ("semana-dia" -> 1 a 10).
    public var esforcos: [String: Int]

    public init(plano: Plano, inicio: Date, calendario: Calendar = CalendarioTreino.padrao()) {
        self.plano = plano
        self.inicio = CalendarioTreino.inicioDaSemana(inicio, calendario: calendario)
        self.registros = [:]
        self.esforcos = [:]
    }

    static func chave(_ semana: Int, _ dia: Int) -> String { "\(semana)-\(dia)" }

    // MARK: Datas

    /// Semana do plano (1...n) e dia (0 = segunda) de uma data; nil fora do plano.
    public func posicao(de data: Date, calendario: Calendar = CalendarioTreino.padrao()) -> (semana: Int, dia: Int)? {
        let comeco = calendario.startOfDay(for: inicio)
        let alvo = calendario.startOfDay(for: data)
        guard let dias = calendario.dateComponents([.day], from: comeco, to: alvo).day, dias >= 0 else { return nil }
        let semana = dias / 7 + 1
        guard semana <= plano.semanas.count else { return nil }
        return (semana, dias % 7)
    }

    public func data(semana: Int, dia: Int, calendario: Calendar = CalendarioTreino.padrao()) -> Date {
        calendario.date(byAdding: .day, value: (semana - 1) * 7 + dia, to: calendario.startOfDay(for: inicio)) ?? inicio
    }

    public func sessao(semana: Int, dia: Int) -> SessaoPlanejada? {
        guard (1...plano.semanas.count).contains(semana), (0...6).contains(dia) else { return nil }
        return plano.semanas[semana - 1].dias[dia]
    }

    /// Data do último dia do plano.
    public var fim: Date { data(semana: plano.semanas.count, dia: 6) }

    // MARK: Registros

    public func status(semana: Int, dia: Int) -> StatusSessao {
        registros[Self.chave(semana, dia)] ?? .planejada
    }

    public mutating func marcar(semana: Int, dia: Int, _ status: StatusSessao, esforco: Int? = nil) {
        registros[Self.chave(semana, dia)] = status == .planejada ? nil : status
        if let esforco { esforcos[Self.chave(semana, dia)] = esforco }
    }

    /// Sessões de dias já passados (antes de `hoje`) ainda sem registro, das últimas `janela` semanas.
    public func pendentes(hoje: Date, janelaDias: Int = 7, calendario: Calendar = CalendarioTreino.padrao()) -> [(semana: Int, dia: Int)] {
        var lista: [(semana: Int, dia: Int)] = []
        for atras in stride(from: janelaDias, through: 1, by: -1) {
            guard let d = calendario.date(byAdding: .day, value: -atras, to: calendario.startOfDay(for: hoje)),
                  let p = posicao(de: d, calendario: calendario),
                  sessao(semana: p.semana, dia: p.dia) != nil,
                  status(semana: p.semana, dia: p.dia) == .planejada else { continue }
            lista.append(p)
        }
        return lista
    }

    /// Esforço das últimas corridas fáceis feitas pelo plano, da mais recente para a mais antiga.
    public func esforcosRecentesEmFaceis(ate hoje: Date, calendario: Calendar = CalendarioTreino.padrao()) -> [Int] {
        guard let atual = posicao(de: hoje, calendario: calendario) else { return [] }
        var lista: [Int] = []
        var semana = atual.semana, dia = atual.dia
        for _ in 0..<28 {
            if let s = sessao(semana: semana, dia: dia), !s.ehForte, status(semana: semana, dia: dia) == .feita,
               let e = esforcos[Self.chave(semana, dia)] {
                lista.append(e)
            }
            dia -= 1
            if dia < 0 { dia = 6; semana -= 1 }
            if semana < 1 { break }
        }
        return lista
    }

    /// Troca o plano mantendo os registros das semanas que não mudaram de lugar.
    public mutating func trocarPlano(_ novo: Plano) {
        plano = novo
        registros = registros.filter { chave, _ in
            let partes = chave.split(separator: "-").compactMap { Int($0) }
            guard partes.count == 2 else { return false }
            return partes[0] <= novo.semanas.count && novo.semanas[partes[0] - 1].dias[partes[1]] != nil
        }
    }

    /// Segunda-feira que vem (ou hoje, se hoje é segunda).
    public static func proximaSegunda(_ data: Date, calendario: Calendar = CalendarioTreino.padrao()) -> Date {
        let inicio = CalendarioTreino.inicioDaSemana(data, calendario: calendario)
        if calendario.isDate(inicio, inSameDayAs: data) { return inicio }
        return calendario.date(byAdding: .day, value: 7, to: inicio) ?? inicio
    }
}

extension Adaptacao {
    /// Para que lado o ritmo dos trechos de qualidade saiu numa corrida: true = mais rápido,
    /// false = mais lento, nil = dentro da faixa, misturado ou sem dados.
    public static func ladoDoRitmo(_ resultados: [ResultadoEtapa]) -> Bool? {
        var rapidos = 0, lentos = 0, dentro = 0
        for r in resultados where r.situacao == .feita && !r.ehExercicio && r.tipo.ehQualidade {
            guard let ritmo = r.ritmo, let faixa = r.faixa else { continue }
            switch SituacaoRitmo.avaliar(ritmo, faixa: faixa) {
            case .rapido: rapidos += 1
            case .lento: lentos += 1
            case .dentro: dentro += 1
            case .semDados: break
            }
        }
        let total = rapidos + lentos + dentro
        guard total > 0 else { return nil }
        if Double(rapidos) / Double(total) > 0.5 { return true }
        if Double(lentos) / Double(total) > 0.5 { return false }
        return nil
    }

    /// Quantos treinos de qualidade seguidos (do mais recente) saíram para o mesmo lado.
    public static func foraDoRitmoSeguidos(_ lados: [Bool?]) -> (seguidos: Int, maisRapido: Bool)? {
        guard let primeiro = lados.first, let lado = primeiro else { return nil }
        let seguidos = lados.prefix { $0 == lado }.count
        return (seguidos, lado)
    }
}

/// Melhores tempos dentro das corridas (qualquer trecho contínuo, pelo tempo em movimento).
public enum Recordes {
    public static let distancias: [(nome: String, metros: Double)] = [
        ("1 km", 1000), ("5 km", 5000), ("10 km", 10_000), ("Meia maratona", 21_097.5), ("Maratona", 42_195),
    ]

    /// Menor tempo em movimento para cobrir `distancia` metros em qualquer trecho da corrida,
    /// com interpolação entre amostras. nil se a corrida for mais curta.
    public static func melhorTempo(_ amostras: [AmostraTrilha], distancia: Double) -> TimeInterval? {
        guard let ultima = amostras.last, ultima.d >= distancia, amostras.count >= 2 else { return nil }
        var melhor: TimeInterval?
        var j = 0
        for i in amostras.indices {
            let alvo = amostras[i].d + distancia
            guard alvo <= ultima.d else { break }
            if j < i { j = i }
            while j < amostras.count - 1, amostras[j].d < alvo { j += 1 }
            let a = amostras[j - (j > i ? 1 : 0)], b = amostras[j]
            let mov: TimeInterval
            if b.d > a.d {
                mov = a.mov + (alvo - a.d) / (b.d - a.d) * (b.mov - a.mov)
            } else {
                mov = b.mov
            }
            let tempo = mov - amostras[i].mov
            if tempo > 0, melhor.map({ tempo < $0 }) ?? true { melhor = tempo }
        }
        return melhor
    }
}
