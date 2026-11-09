import CrunningCore
import SwiftData
import SwiftUI

/// Aviso de privacidade mostrado nas telas do coach.
struct AvisoPrivacidadeCoach: View {
    var body: some View {
        Label("Vão para a IA só dados agregados do plano (volumes, treinos, esforço, se o ritmo ficou na faixa) e o que você escrever. Nunca rota, GPS, nome ou dados do Saúde.", systemImage: "lock.shield")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// Lados do ritmo dos treinos de qualidade mais recentes (para o contexto da IA).
func ladosRecentes(_ corridas: [Corrida]) -> [Bool?] {
    corridas.prefix(15).compactMap { corrida -> Bool?? in
        let r = corrida.carregarResultados()
        guard r.contains(where: { $0.tipo.ehQualidade && !$0.ehExercicio }) else { return nil }
        return .some(Adaptacao.ladoDoRitmo(r))
    }
}

// MARK: - Chat de ajustes

struct ChatCoachView: View {
    let ativo: PlanoAtivo
    @Environment(\.modelContext) var contexto
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @Query(sort: \Corrida.inicio, order: .reverse) var corridas: [Corrida]

    struct Fala: Identifiable {
        let id = UUID()
        let doCoach: Bool
        let texto: String
    }

    struct Proposta {
        let novo: Plano
        let comparacao: ComparacaoPlano
        let descricoes: [String]
    }

    @State var falas: [Fala] = []
    @State var historico: [ClienteClaude.Mensagem] = []
    @State var texto = ""
    @State var enviando = false
    @State var proposta: Proposta?
    @FocusState var focado: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { leitor in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        AvisoPrivacidadeCoach()
                        if !Chaveiro.temChave && !ClienteClaude.simulado {
                            Text("Salve a sua chave em Ajustes > Coach de IA para conversar.").foregroundStyle(Paleta.foraLeve)
                        }
                        if falas.isEmpty {
                            Text("Conte o que mudou: \"viajo semana que vem\", \"estou com a canela dolorida\", \"troca o longão para sábado\", \"a prova mudou para daqui a 10 semanas\".")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(falas) { f in balao(f) }
                        if let proposta { cartaoProposta(proposta) }
                        if enviando { ProgressView().padding(.vertical, 8) }
                        Color.clear.frame(height: 1).id("fim")
                    }
                    .padding(16)
                }
                .onChange(of: falas.count) { _, _ in withAnimation { leitor.scrollTo("fim") } }
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Escreva para o coach", text: $texto, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focado)
                    .padding(12)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button {
                    Task { await enviar() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
                }
                .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || enviando)
                .accessibilityLabel("Enviar")
            }
            .padding(12)
        }
        .background { FundoView() }
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if ativo.agenda?.anterior != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Voltar ao anterior") { voltar() }
                }
            }
        }
    }

    private func balao(_ f: Fala) -> some View {
        HStack {
            if !f.doCoach { Spacer(minLength: 40) }
            Text(f.texto)
                .padding(12)
                .background(f.doCoach ? Color.primary.opacity(0.08) : Paleta.verdeLogo.opacity(0.25),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if f.doCoach { Spacer(minLength: 40) }
        }
    }

    private func cartaoProposta(_ p: Proposta) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Proposta", systemImage: "wand.and.stars").font(.headline)
            ForEach(p.descricoes, id: \.self) { Text("• " + $0).font(.subheadline) }
            ForEach(p.comparacao.linhas.prefix(8)) { l in
                HStack {
                    Text("Semana \(l.semana)").font(.caption)
                    Spacer()
                    Text(km(l.volumeAntes) + " → " + km(l.volumeDepois)).font(.caption.monospacedDigit())
                }
            }
            if p.comparacao.linhas.count > 8 {
                Text("e mais \(p.comparacao.linhas.count - 8) semanas").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Salvar") { salvar(p) }.buttonStyle(.glass)
                Button("Ajustar") { focado = true }
                Spacer()
                Button("Recusar", role: .destructive) {
                    proposta = nil
                    falas.append(Fala(doCoach: true, texto: L("Ok, nada mudou.", "OK, nothing changed.")))
                }
            }
        }
        .padding(16)
        .cartaoVidro(raio: 20)
    }

    private func km(_ m: Double?) -> String {
        m.map { Formatador.distancia($0, unidade: unidade, casas: 1) } ?? "—"
    }

    private func enviar() async {
        guard let agenda = ativo.agenda else { return }
        let pedido = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        texto = ""
        falas.append(Fala(doCoach: false, texto: pedido))
        historico.append(ClienteClaude.Mensagem(papel: "user", texto: pedido))
        enviando = true
        defer { enviando = false }
        let contextoIA = ContextoAgendaIA(agenda: agenda, ladosRecentes: ladosRecentes(corridas))
        do {
            for tentativa in 0..<2 {
                let resposta = try await CoachChat.responder(historico, contexto: contextoIA)
                historico.append(ClienteClaude.Mensagem(papel: "assistant", texto: resposta.mensagem))
                let acoes = resposta.acoes.compactMap(\.correcao)
                guard !acoes.isEmpty else {
                    falas.append(Fala(doCoach: true, texto: resposta.mensagem))
                    proposta = nil
                    return
                }
                var plano = agenda.plano
                var falha: (CorrecaoPlano, any Error)?
                for acao in acoes {
                    do { plano = try acao.aplicar(plano) } catch { falha = (acao, error); break }
                }
                if let falha {
                    let motivo = "O motor recusou \"\(falha.0.descricao)\": " + PreviaPlanoView.explicar(falha.1)
                    if tentativa == 0 {
                        historico.append(ClienteClaude.Mensagem(papel: "user", texto: motivo + " Proponha outra mudança que caiba nas travas, ou explique que não dá."))
                        continue
                    }
                    falas.append(Fala(doCoach: true, texto: resposta.mensagem + "\n\n" + L("O motor recusou \"\(falha.0.descricao)\": ", "The engine refused \"\(falha.0.descricao)\": ") + PreviaPlanoView.explicar(falha.1) + L(" Nada mudou.", " Nothing changed.")))
                    return
                }
                falas.append(Fala(doCoach: true, texto: resposta.mensagem))
                let comparacao = ComparacaoPlano(antes: agenda.plano, depois: plano)
                proposta = comparacao.mudouAlgo ? Proposta(novo: plano, comparacao: comparacao, descricoes: acoes.map(\.descricao)) : nil
                return
            }
        } catch {
            falas.append(Fala(doCoach: true, texto: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription))
        }
    }

    private func salvar(_ p: Proposta) {
        guard var agenda = ativo.agenda else { return }
        agenda.trocarPlano(p.novo)
        ativo.agenda = agenda
        try? contexto.save()
        proposta = nil
        falas.append(Fala(doCoach: true, texto: L("Salvo. Se mudar de ideia, \"Voltar ao anterior\" desfaz.", "Saved. If you change your mind, \"Go back to the previous one\" undoes it.")))
        historico.append(ClienteClaude.Mensagem(papel: "user", texto: "Salvei a proposta."))
        historico.append(ClienteClaude.Mensagem(papel: "assistant", texto: "Combinado."))
    }

    private func voltar() {
        guard var agenda = ativo.agenda, agenda.voltarAoAnterior() else { return }
        ativo.agenda = agenda
        try? contexto.save()
        falas.append(Fala(doCoach: true, texto: L("Voltei ao plano anterior.", "Back to the previous plan.")))
    }
}

