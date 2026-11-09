import Foundation

/// Textos dos avisos de voz, escritos para serem ouvidos (números por extenso quando o
/// sintetizador leria errado, como "4:15" virando hora).
public enum Fala {
    public static func duracao(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos.rounded()))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        var partes: [String] = []
        if h > 0 { partes.append(h == 1 ? "1 hora" : "\(h) horas") }
        if m > 0 { partes.append(m == 1 ? "1 minuto" : "\(m) minutos") }
        if s > 0 || partes.isEmpty { partes.append(s == 1 ? "1 segundo" : "\(s) segundos") }
        return juntar(partes)
    }

    public static func distancia(_ metros: Double) -> String {
        let m = max(0, metros)
        if m < 1000 { return "\(Int(m.rounded())) metros" }
        let km = m / 1000
        if abs(km - km.rounded()) < 0.001 {
            let n = Int(km.rounded())
            return n == 1 ? "1 quilômetro" : "\(n) quilômetros"
        }
        if m < 10_000, Int(m.rounded()) % 100 == 0 { return "\(Int(m.rounded())) metros" }
        return Formatador.numero(km, casas: 1) + " quilômetros"
    }

    /// "4 e 15 por quilômetro"; "5 minutos por quilômetro" quando os segundos são zero.
    public static func ritmo(_ segundosPorKm: Double, unidade: UnidadeDistancia = .quilometros) -> String {
        let total = Int((segundosPorKm * unidade.metros / 1000).rounded())
        let m = total / 60, s = total % 60
        let por = unidade == .quilometros ? "por quilômetro" : "por milha"
        return s == 0 ? "\(m) minutos \(por)" : "\(m) e \(s) \(por)"
    }

    public static func inicioTreino(_ nome: String) -> String {
        "Começando: \(nome)."
    }

    /// Anúncio de uma etapa nova: o que é, quanto dura e o alvo.
    public static func etapa(_ e: EtapaExecucao, unidade: UnidadeDistancia = .quilometros) -> String {
        switch e.conteudo {
        case let .exercicio(x):
            return "\(x.nome). \(medidaExercicio(x.medida)). \(x.comoFazer)"
        case let .corrida(p):
            var texto = e.nome
            if let k = e.repeticao, let n = e.totalRepeticoes, n > 1 { texto += " \(k) de \(n)" }
            texto += ". "
            switch (e.planejado, e.medida) {
            case let (.distancia(d), .tempo(t)):
                texto += "\(distancia(d)), cerca de \(duracao(t))"
            case let (_, .tempo(t)):
                texto += duracao(t)
            case let (_, .distancia(d)):
                texto += distancia(d)
            }
            if let faixa = e.faixa {
                texto += ", ritmo \(ritmo(faixa.alvo, unidade: unidade))."
            } else {
                texto += ". \(p.intensidade.testeDaFala)"
            }
            return texto
        }
    }

    public static func medidaExercicio(_ medida: ExercicioAquecimento.Medida) -> String {
        switch medida {
        case let .tempo(t): duracao(t)
        case let .repeticoes(n, porLado): porLado ? "\(n) de cada lado" : "\(n) vezes"
        case let .distancia(d, vezes): "\(vezes) vezes de \(Int(d.rounded())) metros"
        }
    }

    public static func contagem(_ n: Int) -> String { "\(n)" }

    public static func ritmo(_ aviso: AvisoRitmo) -> String {
        switch aviso {
        case .acelerar: "Acelere um pouco."
        case .reduzir: "Reduza um pouco."
        case .voltouAoRitmo: "No ritmo."
        }
    }

    public static func parcial(numero: Int, duracao d: TimeInterval) -> String {
        "Quilômetro \(numero): \(duracao(d))."
    }

    public static func volta(numero: Int, duracao d: TimeInterval, distancia m: Double) -> String {
        m >= 50 ? "Volta \(numero): \(duracao(d)), \(distancia(m))." : "Volta \(numero): \(duracao(d))."
    }

    public static let fimTreino = "Treino concluído. Pode seguir no seu ritmo ou deslizar para finalizar."
    public static let pausa = "Pausado."
    public static let retomada = "Retomando."

    static func juntar(_ partes: [String]) -> String {
        guard partes.count > 1 else { return partes.first ?? "" }
        return partes.dropLast().joined(separator: ", ") + " e " + partes[partes.count - 1]
    }
}
