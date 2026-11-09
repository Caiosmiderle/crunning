import Foundation

/// Textos dos avisos de voz, escritos para serem ouvidos (números por extenso quando o
/// sintetizador leria errado, como "4:15" virando hora).
public enum Fala {
    public static func duracao(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos.rounded()))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        var partes: [String] = []
        if h > 0 { partes.append(h == 1 ? L("1 hora", "1 hour") : L("\(h) horas", "\(h) hours")) }
        if m > 0 { partes.append(m == 1 ? L("1 minuto", "1 minute") : L("\(m) minutos", "\(m) minutes")) }
        if s > 0 || partes.isEmpty { partes.append(s == 1 ? L("1 segundo", "1 second") : L("\(s) segundos", "\(s) seconds")) }
        return juntar(partes)
    }

    public static func distancia(_ metros: Double) -> String {
        let m = max(0, metros)
        if m < 1000 { return L("\(Int(m.rounded())) metros", "\(Int(m.rounded())) meters") }
        let km = m / 1000
        if abs(km - km.rounded()) < 0.001 {
            let n = Int(km.rounded())
            return n == 1 ? L("1 quilômetro", "1 kilometer") : L("\(n) quilômetros", "\(n) kilometers")
        }
        if m < 10_000, Int(m.rounded()) % 100 == 0 { return L("\(Int(m.rounded())) metros", "\(Int(m.rounded())) meters") }
        return Formatador.numero(km, casas: 1) + L(" quilômetros", " kilometers")
    }

    /// "4 e 15 por quilômetro"; "5 minutos por quilômetro" quando os segundos são zero.
    /// Em inglês: "4 15 per kilometer", "4 oh 5 per kilometer" e "5 minutes per kilometer".
    public static func ritmo(_ segundosPorKm: Double, unidade: UnidadeDistancia = .quilometros) -> String {
        let total = Int((segundosPorKm * unidade.metros / 1000).rounded())
        let m = total / 60, s = total % 60
        let por = unidade == .quilometros ? L("por quilômetro", "per kilometer") : L("por milha", "per mile")
        if s == 0 { return L("\(m) minutos \(por)", "\(m) minutes \(por)") }
        return L("\(m) e \(s) \(por)", s < 10 ? "\(m) oh \(s) \(por)" : "\(m) \(s) \(por)")
    }

    public static func inicioTreino(_ nome: String) -> String {
        L("Começando: \(nome).", "Starting: \(nome).")
    }

    /// Anúncio de uma etapa nova: o que é, quanto dura e o alvo.
    public static func etapa(_ e: EtapaExecucao, unidade: UnidadeDistancia = .quilometros) -> String {
        switch e.conteudo {
        case let .exercicio(x):
            return "\(x.nome). \(medidaExercicio(x.medida)). \(x.comoFazer)"
        case let .corrida(p):
            var texto = e.nome
            if let k = e.repeticao, let n = e.totalRepeticoes, n > 1 { texto += L(" \(k) de \(n)", " \(k) of \(n)") }
            texto += ". "
            switch (e.planejado, e.medida) {
            case let (.distancia(d), .tempo(t)):
                texto += L("\(distancia(d)), cerca de \(duracao(t))", "\(distancia(d)), about \(duracao(t))")
            case let (_, .tempo(t)):
                texto += duracao(t)
            case let (_, .distancia(d)):
                texto += distancia(d)
            }
            if let faixa = e.faixa {
                let alvo = ritmo(faixa.alvo, unidade: unidade)
                texto += L(", ritmo \(alvo).", ", pace \(alvo).")
            } else {
                texto += ". \(p.intensidade.testeDaFala)"
            }
            return texto
        }
    }

    public static func medidaExercicio(_ medida: ExercicioAquecimento.Medida) -> String {
        switch medida {
        case let .tempo(t): duracao(t)
        case let .repeticoes(n, porLado): porLado ? L("\(n) de cada lado", "\(n) each side") : L("\(n) vezes", "\(n) times")
        case let .distancia(d, vezes): L("\(vezes) vezes de \(Int(d.rounded())) metros", "\(vezes) times \(Int(d.rounded())) meters")
        }
    }

    public static func contagem(_ n: Int) -> String { "\(n)" }

    public static func ritmo(_ aviso: AvisoRitmo) -> String {
        switch aviso {
        case .acelerar: L("Acelere um pouco.", "Speed up a little.")
        case .reduzir: L("Reduza um pouco.", "Slow down a little.")
        case .voltouAoRitmo: L("No ritmo.", "On pace.")
        }
    }

    public static func parcial(numero: Int, duracao d: TimeInterval) -> String {
        L("Quilômetro \(numero): \(duracao(d)).", "Kilometer \(numero): \(duracao(d)).")
    }

    public static func volta(numero: Int, duracao d: TimeInterval, distancia m: Double) -> String {
        m >= 50
            ? L("Volta \(numero): \(duracao(d)), \(distancia(m)).", "Lap \(numero): \(duracao(d)), \(distancia(m)).")
            : L("Volta \(numero): \(duracao(d)).", "Lap \(numero): \(duracao(d)).")
    }

    public static let fimTreino = L("Treino concluído. Pode seguir no seu ritmo ou deslizar para finalizar.",
                                    "Workout complete. You can keep going at your own pace or swipe to finish.")
    public static let pausa = L("Pausado.", "Paused.")
    public static let retomada = L("Retomando.", "Resuming.")

    /// "1 hora, 2 minutos e 5 segundos"; em inglês, para ouvir: "1 hour 2 minutes 5 seconds".
    static func juntar(_ partes: [String]) -> String {
        guard partes.count > 1 else { return partes.first ?? "" }
        return partes.dropLast().joined(separator: L(", ", " ")) + L(" e ", " ") + partes[partes.count - 1]
    }
}