// MARK: - Revisão semanal

struct RevisaoCoachView: View {
    let ativo: PlanoAtivo
    @Environment(\.modelContext) var contexto
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage("ultimaRevisao") var ultimaRevisao = 0.0
    @Query(sort: \Corrida.inicio, order: .reverse) var corridas: [Corrida]
    @State var analise: AnaliseIA?
    @State var carregando = false
    @State var erro: String?
    @State var proposta: PropostaCorrecao?
    @State var aplicadas: Set<String> = []

    var body: some View {
        Form {
            Section {
                AvisoPrivacidadeCoach()
                Button(analise == nil ? L("Revisar meu plano agora", "Review my plan now") : L("Revisar de novo", "Review again")) { Task { await revisar() } }
                    .disabled(carregando || (!Chaveiro.temChave && !ClienteClaude.simulado))
                if carregando { HStack { ProgressView(); Text("O coach está olhando a sua semana...") } }
                if let erro { Text(erro).foregroundStyle(Paleta.foraForte) }
            } footer: {
                Text("Compara o planejado com o feito (aderência, esforço, ritmo) e propõe ajustes para as próximas semanas. Usa o Sonnet; cada revisão custa centavos.")
            }
            if let analise {
                Section("Parecer") {
                    Text(analise.resumo)
                    ForEach(analise.pontos, id: \.self) { ponto in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ponto.problema).font(.subheadline.weight(.semibold))
                            Text(ponto.sugestao).font(.subheadline).foregroundStyle(.secondary)
                            if let correcao = ponto.correcao?.correcao {
                                if aplicadas.contains(ponto.problema) {
                                    Label("Aplicada", systemImage: "checkmark.circle.fill").foregroundStyle(Paleta.verdeLogo)
                                } else {
                                    Button(L("Ver correção: ", "See fix: ") + correcao.descricao) { propor(correcao, ponto.problema) }
                                        .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                    ForEach(analise.positivos, id: \.self) { Label($0, systemImage: "hand.thumbsup").font(.subheadline) }
                }
            }
        }
        .navigationTitle("Revisão da semana")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $proposta) { p in
            PropostaCorrecaoView(proposta: p, unidade: unidade) { aplicar(p) }
        }
    }

    private func revisar() async {
        guard let agenda = ativo.agenda else { return }
        carregando = true
        erro = nil
        defer { carregando = false }
        do {
            analise = try await RevisaoCoach.revisar(ContextoAgendaIA(agenda: agenda, ladosRecentes: ladosRecentes(corridas)))
            ultimaRevisao = Date.now.timeIntervalSince1970
        } catch {
            erro = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func propor(_ correcao: CorrecaoPlano, _ chave: String) {
        guard let agenda = ativo.agenda else { return }
        do {
            let novo = try correcao.aplicar(agenda.plano)
            proposta = PropostaCorrecao(correcao: correcao, novo: novo, comparacao: ComparacaoPlano(antes: agenda.plano, depois: novo), motivo: chave, chave: chave)
        } catch {
            erro = L("O motor recusou: ", "The engine refused: ") + PreviaPlanoView.explicar(error)
        }
    }

    private func aplicar(_ p: PropostaCorrecao) {
        guard var agenda = ativo.agenda else { return }
        agenda.trocarPlano(p.novo)
        ativo.agenda = agenda
        try? contexto.save()
        if let chave = p.chave { aplicadas.insert(chave) }
        proposta = nil
    }
}

// MARK: - Plano montado com o coach

/// Cartão de opção numerado ("01", "02"...), mais claro quando escolhido.
struct CartaoNumerado: View {
    let numero: Int
    let titulo: String
    let escolhido: Bool
    var acao: () -> Void

    var body: some View {
        Button(action: acao) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: "%02d", numero)).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                Text(titulo).font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .padding(12)
            .background(escolhido ? Paleta.verdeLogo.opacity(0.25) : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(escolhido ? Paleta.verdeLogo : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(escolhido ? .isSelected : [])
    }
}

struct CriarPlanoCoachView: View {
    @AppStorage(Preferencias.provaDistancia) var distanciaReferencia: Double = 5000
    @AppStorage(Preferencias.provaTempo) var tempoReferencia: Double = 0
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @State var objetivo = "10 km"
    @State var semanas = 12
    @State var nivel = Nivel.intermediario.nome
    @State var dias: Set<Int> = [1, 3, 5, 6]
    @State var diaLongao = 6
    @State var volume = 25
    @State var maior = 8
    @State var terreno = "Plano"
    @State var lesoes = ""
    @State var montando = false
    @State var erro: String?
    @State var resultado: (plano: Plano, explicacao: String)?
    @State var usando = false

    nonisolated static var nomesDias: [String] { [L("Seg", "Mon"), L("Ter", "Tue"), L("Qua", "Wed"), L("Qui", "Thu"), L("Sex", "Fri"), L("Sáb", "Sat"), L("Dom", "Sun")] }
    let colunas = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AvisoPrivacidadeCoach()
                pergunta(L("Qual o objetivo?", "What is your goal?"))
                LazyVGrid(columns: colunas, spacing: 10) {
                    ForEach(Array(CriadorPlanoCoach.objetivos.enumerated()), id: \.offset) { i, o in
                        CartaoNumerado(numero: i + 1, titulo: Self.rotuloObjetivo(o), escolhido: objetivo == o) { objetivo = o }
                    }
                }
                Stepper("\(semanas) semanas até a prova (ou de plano)", value: $semanas, in: 1...30)
                pergunta(L("Nível", "Level"))
                LazyVGrid(columns: colunas, spacing: 10) {
                    ForEach(Array(Nivel.allCases.enumerated()), id: \.offset) { i, n in
                        CartaoNumerado(numero: i + 1, titulo: n.nome, escolhido: nivel == n.nome) { nivel = n.nome }
                    }
                }
                pergunta(L("Em que dias você pode correr?", "Which days can you run?"))
                LazyVGrid(columns: colunas, spacing: 10) {
                    ForEach(0..<7, id: \.self) { d in
                        CartaoNumerado(numero: d + 1, titulo: Self.nomesDias[d], escolhido: dias.contains(d)) {
                            if dias.contains(d) { dias.remove(d) } else { dias.insert(d) }
                            if !dias.contains(diaLongao), let ultimo = dias.max() { diaLongao = ultimo }
                        }
                    }
                }
                Picker("Dia do longão", selection: $diaLongao) {
                    ForEach(dias.sorted(), id: \.self) { Text(Self.nomesDias[$0]).tag($0) }
                }
                Stepper("Volume atual: \(volume) km por semana", value: $volume, in: 0...160)
                Stepper("Maior corrida recente: \(maior) km", value: $maior, in: 0...45)
                pergunta(L("Terreno", "Terrain"))
                LazyVGrid(columns: colunas, spacing: 10) {
                    ForEach(Array(["Plano", "Misto", "Com subidas"].enumerated()), id: \.offset) { i, t in
                        CartaoNumerado(numero: i + 1, titulo: Self.rotuloTerreno(t), escolhido: terreno == t) { terreno = t }
                    }
                }
                pergunta(L("Lesões ou limitações (opcional)", "Injuries or limitations (optional)"))
                TextField("Ex.: canelite há 2 meses, já curada", text: $lesoes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(tempoReferencia > 0 ? L("Os ritmos saem da sua prova em Meus ritmos.", "Paces come from your race in My paces.") : L("Sem prova em Meus ritmos: os treinos vão por esforço até você fazer um teste.", "No race in My paces: workouts go by effort until you do a test."))
                    .font(.footnote).foregroundStyle(.secondary)

                Button {
                    Task { await montar() }
                } label: {
                    Label(montando ? L("Montando...", "Building...") : L("Montar com o coach", "Build with the coach"), systemImage: "wand.and.stars")
                        .font(.headline)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Paleta.verdeLogo, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(montando || dias.count < 2 || (!Chaveiro.temChave && !ClienteClaude.simulado))
                if !Chaveiro.temChave && !ClienteClaude.simulado {
                    Text("Salve a sua chave em Ajustes > Coach de IA.").font(.footnote).foregroundStyle(Paleta.foraLeve)
                }
                if let erro { Text(erro).foregroundStyle(Paleta.foraForte) }

                if let resultado {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(resultado.explicacao).font(.subheadline)
                        ForEach(resultado.plano.semanas, id: \.numero) { s in
                            HStack {
                                Text(L("Semana \(s.numero) · \(s.fase.nome)", "Week \(s.numero) · \(s.fase.nome)") + (s.alivio ? L(" · alívio", " · recovery week") : "")).font(.caption)
                                Spacer()
                                Text(Formatador.distancia(s.volumeTreino, unidade: unidade, casas: 0)).font(.caption.monospacedDigit())
                            }
                        }
                        Button("Usar este plano") { usando = true }
                            .buttonStyle(.glass)
                    }
                    .padding(16)
                    .cartaoVidro(raio: 22)
                }
            }
            .padding(20)
        }
        .background { FundoView() }
        .navigationTitle("Plano com o coach")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $usando) {
            if let resultado { NavigationStack { UsarPlanoView(plano: resultado.plano) } }
        }
    }

