import CrunningCore
import SwiftUI

/// Prévia do motor de treino: monta um plano com as regras da fase 4 e mostra as
/// travas conferidas. O plano de verdade, com calendário e Hoje, chega na fase 8.
struct PreviaPlanoView: View {
    enum OpcaoObjetivo: String, CaseIterable, Identifiable {
        case cincoK, dezK, meia, maratona, condicionamento, comecar
        var id: String { rawValue }

        var objetivo: Objetivo {
            switch self {
            case .cincoK: .cincoK
            case .dezK: .dezK
            case .meia: .meia
            case .maratona: .maratona
            case .condicionamento: .condicionamento
            case .comecar: .comecarACorrer
            }
        }

        var nome: String {
            switch self {
            case .cincoK: "5 km"
            case .dezK: "10 km"
            case .meia: L("Meia maratona", "Half marathon")
            case .maratona: L("Maratona", "Marathon")
            case .condicionamento: L("Condicionamento", "General fitness")
            case .comecar: L("Começar a correr", "Start running")
            }
        }
    }

    nonisolated static var nomesDias: [String] { [L("Seg", "Mon"), L("Ter", "Tue"), L("Qua", "Wed"), L("Qui", "Thu"), L("Sex", "Fri"), L("Sáb", "Sat"), L("Dom", "Sun")] }

    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage(Preferencias.provaDistancia) var distanciaReferencia: Double = 5000
    @AppStorage(Preferencias.provaTempo) var tempoReferencia: Double = 0
    @State var opcao: OpcaoObjetivo = .dezK
    @State var semanas = 12
    @State var nivel: Nivel = .intermediario
    @State var dias: Set<Int> = [1, 3, 5, 6]
    @State var diaLongao = 6
    @State var volumeKm = 25
    @State var longaoKm = 8
    @State var plano: Plano?
    @State var analise: AnaliseIA?
    @State var analisando = false
    @State var erroAnalise: String?
    @State var tetoPercentual = 10
    /// Planos antes de cada correção aplicada (para voltar ao anterior).
    @State var historico: [Plano] = []
    @State var proposta: PropostaCorrecao?
    /// Pontos da análise cuja correção já foi aplicada.
    @State var aplicadas: Set<String> = []
    @State var mensagemCorrecao: String?
    @State var usandoPlano = false
    @Environment(EstadoApp.self) var estadoApp
    @Environment(\.modelContext) var contexto

