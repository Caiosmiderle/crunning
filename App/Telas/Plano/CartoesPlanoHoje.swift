import CrunningCore
import SwiftData
import SwiftUI

/// Hoje com plano: o treino do dia, o check-in dos treinos que ficaram para trás e as
/// propostas de adaptação (Adaptacao). Nada muda no plano sem o seu OK.
struct CartoesPlanoHoje: View {
    let ativo: PlanoAtivo
    @Binding var aba: Aba
    @Environment(EstadoApp.self) var estadoApp
    @Environment(\.modelContext) var contexto
    @Query(sort: \Corrida.inicio, order: .reverse) var corridas: [Corrida]
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage("alivioDispensadoEm") var alivioDispensadoEm = 0.0
    @AppStorage("ritmoDispensadoEm") var ritmoDispensadoEm = 0.0
    @AppStorage("ultimaRevisao") var ultimaRevisao = 0.0
    @State var proposta: PropostaCorrecao?
    @State var mensagem: String?
    @State var diasParado = 7
    @State var perguntandoPausa = false
    @State var perguntandoSaude = false
    @State var febre = false
    @State var abaixoDoPescoco = false
    @State var dorMudaPassada = false
    @State var dorPersiste = false

    var body: some View {
        if let agenda = ativo.agenda {
            VStack(spacing: 16) {
                treinoDoDia(agenda)
                let pendentes = agenda.pendentes(hoje: .now)
                if !pendentes.isEmpty { checkin(agenda, pendentes) }
                if let alivio = propostaDeAlivio(agenda) { cartaoAlivio(agenda, alivio) }
                if let ritmo = avisoDeRitmo() { cartaoRitmo(ritmo) }
                if horaDeRevisar { cartaoRevisao }
                if let mensagem {
                    Text(mensagem).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .sheet(item: $proposta) { p in
                PropostaCorrecaoView(proposta: p, unidade: unidade) { aplicar(p, marcandoPendentes: agenda.pendentes(hoje: .now)) }
            }
            .sheet(isPresented: $perguntandoPausa) { folhaPausa(agenda) }
            .sheet(isPresented: $perguntandoSaude) { folhaSaude }
        }
    }

    // MARK: Treino do dia

    @ViewBuilder
    private func treinoDoDia(_ agenda: AgendaPlano) -> some View {
        let hoje = Date.now
        VStack(alignment: .leading, spacing: 10) {
            Label("Treino de hoje", systemImage: "figure.run")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            if let p = agenda.posicao(de: hoje) {
                if let sessao = agenda.sessao(semana: p.semana, dia: p.dia) {
                    HStack {
                        Circle().fill(sessao.tipo.cor).frame(width: 12, height: 12)
                        Text(sessao.treino.nome).font(.title2.weight(.semibold))
                    }
                    Text(Formatador.distancia(sessao.distancia, unidade: unidade, casas: 1) + " · " + Formatador.duracao(sessao.duracao) + " · semana \(p.semana)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    LinhaDoTempoTreino(blocos: sessao.treino.blocos, zonas: ZonasDoUsuario.atuais(), altura: 28)
                    if let porque = sessao.treino.modeloID.flatMap({ Modelos.modelo(id: $0)?.porque }) {
                        Text(porque).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if agenda.status(semana: p.semana, dia: p.dia) == .feita {
                        Label("Feito", systemImage: "checkmark.circle.fill").foregroundStyle(Paleta.verdeLogo).font(.headline)
                    } else {
                        Button {
                            estadoApp.abrirTreino(sessao.treino, plano: (p.semana, p.dia))
                        } label: {
                            Label("Começar treino", systemImage: "play.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(Paleta.verdeLogo, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Descanso").font(.title2.weight(.semibold))
                    Text(proximo(agenda, depois: p)).font(.subheadline).foregroundStyle(.secondary)
                }
            } else if hoje < agenda.inicio {
                Text("O plano começa em " + agenda.inicio.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.ptBR)) + ".")
                    .font(.title3.weight(.semibold))
            } else {
                Text("O plano terminou.").font(.title3.weight(.semibold))
                Text("Monte o próximo na aba Plano > Prévia.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }

    private func proximo(_ agenda: AgendaPlano, depois p: (semana: Int, dia: Int)) -> String {
        var semana = p.semana, dia = p.dia
        for _ in 0..<14 {
            dia += 1
            if dia > 6 { dia = 0; semana += 1 }
            if let s = agenda.sessao(semana: semana, dia: dia) {
                let quando = agenda.data(semana: semana, dia: dia).formatted(.dateTime.weekday(.wide).locale(.ptBR))
                return "Próximo: \(s.treino.nome), \(quando)."
            }
        }
        return ""
    }

    // MARK: Check-in

    private func checkin(_ agenda: AgendaPlano, _ pendentes: [(semana: Int, dia: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Ficou para trás", systemImage: "questionmark.circle")
                .font(.headline)
            ForEach(Array(pendentes.enumerated()), id: \.offset) { _, p in
                if let s = agenda.sessao(semana: p.semana, dia: p.dia) {
                    Text(agenda.data(semana: p.semana, dia: p.dia).formatted(.dateTime.weekday(.wide).locale(.ptBR)) + ": " + s.treino.nome)
                        .font(.subheadline)
                }
            }
            Text("O que houve?").font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                botao("Fiz sem o app") { marcarTodos(pendentes, .feita) }
                botao("Perdi, sigo o plano") {
                    marcarTodos(pendentes, .perdida)
                    mensagem = Adaptacao.avaliar(.perdeuTreino).mensagem
                }
                botao("Fiquei parado") {
                    diasParado = max(6, pendentes.count * 2)
                    perguntandoPausa = true
                }
                botao("Doente ou com dor") { perguntandoSaude = true }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }

    private func botao(_ titulo: String, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(titulo)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func marcarTodos(_ pendentes: [(semana: Int, dia: Int)], _ status: StatusSessao) {
        guard var agenda = ativo.agenda else { return }
        for p in pendentes { agenda.marcar(semana: p.semana, dia: p.dia, status) }
        ativo.agenda = agenda
        try? contexto.save()
    }

    private func folhaPausa(_ agenda: AgendaPlano) -> some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("\(diasParado) dias sem correr", value: $diasParado, in: 1...120)
                } footer: {
                    Text(Adaptacao.avaliar(.ausencia(dias: diasParado)).mensagem)
                }
            }
            .navigationTitle("Quanto tempo parado?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { perguntandoPausa = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(diasParado > 5 ? "Ver proposta" : "OK") {
                        perguntandoPausa = false
                        let pendentes = agenda.pendentes(hoje: .now)
                        guard diasParado > 5, let p = agenda.posicao(de: .now) else {
                            marcarTodos(pendentes, .perdida)
                            mensagem = Adaptacao.avaliar(.ausencia(dias: diasParado)).mensagem
                            return
                        }
                        propor(.retomarAposPausa(semana: p.semana, dias: diasParado), agenda, motivo: Adaptacao.avaliar(.ausencia(dias: diasParado)).mensagem)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var folhaSaude: some View {
        NavigationStack {
            Form {
                Section("Doença") {
                    Toggle("Febre", isOn: $febre)
                    Toggle("Sintomas abaixo do pescoço (peito, corpo, estômago)", isOn: $abaixoDoPescoco)
                    Text(Adaptacao.avaliar(.doenca(febre: febre, sintomasAbaixoDoPescoco: abaixoDoPescoco)).mensagem)
                        .font(.subheadline)
                }
                Section("Dor") {
                    Toggle("A dor muda a minha passada", isOn: $dorMudaPassada)
                    Toggle("A dor continua depois do aquecimento ou no dia seguinte", isOn: $dorPersiste)
                    Text(Adaptacao.avaliar(.dor(mudaAPassada: dorMudaPassada, persiste: dorPersiste)).mensagem)
                        .font(.subheadline)
                }
                Section {
                    Text("Quando voltar, use \"Fiquei parado\" com os dias sem correr: o plano recomeça aos poucos. O CRUNNING não é aconselhamento médico.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Doente ou com dor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { perguntandoSaude = false } }
            }
        }
    }

    // MARK: Revisão semanal

    /// Domingo a partir das 17 h ou segunda, se não houve revisão nos últimos 3 dias.
    private var horaDeRevisar: Bool {
        let agora = Date.now
        let c = Calendar.current.dateComponents([.weekday, .hour], from: agora)
        let momento = (c.weekday == 1 && (c.hour ?? 0) >= 17) || c.weekday == 2
        return momento && agora.timeIntervalSince1970 - ultimaRevisao > 3 * 86_400
    }

    private var cartaoRevisao: some View {
        NavigationLink {
            RevisaoCoachView(ativo: ativo)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checklist").font(.title2).foregroundStyle(Paleta.verdeLogo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hora de revisar a semana").font(.headline)
                    Text("O coach compara o planejado com o feito e propõe ajustes.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoVidro()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Adaptação

    private func propostaDeAlivio(_ agenda: AgendaPlano) -> Recomendacao? {
        guard let p = agenda.posicao(de: .now), p.semana <= agenda.plano.semanas.count else { return nil }
        let semana = agenda.plano.semanas[p.semana - 1]
        guard !semana.alivio, semana.fase != .polimento, agenda.plano.entrada.objetivo != .comecarACorrer else { return nil }
        let inicioSemana = agenda.data(semana: p.semana, dia: 0).timeIntervalSince1970
        guard alivioDispensadoEm < inicioSemana else { return nil }
        let esforcos = agenda.esforcosRecentesEmFaceis(ate: .now)
        guard esforcos.count >= 2 else { return nil }
        let r = Adaptacao.avaliar(.esforcoAltoEmFaceis(seguidas: 2, esforco: min(esforcos[0], esforcos[1])))
        if case .proporAlivio = r { return r }
        return nil
    }

    private func cartaoAlivio(_ agenda: AgendaPlano, _ r: Recomendacao) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Corridas fáceis pesadas", systemImage: "leaf")
                .font(.headline)
            Text(r.mensagem).font(.subheadline)
            HStack {
                Button("Ver proposta") {
                    if let p = agenda.posicao(de: .now) { propor(.aliviarSemana(semana: p.semana), agenda, motivo: r.mensagem) }
                }
                .buttonStyle(.glass)
                Button("Agora não") { alivioDispensadoEm = Date.now.timeIntervalSince1970 }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }

    /// Últimos treinos de qualidade gravados com blocos: todos fora da faixa para o mesmo lado?
    private func avisoDeRitmo() -> Recomendacao? {
        let comBlocos = corridas.prefix(20).filter { $0.inicio.timeIntervalSince1970 > ritmoDispensadoEm }
        let lados: [Bool?] = comBlocos.compactMap { corrida in
            let resultados = corrida.carregarResultados()
            guard resultados.contains(where: { $0.tipo.ehQualidade && !$0.ehExercicio }) else { return nil }
            return .some(Adaptacao.ladoDoRitmo(resultados))
        }
        guard let fora = Adaptacao.foraDoRitmoSeguidos(lados) else { return nil }
        let r = Adaptacao.avaliar(.foraDoRitmo(treinosSeguidos: fora.seguidos, maisRapido: fora.maisRapido))
        if case .perguntarAjusteDeRitmos = r { return r }
        return nil
    }

    private func cartaoRitmo(_ r: Recomendacao) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Ritmos", systemImage: "speedometer").font(.headline)
            Text(r.mensagem).font(.subheadline)
            Text("O jeito mais confiável é um teste novo (Treinos > Prontos > Teste de 3 km) ou uma prova recente em Ajustes > Meus ritmos.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button("Fazer um teste") { aba = .treinos }
                    .buttonStyle(.glass)
                Button("Agora não") { ritmoDispensadoEm = Date.now.timeIntervalSince1970 }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }

    private func propor(_ correcao: CorrecaoPlano, _ agenda: AgendaPlano, motivo: String?) {
        do {
            let novo = try correcao.aplicar(agenda.plano)
            proposta = PropostaCorrecao(correcao: correcao, novo: novo, comparacao: ComparacaoPlano(antes: agenda.plano, depois: novo),
                                        motivo: motivo, chave: nil)
        } catch {
            mensagem = "O motor recusou: " + PreviaPlanoView.explicar(error)
        }
    }

    private func aplicar(_ p: PropostaCorrecao, marcandoPendentes pendentes: [(semana: Int, dia: Int)]) {
        guard var agenda = ativo.agenda else { return }
        agenda.trocarPlano(p.novo)
        if case .retomarAposPausa = p.correcao {
            for q in pendentes { agenda.marcar(semana: q.semana, dia: q.dia, .perdida) }
        }
        ativo.agenda = agenda
        try? contexto.save()
        mensagem = "Aplicado: " + p.correcao.descricao + "."
        proposta = nil
    }
}
