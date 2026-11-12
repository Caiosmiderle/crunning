import Foundation

/// Perna pesada no Anilha perto de um treino forte do plano (qualidade ou longão).
///
/// Base: depois de uma sessão de força de membros inferiores, a economia de corrida e o
/// desempenho podem ficar piores por até 48 h, sobretudo em quem não é treinado em força; o
/// tempo de recuperação varia de pessoa para pessoa (Doma, Deakin e Bentley, 2017, Sports
/// Medicine 47:2187-2200; Doma e colegas, 2019, Sports Medicine - Open). Escolha do app: conta
/// como pesada a sessão com pelo menos `seriesPesada` séries de trabalho de perna, e a prevista
/// no Anilha com perna na véspera. O app nunca move sozinho: sugere, mostra a prévia e espera.
public struct AvisoForca: Equatable, Sendable, Identifiable {
    public var id: String { "forca-\(semana)-\(dia)-\(forcaData)" }
    public let semana: Int
    public let dia: Int
    /// Nome do treino de corrida afetado.
    public let treino: String
    /// Nome da ficha de força e o dia dela (`yyyy-MM-dd`).
    public let forca: String
    public let forcaData: String
    public let seriesPernas: Int?
    /// Dias entre a força e a corrida (1 = véspera, 2 = anteontem).
    public let diasAntes: Int
    /// A força ainda é só previsão do Anilha.
    public let prevista: Bool
    /// Troca de dia sugerida na mesma semana (nil em prova ou quando não há dia leve livre).
    public let sugestao: CorrecaoPlano?

    public var motivo: String {
        let quando = diasAntes == 1 ? L("na véspera", "the day before") : L("dois dias antes", "two days before")
        let series = seriesPernas.map { L(", \($0) séries de perna", ", \($0) leg sets") } ?? ""
        let base = prevista
            ? L("O Anilha prevê \(forca) \(quando), com perna.", "Anilha plans \(forca) \(quando), with legs.")
            : L("Você fez \(forca) no Anilha \(quando)\(series).", "You did \(forca) in Anilha \(quando)\(series).")
        return base + L(" Depois de treino pesado de perna, o rendimento na corrida pode cair por até 48 h (Doma e colegas, 2017 e 2019).",
                        " After heavy leg training, running performance can drop for up to 48 h (Doma et al., 2017 and 2019).")
    }
}

public enum ConflitoForca {
    /// Séries de trabalho de perna a partir das quais a sessão conta como pesada (escolha do app).
    public static let seriesPesada = 6
    /// Janela olhada para trás a partir da corrida, em dias (até 48 h).
    public static let janelaDias = 2
    /// Quantos dias à frente o app avisa (hoje e os dois seguintes).
    public static let horizonteDias = 3

    /// Treino forte: qualidade (intervalado, repetições, limiar, ritmo de prova, prova) ou longão.
    static func forte(_ tipo: TipoTreino) -> Bool {
        tipo == .longao || TrocaAnilha.tipo(tipo) == "intervalado"
    }

    public static func avisos(agenda: AgendaPlano, forca: EstadoForcaAnilha, hoje: Date,
                              calendario: Calendar = CalendarioTreino.padrao()) -> [AvisoForca] {
        var lista: [AvisoForca] = []
        let inicio = calendario.startOfDay(for: hoje)
        for adiante in 0..<horizonteDias {
            guard let data = calendario.date(byAdding: .day, value: adiante, to: inicio),
                  let pos = agenda.posicao(de: data, calendario: calendario),
                  agenda.status(semana: pos.semana, dia: pos.dia) == .planejada,
                  let sessao = agenda.sessao(semana: pos.semana, dia: pos.dia),
                  forte(sessao.tipo),
                  let perna = pernaAntes(data, forca: forca, calendario: calendario)
            else { continue }
            let sugestao = sessao.tipo == .prova ? nil
                : troca(agenda: agenda, semana: pos.semana, de: pos.dia, depoisDe: data, forca: forca, calendario: calendario)
            lista.append(AvisoForca(semana: pos.semana, dia: pos.dia, treino: sessao.treino.nome,
                                    forca: perna.nome, forcaData: perna.data, seriesPernas: perna.series,
                                    diasAntes: perna.dias, prevista: perna.prevista, sugestao: sugestao))
        }
        return lista
    }

    /// A perna pesada mais próxima nos `janelaDias` antes da data (feita; ou prevista na véspera).
    static func pernaAntes(_ data: Date, forca: EstadoForcaAnilha, calendario: Calendar)
        -> (nome: String, data: String, series: Int?, dias: Int, prevista: Bool)? {
        for dias in 1...janelaDias {
            guard let antes = calendario.date(byAdding: .day, value: -dias, to: data) else { continue }
            let chave = EstadoForcaAnilha.chave(antes, calendario: calendario)
            let dia = forca.doDia(chave)
            if let s = dia.feitas.first(where: { $0.pernas == true && ($0.seriesPernas ?? 0) >= seriesPesada }) {
                return (s.nome ?? L("Treino de força", "Strength workout"), chave, s.seriesPernas, dias, false)
            }
            if dias == 1, let p = dia.planejadas.first(where: { $0.pernas }) {
                return (p.nome, chave, nil, dias, true)
            }
        }
        return nil
    }

    /// Primeiro dia leve ou de descanso, depois da corrida e na mesma semana, sem perna pesada
    /// nos dois dias anteriores, em que o motor aceita a troca.
    static func troca(agenda: AgendaPlano, semana: Int, de: Int, depoisDe data: Date,
                      forca: EstadoForcaAnilha, calendario: Calendar) -> CorrecaoPlano? {
        guard de < 6 else { return nil }
        for para in (de + 1)...6 {
            guard agenda.status(semana: semana, dia: para) == .planejada else { continue }
            if let outro = agenda.sessao(semana: semana, dia: para), forte(outro.tipo) { continue }
            let alvo = agenda.data(semana: semana, dia: para, calendario: calendario)
            if pernaAntes(alvo, forca: forca, calendario: calendario) != nil { continue }
            let correcao = CorrecaoPlano.moverTreino(semana: semana, de: de, para: para)
            if (try? correcao.aplicar(agenda.plano)) != nil { return correcao }
        }
        return nil
    }

    /// Linha para o coach: força das últimas 48 h antes de uma corrida (só agregados).
    public static func resumoParaCoach(antesDe data: Date, forca: EstadoForcaAnilha,
                                       calendario: Calendar = CalendarioTreino.padrao()) -> String? {
        var partes: [String] = []
        for dias in 0...janelaDias {
            guard let d = calendario.date(byAdding: .day, value: -dias, to: calendario.startOfDay(for: data)) else { continue }
            for s in forca.doDia(EstadoForcaAnilha.chave(d, calendario: calendario)).feitas {
                let quando = dias == 0 ? L("no mesmo dia", "same day") : dias == 1 ? L("1 dia antes", "1 day before") : L("\(dias) dias antes", "\(dias) days before")
                let perna = s.pernas == true ? L(", perna: \(s.seriesPernas ?? 0) séries", ", legs: \(s.seriesPernas ?? 0) sets") : L(", sem perna", ", no legs")
                partes.append((s.nome ?? L("Força", "Strength")) + " (" + quando + perna + ")")
            }
        }
        return partes.isEmpty ? nil : partes.joined(separator: "; ")
    }
}