    var body: some View {
        Form {
            Section("Objetivo") {
                Picker("Objetivo", selection: $opcao) {
                    ForEach(OpcaoObjetivo.allCases) { Text($0.nome).tag($0) }
                }
                Stepper("\(semanas) semanas", value: $semanas, in: 1...30)
                Picker("Nível", selection: $nivel) {
                    ForEach(Nivel.allCases) { Text($0.nome).tag($0) }
                }
            }

            Section {
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { dia in
                        let marcado = dias.contains(dia)
                        Button {
                            if marcado { dias.remove(dia) } else { dias.insert(dia) }
                            if !dias.contains(diaLongao), let ultimo = dias.max() { diaLongao = ultimo }
                        } label: {
                            Text(Self.nomesDias[dia])
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(marcado ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(marcado ? .isSelected : [])
                    }
                }
                Picker("Dia do longão", selection: $diaLongao) {
                    ForEach(dias.sorted(), id: \.self) { Text(Self.nomesDias[$0]).tag($0) }
                }
            } header: {
                Text("Dias disponíveis")
            }

            Section {
                Stepper("Volume atual: \(volumeKm) km por semana", value: $volumeKm, in: 0...160)
                Stepper("Maior corrida recente: \(longaoKm) km", value: $longaoKm, in: 0...45)
                Stepper("Aumento máximo por semana: \(tetoPercentual)%", value: $tetoPercentual, in: 5...20)
            } header: {
                Text("Hoje")
            } footer: {
                Text(L("A maior corrida das últimas 4 semanas limita as corridas do plano: nenhuma passa 10% dela, e ela cresce até 10% por semana. ", "The longest run of the last 4 weeks limits the runs in the plan: none goes more than 10% beyond it, and it grows by up to 10% per week. ") + (tempoReferencia > 0 ? L("Ritmos pela prova de referência de Meus ritmos.", "Paces from the reference race in My paces.") : L("Sem prova em Meus ritmos: as distâncias são estimadas pelo nível.", "No race in My paces: distances are estimated from the level.")))
            }

            Section {
                switch GeradorPlano.viabilidade(entradaAtual) {
                case .viavel:
                    Button("Gerar prévia") { gerar() }
                        .font(.headline)
                        .disabled(dias.count < 2)
                case let .curto(minimas, motivo):
                    Label(motivo, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.foraLeve)
                    Button("Usar \(minimas) semanas") { semanas = minimas }
                        .font(.headline)
                case let .naoRecomendado(motivo):
                    Label(motivo, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.foraForte)
                }
            }

            if let plano {
                let erros = ValidadorPlano.validar(plano)
                let alertas = GeradorPlano.alertas(plano)
                if !alertas.isEmpty {
                    Section("Atenção") {
                        ForEach(alertas, id: \.self) {
                            Label($0, systemImage: "exclamationmark.circle").font(.subheadline)
                        }
                    }
                }
                Section("Por que este plano?") {
                    ForEach(plano.regras, id: \.self) { Text($0).font(.subheadline) }
                }
                Section("Travas") {
                    if erros.isEmpty {
                        Label("Todas as travas conferidas", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Paleta.verdeLogo)
                        Button {
                            usandoPlano = true
                        } label: {
                            Label("Usar este plano", systemImage: "calendar.badge.plus").font(.headline)
                        }
                    } else {
                        ForEach(erros.map(\.description), id: \.self) { Text($0).foregroundStyle(Paleta.foraForte) }
                    }
                }
                Section {
                    if analisando {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("O coach está lendo o plano...").foregroundStyle(.secondary)
                        }
                    } else if let analise {
                        visaoAnalise(analise)
                    }
                    if !analisando {
                        if Chaveiro.temChave {
                            Button(analise == nil ? L("Analisar com o coach de IA", "Analyze with the AI coach") : L("Analisar de novo", "Analyze again")) {
                                Task { await analisar(plano) }
                            }
                        } else {
                            Text("Para pedir a análise, salve a sua chave em Ajustes > Coach de IA.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let erroAnalise {
                        Text(erroAnalise).font(.subheadline).foregroundStyle(Paleta.foraForte)
                    }
                } header: {
                    Text("Coach de IA")
                } footer: {
                    Text("Parecer de um treinador virtual (Claude) sobre o plano. Vai só o resumo do plano. As correções que ele propõe passam pelo motor e pelas travas, e só entram no plano se você aplicar.")
                }
                if mensagemCorrecao != nil || !historico.isEmpty {
                    Section {
                        if let mensagemCorrecao {
                            Text(mensagemCorrecao).font(.subheadline)
                        }
                        if !historico.isEmpty {
                            Button("Voltar ao anterior", systemImage: "arrow.uturn.backward") { desfazer() }
                            if analise != nil {
                                Text("O plano mudou depois da análise. Peça uma nova análise para o coach conferir a versão nova.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Correções")
                    }
                }
                Section("Semanas") {
                    ForEach(plano.semanas, id: \.numero) { semana in
                        DisclosureGroup {
                            ForEach(0..<7, id: \.self) { dia in
                                linhaDia(dia, semana.dias[dia])
                                    .contextMenu { menuDia(semana, dia: dia) }
                            }
                            if semana.fase != .polimento, plano.entrada.objetivo != .comecarACorrer {
                                HStack(spacing: 16) {
                                    Button("Aliviar semana", systemImage: "leaf") {
                                        propor(.aliviarSemana(semana: semana.numero), motivo: nil, chave: nil)
                                    }
                                    Button("Reduzir 10%", systemImage: "minus.circle") {
                                        propor(.reduzirSemana(semana: semana.numero, fator: 0.9), motivo: nil, chave: nil)
                                    }
                                }
                                .font(.subheadline)
                                .buttonStyle(.borderless)
                            }
                            Text("Toque e segure um dia para correr, salvar, trocar ou mover o treino.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } label: {
                            HStack {
                                Text("Semana \(semana.numero)").font(.body.weight(.medium))
                                Text(semana.fase.nome + (semana.alivio ? L(" · alívio", " · recovery week") : ""))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(Formatador.distancia(semana.volumeTreino, unidade: unidade, casas: 0) + (semana.temProva ? L(" + prova", " + race") : ""))
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Prévia do motor")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $proposta) { p in
            PropostaCorrecaoView(proposta: p, unidade: unidade) { aplicar(p) }
        }
        .sheet(isPresented: $usandoPlano) {
            if let plano {
                NavigationStack { UsarPlanoView(plano: plano) }
            }
        }
    }

    private var entradaAtual: EntradaPlano {
        let vdot = tempoReferencia > 0 ? Daniels.vdot(distanciaMetros: distanciaReferencia, tempoSegundos: tempoReferencia) : nil
        return EntradaPlano(
            objetivo: opcao.objetivo, semanas: semanas, nivel: nivel, diasDisponiveis: dias, diaLongao: diaLongao,
            volumeAtual: Double(volumeKm) * 1000, longaoAtual: Double(longaoKm) * 1000, vdot: vdot,
            tetoProgressao: Double(tetoPercentual) / 100
        )
    }

    private func gerar() {
        analise = nil
        erroAnalise = nil
        historico = []
        aplicadas = []
        mensagemCorrecao = nil
        withAnimation { plano = GeradorPlano.gerar(entradaAtual) }
    }

    private func analisar(_ plano: Plano) async {
        analisando = true
        erroAnalise = nil
        defer { analisando = false }
        do {
            analise = try await CoachIA.analisar(plano, alertas: GeradorPlano.alertas(plano))
        } catch {
            erroAnalise = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func rotulo(_ avaliacao: String) -> (texto: String, cor: Color) {
        switch avaliacao {
        case "boa": (L("Plano bom", "Good plan"), Paleta.verdeLogo)
        case "aceitavel": (L("Plano aceitável", "Acceptable plan"), Paleta.foraLeve)
        default: (L("Plano com problemas", "Plan with problems"), Paleta.foraForte)
        }
    }

    /// "alta", "media" e "baixa" vêm do esquema da IA (em português); na tela, no idioma do app.
    private func nomeGravidade(_ gravidade: String) -> String {
        switch gravidade {
        case "alta": L("Alta", "High")
        case "media": L("Média", "Medium")
        case "baixa": L("Baixa", "Low")
        default: gravidade.capitalized
        }
    }

    private func corGravidade(_ gravidade: String) -> Color {
        switch gravidade {
        case "alta": Paleta.foraForte
        case "media": Paleta.foraLeve
        default: Color.secondary
        }
    }

    @ViewBuilder
    private func visaoAnalise(_ analise: AnaliseIA) -> some View {
        let r = rotulo(analise.avaliacao)
        Label(r.texto, systemImage: "figure.run.circle").font(.headline).foregroundStyle(r.cor)
        Text(analise.resumo).font(.subheadline)
        ForEach(analise.pontos, id: \.self) { ponto in
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(nomeGravidade(ponto.gravidade))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(corGravidade(ponto.gravidade))
                    if !ponto.semanas.isEmpty {
                        Text(L("semana", "week") + (ponto.semanas.count > 1 ? "s " : " ") + ponto.semanas.map(String.init).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(ponto.problema).font(.subheadline)
                Text(L("Sugestão: ", "Suggestion: ") + ponto.sugestao).font(.subheadline).foregroundStyle(.secondary)
                if let correcao = ponto.correcao?.correcao {
                    if aplicadas.contains(ponto.problema) {
                        Label("Correção aplicada", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Paleta.verdeLogo)
                    } else {
                        Button {
                            propor(correcao, motivo: ponto.problema, chave: ponto.problema)
                        } label: {
                            Label(L("Ver correção: ", "See fix: ") + correcao.descricao, systemImage: "wand.and.stars")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        ForEach(analise.positivos, id: \.self) {
            Label($0, systemImage: "hand.thumbsup").font(.subheadline)
        }
    }

    // MARK: Correções

    private func propor(_ correcao: CorrecaoPlano, motivo: String?, chave: String?) {
        guard let plano else { return }
        do {
            let novo = try correcao.aplicar(plano)
            let comparacao = ComparacaoPlano(antes: plano, depois: novo)
            guard comparacao.mudouAlgo else {
                mensagemCorrecao = L("Essa correção não muda nada no plano.", "This fix does not change anything in the plan.")
                return
            }
            proposta = PropostaCorrecao(correcao: correcao, novo: novo, comparacao: comparacao, motivo: motivo, chave: chave)
        } catch {
            mensagemCorrecao = L("O motor recusou \"\(correcao.descricao)\": ", "The engine refused \"\(correcao.descricao)\": ") + Self.explicar(error)
        }
    }

    private func aplicar(_ p: PropostaCorrecao) {
        guard let atual = plano else { return }
        historico.append(atual)
        withAnimation { plano = p.novo }
        sincronizarFormulario(p.novo.entrada)
        if let chave = p.chave { aplicadas.insert(chave) }
        mensagemCorrecao = L("Aplicado: ", "Applied: ") + p.correcao.descricao + "."
        proposta = nil
    }

    private func desfazer() {
        guard let anterior = historico.popLast() else { return }
        withAnimation { plano = anterior }
        sincronizarFormulario(anterior.entrada)
        mensagemCorrecao = L("Voltou ao plano anterior.", "Back to the previous plan.")
    }

    private func sincronizarFormulario(_ e: EntradaPlano) {
        semanas = e.semanas
        nivel = e.nivel
        dias = e.diasDisponiveis
        diaLongao = e.diaLongao
        tetoPercentual = Int((e.tetoProgressao * 100).rounded())
    }

    static func explicar(_ erro: any Error) -> String {
        guard let correcao = erro as? ErroCorrecao else { return erro.localizedDescription }
        switch correcao {
        case let .inviavel(motivo), let .foraDosLimites(motivo):
            return motivo
        case let .operacao(operacao):
            switch operacao {
            case .semanaInvalida: return L("essa semana não existe no plano.", "that week does not exist in the plan.")
            case .diaInvalido: return L("dia inválido.", "invalid day.")
            case .semSessao: return L("não há treino nesse dia.", "there is no workout on that day.")
            case .semEquivalente: return L("não há treino equivalente que caiba nas travas.", "there is no equivalent workout that fits the safety limits.")
            case .naoSeAplica: return L("não se aplica a este plano.", "it does not apply to this plan.")
            case let .violaria(violacoes):
                return L("quebraria as travas (", "it would break the safety limits (") + violacoes.prefix(2).map(\.description).joined(separator: "; ") + ")."
            }
        }
    }

    @ViewBuilder
    private func menuDia(_ semana: SemanaPlano, dia: Int) -> some View {
        if let sessao = semana.dias[dia] {
            Button("Correr este treino", systemImage: "play.fill") {
                estadoApp.abrirTreino(sessao.treino)
            }
            Button("Salvar nos meus treinos", systemImage: "square.and.arrow.down") {
                contexto.insert(TreinoSalvo(treino: sessao.treino))
                try? contexto.save()
                mensagemCorrecao = L("\(sessao.treino.nome) salvo em Treinos.", "\(sessao.treino.nome) saved to Workouts.")
            }
            if sessao.treino.modeloID != nil, !sessao.ehProva {
                Button("Trocar por equivalente", systemImage: "arrow.triangle.2.circlepath") {
                    propor(.trocarTreino(semana: semana.numero, dia: dia), motivo: nil, chave: nil)
                }
            }
            Menu("Mover para", systemImage: "arrow.left.arrow.right") {
                ForEach(0..<7, id: \.self) { outro in
                    if outro != dia {
                        Button(Self.nomesDias[outro] + (semana.dias[outro] == nil ? "" : L(" (troca)", " (swap)"))) {
                            propor(.moverTreino(semana: semana.numero, de: dia, para: outro), motivo: nil, chave: nil)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func linhaDia(_ dia: Int, _ sessao: SessaoPlanejada?) -> some View {
        HStack(spacing: 10) {
            Text(Self.nomesDias[dia])
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            if let sessao {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(sessao.tipo.cor)
                    .frame(width: 6, height: 22)
                Text(sessao.treino.nome)
                    .font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Formatador.distancia(sessao.distancia, unidade: unidade, casas: 1))
                        .font(.subheadline.monospacedDigit())
                    Text(Formatador.duracao(sessao.duracao))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Descanso")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
    }
}


// MARK: - Proposta de correção

struct PropostaCorrecao: Identifiable {
    let id = UUID()
    let correcao: CorrecaoPlano
    let novo: Plano
    let comparacao: ComparacaoPlano
    let motivo: String?
    let chave: String?
}

/// Antes e depois de uma correção, semana a semana, com Aplicar e Recusar.
struct PropostaCorrecaoView: View {
    let proposta: PropostaCorrecao
    let unidade: UnidadeDistancia
    var aoAplicar: () -> Void
    @Environment(\.dismiss) var fechar

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(proposta.correcao.descricao).font(.headline)
                    if let motivo = proposta.motivo {
                        Text(motivo).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if proposta.comparacao.semanasAntes != proposta.comparacao.semanasDepois {
                    Section {
                        LabeledContent("Semanas", value: "\(proposta.comparacao.semanasAntes) → \(proposta.comparacao.semanasDepois)")
                    }
                }
                Section {
                    ForEach(proposta.comparacao.linhas) { linha in
                        HStack {
                            Text("Semana \(linha.semana)")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(km(linha.volumeAntes) + " → " + km(linha.volumeDepois))
                                    .font(.subheadline.monospacedDigit())
                                Text(L("maior corrida ", "longest run ") + km(linha.longaoAntes) + " → " + km(linha.longaoDepois))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Antes e depois")
                } footer: {
                    Text("O plano novo passou em todas as travas do motor. Depois de aplicar, dá para voltar ao anterior.")
                }
            }
            .navigationTitle("Correção proposta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Recusar") { fechar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        aoAplicar()
                        fechar()
                    }
                }
            }
        }
    }

    private func km(_ metros: Double?) -> String {
        metros.map { Formatador.distancia($0, unidade: unidade, casas: 1) } ?? "—"
    }
}
