import CrunningCore
import Foundation
import SwiftUI

/// A seleção guarda o item completo apenas para apresentação local.
enum TreinoForcaAnilha: Identifiable {
    case feita(SessaoForcaAnilha)
    case prevista(ForcaPlanejadaAnilha)

    var id: String {
        switch self {
        case .feita(let s): "feita-\(s.origemID)"
        case .prevista(let p): "prevista-\(p.dataLocal)-\(p.fichaID ?? p.nome)"
        }
    }

    var nome: String {
        switch self {
        case .feita(let s): s.nome ?? L("Treino de força", "Strength workout")
        case .prevista(let p): p.nome
        }
    }

    var estado: String {
        switch self {
        case .feita(let s): s.status == "parcial" ? L("parcial", "partial") : L("feito", "done")
        case .prevista: L("previsto", "planned")
        }
    }

    var pernas: Bool {
        switch self {
        case .feita(let s): s.pernas == true
        case .prevista(let p): p.pernas
        }
    }

    var url: URL? {
        switch self {
        case .feita(let s): LinkForcaAnilha.url(s.link)
        case .prevista(let p): LinkForcaAnilha.url(p.link)
        }
    }
}

struct DetalheForcaAnilhaView: View {
    let treino: TreinoForcaAnilha
    let data: Date
    @Environment(\.dismiss) private var fechar
    @Environment(\.openURL) private var abrirURL
    @State private var falhouAoAbrir = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    cabecalho
                    switch treino {
                    case .feita(let sessao):
                        let exercicios = sessao.exercicios ?? []
                        if exercicios.isEmpty {
                            semDetalhes
                        } else {
                            let total = exercicios.reduce(0) { $0 + $1.series.filter { $0.tipo == "trabalho" }.count }
                            Text(L("\(total) séries de trabalho", "\(total) working sets"))
                                .font(.headline)
                            ForEach(Array(exercicios.enumerated()), id: \.offset) { _, exercicio in
                                exercicioFeito(exercicio)
                            }
                        }
                    case .prevista(let prevista):
                        let exercicios = prevista.exercicios ?? []
                        if exercicios.isEmpty {
                            semDetalhes
                        } else {
                            ForEach(Array(exercicios.enumerated()), id: \.offset) { _, exercicio in
                                exercicioPrevisto(exercicio)
                            }
                        }
                    }
                    if let url = treino.url {
                        Button(L("Abrir no Anilha", "Open in Anilha")) {
                            falhouAoAbrir = false
                            abrirURL(url) { aceito in
                                falhouAoAbrir = !aceito
                            }
                        }
                        .buttonStyle(.glassProminent)
                    }
                    if falhouAoAbrir {
                        Text(L("Não consegui abrir o Anilha. Ele está instalado neste iPhone?",
                               "Couldn't open Anilha. Is it installed on this iPhone?"))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle(L("Força no Anilha", "Strength in Anilha"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Fechar", "Close")) { fechar() }
                }
            }
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(treino.nome).font(.title2.weight(.semibold))
            Text(data.formatted(date: .long, time: .omitted))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text(treino.estado)
                if treino.pernas {
                    Text(L("perna", "legs"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForcaDoDia.corPerna)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ForcaDoDia.corPerna.opacity(0.15), in: Capsule())
                }
            }
            if case .feita(let sessao) = treino, let duracao = sessao.duracaoS {
                Text(L("Duração: ", "Duration: ") + Formatador.duracao(Double(duracao)))
                    .accessibilityLabel(L("Duração: ", "Duration: ") + Fala.duracao(Double(duracao)))
            }
        }
    }

    private var semDetalhes: some View {
        Text(L("Detalhes aparecem quando o Anilha atualizar.", "Details will appear when Anilha updates."))
            .foregroundStyle(.secondary)
    }

    private func nomeExercicio(_ nome: String, grupo: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nome).font(.headline)
            if let grupo = nomeGrupo(grupo) {
                Text(grupo).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func exercicioFeito(_ exercicio: ExercicioFeitoAnilha) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            nomeExercicio(exercicio.nome, grupo: exercicio.grupo)
            ForEach(Array(exercicio.series.enumerated()), id: \.offset) { _, serie in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(textoSerie(serie)).monospacedDigit()
                    if serie.tipo == "aquecimento" {
                        Text(L("aquecimento", "warm-up")).font(.caption)
                    }
                }
                .foregroundStyle(serie.tipo == "aquecimento" ? Color.secondary : Color.primary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(falaSerie(serie))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro(raio: 20)
    }

    private func exercicioPrevisto(_ exercicio: ExercicioPrevistoAnilha) -> some View {
        let reps = faixaReps(exercicio)
        return VStack(alignment: .leading, spacing: 10) {
            nomeExercicio(exercicio.nome, grupo: exercicio.grupo)
            Text(reps.map { "\(exercicio.series) × \($0)" } ?? L("\(exercicio.series) séries", "\(exercicio.series) sets"))
                .monospacedDigit()
                .accessibilityLabel(L("\(exercicio.series) séries", "\(exercicio.series) sets") +
                    (reps.map { _ in L(", \(falaReps(exercicio)) repetições", ", \(falaReps(exercicio)) repetitions") } ?? ""))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro(raio: 20)
    }

    private func nomeGrupo(_ grupo: String?) -> String? {
        switch grupo {
        case "costas": L("Costas", "Back")
        case "peito": L("Peito", "Chest")
        case "pernas": L("Pernas", "Legs")
        case "ombros": L("Ombros", "Shoulders")
        case "bracos": L("Braços", "Arms")
        case "core": L("Core", "Core")
        default: nil
        }
    }

    private func numero(_ valor: Double) -> String {
        let formato = NumberFormatter()
        formato.locale = Locale(identifier: "pt_BR")
        formato.numberStyle = .decimal
        formato.minimumFractionDigits = 0
        formato.maximumFractionDigits = 1
        return formato.string(from: NSNumber(value: valor)) ?? "0"
    }

    private func textoSerie(_ serie: SerieAnilha) -> String {
        if let segundos = serie.segundos { return "\(segundos) s" }
        let carga = serie.cargaKg.map { numero($0) + " kg" }
        if let reps = serie.reps {
            return (carga.map { $0 + " " } ?? "") + "× \(reps)"
        }
        return carga ?? L("Sem registro", "Not recorded")
    }

    private func falaSerie(_ serie: SerieAnilha) -> String {
        var partes: [String] = []
        if serie.tipo == "aquecimento" { partes.append(L("aquecimento", "warm-up")) }
        if let segundos = serie.segundos {
            partes.append(L("\(segundos) segundos", "\(segundos) seconds"))
        } else {
            if let carga = serie.cargaKg { partes.append(L("\(numero(carga)) quilos", "\(numero(carga)) kilograms")) }
            if let reps = serie.reps { partes.append(L("\(reps) repetições", "\(reps) repetitions")) }
            if serie.cargaKg == nil && serie.reps == nil { partes.append(L("Sem registro", "Not recorded")) }
        }
        return partes.joined(separator: ", ")
    }

    private func faixaReps(_ exercicio: ExercicioPrevistoAnilha) -> String? {
        if let min = exercicio.repsMin, let max = exercicio.repsMax, min != max { return "\(min)–\(max)" }
        return (exercicio.repsMin ?? exercicio.repsMax).map { "\($0)" }
    }

    private func falaReps(_ exercicio: ExercicioPrevistoAnilha) -> String {
        if let min = exercicio.repsMin, let max = exercicio.repsMax, min != max { return L("\(min) a \(max)", "\(min) to \(max)") }
        return (exercicio.repsMin ?? exercicio.repsMax).map { "\($0)" } ?? ""
    }
}