    private func pergunta(_ texto: String) -> some View {
        Text(texto).font(.headline)
    }

    /// Nome do objetivo na tela. O valor guardado (comparado no motor e mandado à IA) continua em português.
    static func rotuloObjetivo(_ objetivo: String) -> String {
        switch objetivo {
        case "Meia maratona": L("Meia maratona", "Half marathon")
        case "Maratona": L("Maratona", "Marathon")
        case "Condicionamento": L("Condicionamento", "General fitness")
        case "Começar a correr": L("Começar a correr", "Start running")
        default: objetivo
        }
    }

    /// Nome do terreno na tela. O valor guardado (mandado à IA) continua em português.
    static func rotuloTerreno(_ terreno: String) -> String {
        switch terreno {
        case "Plano": L("Plano", "Flat")
        case "Misto": L("Misto", "Mixed")
        case "Com subidas": L("Com subidas", "Hilly")
        default: terreno
        }
    }

    private func montar() async {
        montando = true
        erro = nil
        defer { montando = false }
        let q = QuestionarioPlano(
            objetivo: objetivo, semanas: semanas, nivel: nivel, dias: dias.sorted(), diaLongao: diaLongao,
            volumeAtualKm: volume, maiorCorridaRecenteKm: maior, terreno: terreno,
            lesoesELimitacoes: lesoes, temProvaDeReferencia: tempoReferencia > 0
        )
        let vdot = tempoReferencia > 0 ? Daniels.vdot(distanciaMetros: distanciaReferencia, tempoSegundos: tempoReferencia) : nil
        do {
            resultado = try await CriadorPlanoCoach.montar(q, vdot: vdot)
        } catch {
            erro = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Avaliação do coach (modo de desenvolvimento)

/// Roda 4 casos fixos pelo coach de verdade (a sua chave) e mostra o resultado ao lado do que
/// se espera, para julgar a qualidade. Os planos dos casos são fictícios.
struct AvaliacaoCoachView: View {
    struct Caso: Identifiable {
        let id: Int
        let nome: String
        let esperado: String
    }

    static let casos = [
        Caso(id: 0, nome: L("5 km para iniciante", "5 km for a beginner"),
             esperado: L("Plano de 5 km nível iniciante, 3 dias, volume baixo, aumento de no máximo 10% por semana (ou menos).",
                         "Beginner 5 km plan, 3 days, low volume, increase of at most 10% per week (or less).")),
        Caso(id: 1, nome: L("Meia maratona em 16 semanas", "Half marathon in 16 weeks"),
             esperado: L("16 semanas, 4 dias, longão no domingo, teto de 10%; explicação curta.",
                         "16 weeks, 4 days, long run on Sunday, 10% cap; short explanation.")),
        Caso(id: 2, nome: L("Volta de lesão", "Coming back from injury"),
             esperado: L("Proposta de \"retomar_apos_pausa\" com 21 dias parado, sem treino por cima de dor; orientação de procurar profissional se doer.",
                         "A \"retomar_apos_pausa\" proposal with 21 days off, no training through pain; advice to see a professional if it hurts.")),
        Caso(id: 3, nome: L("Semana de viagem", "Travel week"),
             esperado: L("Alívio ou redução da semana que vem; nada nas semanas passadas.",
                         "Recovery week or reduction for next week; nothing in past weeks.")),
    ]

    @State var resultados: [Int: String] = [:]
    @State var rodando = false
    @State var confirmando = false

    var body: some View {
        Form {
            Section {
                Text("Usa a sua chave: 2 chamadas ao Sonnet e 2 ao Haiku, alguns centavos de dólar. Com \"Simular o coach\" ligado, roda sem gastar.")
                    .font(.footnote)
                Button(rodando ? L("Rodando...", "Running...") : L("Rodar os 4 casos", "Run the 4 cases")) { confirmando = true }
                    .disabled(rodando || (!Chaveiro.temChave && !ClienteClaude.simulado))
            }
            ForEach(Self.casos) { caso in
                Section(caso.nome) {
                    Text(L("Esperado: ", "Expected: ") + caso.esperado).font(.footnote).foregroundStyle(.secondary)
                    Text(resultados[caso.id] ?? "—").font(.subheadline)
                }
            }
        }
        .navigationTitle("Avaliar o coach")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Rodar os 4 casos com a sua chave?", isPresented: $confirmando, titleVisibility: .visible) {
            Button("Rodar") { Task { await rodar() } }
        } message: {
            Text("Custa alguns centavos na sua conta da Anthropic.")
        }
    }

    private func rodar() async {
        rodando = true
        defer { rodando = false }
        resultados = [:]
        let questionarios = [
            QuestionarioPlano(objetivo: "5 km", semanas: 10, nivel: Nivel.iniciante.nome, dias: [1, 3, 6], diaLongao: 6, volumeAtualKm: 8,
                              maiorCorridaRecenteKm: 3, terreno: "Plano", lesoesELimitacoes: "", temProvaDeReferencia: false),
            QuestionarioPlano(objetivo: "Meia maratona", semanas: 16, nivel: Nivel.intermediario.nome, dias: [1, 3, 5, 6], diaLongao: 6, volumeAtualKm: 30,
                              maiorCorridaRecenteKm: 12, terreno: "Misto", lesoesELimitacoes: "", temProvaDeReferencia: true),
        ]
        for (i, q) in questionarios.enumerated() {
            do {
                let r = try await CriadorPlanoCoach.montar(q, vdot: 45)
                let semanas = r.plano.semanas.count
                let pico = r.plano.semanas.map(\.volumeTreino).max() ?? 0
                resultados[i] = r.explicacao + L("\n\n\(semanas) semanas, \(r.plano.entrada.nivel.nome), teto \(Int((r.plano.entrada.tetoProgressao * 100).rounded()))%, pico ", "\n\n\(semanas) weeks, \(r.plano.entrada.nivel.nome), cap \(Int((r.plano.entrada.tetoProgressao * 100).rounded()))%, peak ") + Formatador.distancia(pico, casas: 0) + "."
            } catch {
                resultados[i] = L("Erro: ", "Error: ") + ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
        let plano = GeradorPlano.gerar(EntradaPlano(objetivo: .dezK, semanas: 12, nivel: .intermediario, diasDisponiveis: [1, 3, 5, 6],
                                                    diaLongao: 6, volumeAtual: 30_000, longaoAtual: 10_000, vdot: 45))
        let agenda = AgendaPlano(plano: plano, inicio: CalendarioTreino.inicioDaSemana(Calendar.current.date(byAdding: .day, value: -21, to: .now) ?? .now))
        let contexto = ContextoAgendaIA(agenda: agenda, ladosRecentes: [])
        let pedidos = [
            "Fiquei 3 semanas parado com canelite. Já estou sem dor e quero voltar.",
            "Viajo na semana que vem e só vou conseguir correr duas vezes.",
        ]
        for (k, pedido) in pedidos.enumerated() {
            do {
                let r = try await CoachChat.responder([ClienteClaude.Mensagem(papel: "user", texto: pedido)], contexto: contexto)
                let acoes = r.acoes.compactMap(\.correcao)
                var plano2 = plano
                var situacao = acoes.isEmpty ? L("sem ações", "no actions") : L("aceitas pelo motor", "accepted by the engine")
                for a in acoes {
                    do { plano2 = try a.aplicar(plano2) } catch { situacao = L("recusada: ", "refused: ") + PreviaPlanoView.explicar(error); break }
                }
                resultados[2 + k] = r.mensagem + L("\n\nAções: ", "\n\nActions: ") + (acoes.isEmpty ? L("nenhuma", "none") : acoes.map(\.descricao).joined(separator: "; ")) + " (\(situacao))."
            } catch {
                resultados[2 + k] = L("Erro: ", "Error: ") + ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }
}
