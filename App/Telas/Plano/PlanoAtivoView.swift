import CrunningCore
import SwiftData
import SwiftUI

/// O plano em uso: semana a semana no calendário, com o que foi feito, mover treino,
/// marcar feito ou perdido, nova data de prova, PDF e encerrar.
struct PlanoAtivoView: View {
    let ativo: PlanoAtivo
    @Environment(EstadoApp.self) var estadoApp
    @Environment(\.modelContext) var contexto
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @State var semanaVista: Int?
    @State var proposta: PropostaCorrecao?
    @State var mensagem: String?
    @State var mudandoProva = false
    @State var semanasRestantes = 8
    @State var confirmandoEncerrar = false
    @State var arquivoPDF: URL?
    @AppStorage(Preferencias.sincronizarCalendario) var sincronizar = false
    @State var adicionandoProva = false
    @State var provaSemana = 1
    @State var provaDia = 5
    @State var provaKm = 5.0
    /// Calendário do mês inteiro em vez da semana (lembra a escolha).
    @AppStorage(PreferenciasPlano.verMes) var verMes = false
    @State var mesVisto: Date?
    @AppStorage(CartaoAvisoForca.chaveDispensados) var dispensados = ""

    nonisolated static var nomesDias: [String] { [L("Seg", "Mon"), L("Ter", "Tue"), L("Qua", "Wed"), L("Qui", "Thu"), L("Sex", "Fri"), L("Sáb", "Sat"), L("Dom", "Sun")] }

    var body: some View {
        if let agenda = ativo.agenda {
            conteudo(agenda)
        } else {
            Text("Não deu para ler o plano salvo.").foregroundStyle(.secondary)
        }
    }

    private func conteudo(_ agenda: AgendaPlano) -> some View {
        let hoje = Date.now
        let atual = agenda.posicao(de: hoje)
        let numero = min(max(semanaVista ?? atual?.semana ?? 1, 1), agenda.plano.semanas.count)
        let semana = agenda.plano.semanas[numero - 1]
        return Tela(selo: L("Semana \(numero) de \(agenda.plano.semanas.count) · \(semana.fase.nome)", "Week \(numero) of \(agenda.plano.semanas.count) · \(semana.fase.nome)") + (semana.alivio ? L(" · alívio", " · recovery week") : ""),
                    iconeSelo: "calendar", titulo: agenda.plano.entrada.objetivo.nome) {
            Picker(L("Ver", "View"), selection: $verMes) {
                Text(L("Semana", "Week")).tag(false)
                Text(L("Mês", "Month")).tag(true)
            }
            .pickerStyle(.segmented)

            ForEach(avisosForca(agenda, hoje: hoje)) { aviso in
                CartaoAvisoForca(aviso: aviso, unidade: unidade) {
                    if let s = aviso.sugestao { propor(s, agenda) }
                } manter: {
                    dispensados = (dispensados.isEmpty ? "" : dispensados + ",") + aviso.id
                }
            }

            if verMes {
                calendarioMes(agenda, hoje: hoje)
            } else {
                HStack {
                    Button { semanaVista = numero - 1 } label: { Image(systemName: "chevron.left") }
                        .disabled(numero <= 1)
                    Spacer()
                    VStack(spacing: 2) {
                        Text(intervalo(agenda, numero)).font(.subheadline.weight(.semibold))
                        Text(Formatador.distancia(semana.volumeTreino, unidade: unidade, casas: 0) + L(" planejados", " planned") + (semana.temProva ? L(" + prova", " + race") : ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { semanaVista = numero + 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(numero >= agenda.plano.semanas.count)
                }
                .font(.title3.weight(.semibold))
                .padding(14)
                .cartaoVidro(raio: 22)

                ForEach(0..<7, id: \.self) { dia in
                    diaComDetalhe(agenda, semana: numero, dia: dia, hoje: hoje)
                }
            }

            if let mensagem {
                Text(mensagem).font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                NavigationLink {
                    ChatCoachView(ativo: ativo)
                } label: {
                    Label("Conversar com o coach", systemImage: "bubble.left.and.text.bubble.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.glass)
                NavigationLink {
                    RevisaoCoachView(ativo: ativo)
                } label: {
                    Label("Revisar a semana", systemImage: "checklist")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.glass)
            }

            Menu {
                if agenda.anterior != nil {
                    Button("Voltar ao plano anterior", systemImage: "arrow.uturn.backward") {
                        var nova = agenda
                        if nova.voltarAoAnterior() {
                            ativo.agenda = nova
                            try? contexto.save()
                            mensagem = L("Voltou ao plano de antes da última mudança.", "Back to the plan from before the last change.")
                        }
                    }
                }
                Button(sincronizar ? L("Parar de sincronizar com o Calendário", "Stop syncing with Calendar") : L("Sincronizar com o Calendário", "Sync with Calendar"), systemImage: "calendar") {
                    Task { await alternarCalendario(agenda) }
                }
                if let arquivoPDF {
                    ShareLink(item: arquivoPDF) { Label("Compartilhar PDF do plano", systemImage: "doc.richtext") }
                } else {
                    Button("Gerar PDF do plano", systemImage: "doc.richtext") { arquivoPDF = PlanoPDF.gerar(agenda, unidade: unidade) }
                }
                if agenda.plano.entrada.objetivo != .comecarACorrer {
                    Button("Adicionar prova secundária", systemImage: "flag.2.crossed") {
                        provaSemana = min(max(atual?.semana ?? 1, 1), agenda.plano.semanas.count)
                        adicionandoProva = true
                    }
                }
                if agenda.plano.entrada.objetivo.distanciaProva != nil {
                    Button("Mudar a data da prova", systemImage: "calendar.badge.clock") {
                        semanasRestantes = max(1, agenda.plano.semanas.count - (atual?.semana ?? 1) + 1)
                        mudandoProva = true
                    }
                }
                Button("Encerrar este plano", systemImage: "xmark.circle", role: .destructive) { confirmandoEncerrar = true }
            } label: {
                Label("Opções do plano", systemImage: "ellipsis.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.glass)

            // O que havia na aba antes do plano continua aqui embaixo.
            OpcoesDePlano(comPlanoAtivo: true)
        }
        .sheet(item: $proposta) { p in
            PropostaCorrecaoView(proposta: p, unidade: unidade) { aplicar(p) }
        }
        .sheet(isPresented: $mudandoProva) {
            NavigationStack {
                Form {
                    Section {
                        Stepper("\(semanasRestantes) semanas até a prova", value: $semanasRestantes, in: 1...30)
                    } footer: {
                        Text("Contando a partir desta semana. O motor refaz o resto com polimento e todas as travas; as semanas já feitas ficam.")
                    }
                }
                .navigationTitle("Nova data da prova")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { mudandoProva = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Ver proposta") {
                            mudandoProva = false
                            propor(.reajustarProva(aPartirDaSemana: atual?.semana ?? 1, semanasRestantes: semanasRestantes), agenda)
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $adicionandoProva) {
            NavigationStack {
                Form {
                    Section {
                        Stepper("Semana \(provaSemana)", value: $provaSemana, in: 1...agenda.plano.semanas.count)
                        Picker("Dia", selection: $provaDia) {
                            ForEach(0..<7, id: \.self) { Text(Self.nomesDias[$0]).tag($0) }
                        }
                        Picker("Distância", selection: $provaKm) {
                            Text("5 km").tag(5.0)
                            Text("10 km").tag(10.0)
                            Text("15 km").tag(15.0)
                            Text("Meia maratona").tag(21.0975)
                        }
                    } footer: {
                        Text("A véspera e o dia seguinte ficam leves e as semanas seguintes são refeitas a partir do volume que sobrar. Nas semanas de polimento não entra; se não couber nas travas, o motor diz por quê.")
                    }
                }
                .navigationTitle("Prova secundária")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { adicionandoProva = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Ver proposta") {
                            adicionandoProva = false
                            propor(.provaSecundaria(semana: provaSemana, dia: provaDia, distancia: provaKm * 1000), agenda)
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Encerrar o plano?", isPresented: $confirmandoEncerrar, titleVisibility: .visible) {
            Button("Encerrar plano", role: .destructive) {
                CalendarioSync.limpar()
                contexto.delete(ativo)
                try? contexto.save()
            }
        } message: {
            Text("As corridas continuam no histórico. Para começar outro, use a prévia.")
        }
    }

    private func alternarCalendario(_ agenda: AgendaPlano) async {
        if sincronizar {
            sincronizar = false
            CalendarioSync.limpar()
            mensagem = L("Os treinos saíram do calendário CRUNNING.", "The workouts were removed from the CRUNNING calendar.")
            return
        }
        guard await CalendarioSync.pedirAcesso() else {
            mensagem = L("Sem acesso ao Calendário. Libere em Ajustes do iPhone > CRUNNING > Calendários > Acesso total.", "No access to Calendar. Allow it in iPhone Settings > CRUNNING > Calendars > Full Access.")
            return
        }
        sincronizar = true
        if let n = CalendarioSync.sincronizar(agenda) {
            mensagem = L("\(n) treinos no calendário CRUNNING do app Calendário. Ele se atualiza quando o plano muda.", "\(n) workouts in the CRUNNING calendar of the Calendar app. It updates when the plan changes.")
        } else {
            mensagem = L("Não deu para criar o calendário CRUNNING.", "Could not create the CRUNNING calendar.")
        }
    }

    /// Perna pesada no Anilha perto de treino forte, menos os que você mandou manter.
    private func avisosForca(_ agenda: AgendaPlano, hoje: Date) -> [AvisoForca] {
        let fora = Set(dispensados.split(separator: ",").map(String.init))
        return ConflitoForca.avisos(agenda: agenda, forca: ForcaAnilha.shared.estado, hoje: hoje)
            .filter { !fora.contains($0.id) }
    }

    private func intervalo(_ agenda: AgendaPlano, _ semana: Int) -> String {
        let a = agenda.data(semana: semana, dia: 0), b = agenda.data(semana: semana, dia: 6)
        return a.formatted(.dateTime.day().month(.abbreviated)) + L(" a ", " – ") + b.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Corrida e força têm ações independentes dentro do cartão do dia.
    @ViewBuilder
    private func diaComDetalhe(_ agenda: AgendaPlano, semana: Int, dia: Int, hoje: Date) -> some View {
        let data = agenda.data(semana: semana, dia: dia)
        let ehHoje = Calendar.current.isDate(data, inSameDayAs: hoje)
        let status = agenda.status(semana: semana, dia: dia)
        let linhaCorrida = HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(Self.nomesDias[dia]).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(data.formatted(.dateTime.day())).font(.headline.monospacedDigit())
            }
            .frame(width: 40)
            if let sessao = agenda.sessao(semana: semana, dia: dia) {
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(sessao.tipo.cor).frame(width: 6, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessao.treino.nome).font(.body.weight(.medium))
                    Text("≈ " + Formatador.distancia(sessao.distancia, unidade: unidade, casas: 1) + " · " + LinhaDoTempoTreino.tempoCurto(sessao.duracao))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
                switch status {
                case .feita: Image(systemName: "checkmark.circle.fill").foregroundStyle(Paleta.dentroDaFaixa)
                case .perdida: Image(systemName: "xmark.circle").foregroundStyle(.secondary)
                case .planejada: Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            } else {
                Text("Descanso").foregroundStyle(.tertiary)
                Spacer()
            }
        }
        VStack(alignment: .leading, spacing: 8) {
            if let sessao = agenda.sessao(semana: semana, dia: dia) {
                NavigationLink {
                    detalhe(agenda, sessao, semana: semana, dia: dia)
                } label: {
                    linhaCorrida
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
            } else {
                linhaCorrida.accessibilityElement(children: .combine)
            }
            ForcaDoDia(data: data)
                .padding(.leading, 52)
        }
        .padding(12)
        .background {
            if ehHoje { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.accentColor, lineWidth: 1.5) }
        }
        .cartaoVidro(raio: 18)
        .contentShape(Rectangle())
        .menuComPrevia(agenda.sessao(semana: semana, dia: dia)?.treino,
                       subtitulo: data.formatted(.dateTime.weekday(.wide).day().month())) {
            menuDia(agenda, semana: semana, dia: dia)
        }
        .accessibilityElement(children: .contain)
    }

    private func detalhe(_ agenda: AgendaPlano, _ sessao: SessaoPlanejada, semana: Int, dia: Int) -> some View {
        DetalheTreinoView(
            treino: sessao.treino,
            porque: sessao.treino.modeloID.flatMap { Modelos.modelo(id: $0)?.porque },
            salvo: nil,
            plano: (semana, dia),
            subtitulo: L("Semana \(semana) · ", "Week \(semana) · ") + agenda.data(semana: semana, dia: dia).formatted(.dateTime.weekday(.wide).day().month())
        )
    }

    // MARK: Mês inteiro

    nonisolated static var letrasDias: [String] {
        [L("S", "M"), L("T", "T"), L("Q", "W"), L("Q", "T"), L("S", "F"), L("S", "S"), L("D", "S")]
    }

    /// O mês em grade de segunda a domingo: cada dia com treino tem a cor do tipo e os km; feito
    /// ganha o visto, perdido fica apagado e hoje tem contorno. Toque abre o treino; segurar dá
    /// as mesmas opções da semana.
    private func calendarioMes(_ agenda: AgendaPlano, hoje: Date) -> some View {
        let cal = CalendarioTreino.padrao()
        func mesDe(_ d: Date) -> Date { cal.dateInterval(of: .month, for: d)?.start ?? d }
        let primeiro = mesDe(agenda.inicio), ultimo = mesDe(agenda.fim)
        let mes = min(max(mesVisto ?? mesDe(hoje), primeiro), ultimo)
        let fimMes = cal.date(byAdding: .month, value: 1, to: mes) ?? mes
        var dias: [Date] = []
        var d = CalendarioTreino.inicioDaSemana(mes, calendario: cal)
        while d < fimMes || dias.count % 7 != 0 {
            dias.append(d)
            guard let proximo = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = proximo
        }
        let sessoes = dias
            .filter { cal.isDate($0, equalTo: mes, toGranularity: .month) }
            .compactMap { agenda.posicao(de: $0, calendario: cal).flatMap { agenda.sessao(semana: $0.semana, dia: $0.dia) } }
        let kmMes = sessoes.reduce(0) { $0 + $1.distancia }
        let titulo = mes.formatted(.dateTime.month(.wide).year())
        return VStack(spacing: 12) {
            HStack {
                Button { mesVisto = cal.date(byAdding: .month, value: -1, to: mes) } label: { Image(systemName: "chevron.left") }
                    .disabled(mes <= primeiro)
                    .accessibilityLabel(L("Mês anterior", "Previous month"))
                Spacer()
                VStack(spacing: 2) {
                    Text(titulo.prefix(1).uppercased() + titulo.dropFirst()).font(.subheadline.weight(.semibold))
                    Text(Formatador.distancia(kmMes, unidade: unidade, casas: 0) + L(" planejados · \(sessoes.count) treinos", " planned · \(sessoes.count) workouts"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { mesVisto = cal.date(byAdding: .month, value: 1, to: mes) } label: { Image(systemName: "chevron.right") }
                    .disabled(mes >= ultimo)
                    .accessibilityLabel(L("Próximo mês", "Next month"))
            }
            .font(.title3.weight(.semibold))
            .padding(14)
            .cartaoVidro(raio: 22)

            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(Self.letrasDias[i])
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(dias, id: \.self) { data in
                        celulaMes(agenda, data: data, doMes: cal.isDate(data, equalTo: mes, toGranularity: .month), hoje: hoje)
                    }
                }
            }
            .padding(10)
            .cartaoVidro(raio: 22)

            Text(L("Toque num dia para ver o treino; segure para marcar, mover ou trocar.", "Tap a day to see the workout; press and hold to mark, move or swap."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func celulaMes(_ agenda: AgendaPlano, data: Date, doMes: Bool, hoje: Date) -> some View {
        let pos = doMes ? agenda.posicao(de: data) : nil
        let sessao = pos.flatMap { agenda.sessao(semana: $0.semana, dia: $0.dia) }
        let status = pos.map { agenda.status(semana: $0.semana, dia: $0.dia) } ?? .planejada
        let ehHoje = Calendar.current.isDate(data, inSameDayAs: hoje)
        let rotulo = data.formatted(.dateTime.weekday(.wide).day().month())
        let forca = doMes ? ForcaDoDia.marca(data) : .nenhuma
        if let pos, let sessao {
            NavigationLink {
                detalhe(agenda, sessao, semana: pos.semana, dia: pos.dia)
            } label: {
                conteudoCelula(data: data, doMes: doMes, sessao: sessao, status: status, ehHoje: ehHoje, forca: forca)
            }
            .buttonStyle(.plain)
            .menuComPrevia(sessao.treino, subtitulo: rotulo) {
                menuDia(agenda, semana: pos.semana, dia: pos.dia)
            }
            .accessibilityLabel(rotulo + ": " + sessao.treino.nome + forca.rotulo)
        } else {
            conteudoCelula(data: data, doMes: doMes, sessao: nil, status: .planejada, ehHoje: ehHoje, forca: forca)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rotulo + (doMes ? L(": descanso", ": rest") : "") + forca.rotulo)
        }
    }

    private func conteudoCelula(data: Date, doMes: Bool, sessao: SessaoPlanejada?, status: StatusSessao, ehHoje: Bool, forca: ForcaDoDia.Marca) -> some View {
        VStack(spacing: 3) {
            Text(data.formatted(.dateTime.day()))
                .font(.footnote.weight(ehHoje ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(doMes ? (ehHoje ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary)) : AnyShapeStyle(.quaternary))
            if let sessao {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(sessao.tipo.cor.opacity(status == .perdida ? 0.3 : 1))
                    .frame(height: 4)
                    .padding(.horizontal, 6)
                if status == .feita {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Paleta.dentroDaFaixa)
                } else {
                    Text(Formatador.numero(Formatador.distanciaNaUnidade(sessao.distancia, unidade: unidade), casas: 0))
                        .font(.caption2.monospacedDigit())
                        .strikethrough(status == .perdida)
                        .foregroundStyle(status == .perdida ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                }
            }
            if let icone = forca.icone {
                Image(systemName: icone)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(forca.pernas ? AnyShapeStyle(ForcaDoDia.corPerna) : AnyShapeStyle(.secondary))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .top)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(status == .feita ? Paleta.dentroDaFaixa.opacity(0.12) : (sessao != nil ? Color.primary.opacity(0.05) : Color.clear))
        }
        .overlay {
            if ehHoje { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.accentColor, lineWidth: 1.5) }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func menuDia(_ agenda: AgendaPlano, semana: Int, dia: Int) -> some View {
        if let sessao = agenda.sessao(semana: semana, dia: dia) {
            Button("Correr este treino", systemImage: "play.fill") {
                estadoApp.abrirTreino(sessao.treino, plano: (semana, dia))
            }
            Button("Marcar como feito", systemImage: "checkmark.circle") { marcar(agenda, semana, dia, .feita) }
            Button("Marcar como perdido", systemImage: "xmark.circle") { marcar(agenda, semana, dia, .perdida) }
            if agenda.status(semana: semana, dia: dia) != .planejada {
                Button("Voltar para planejado", systemImage: "arrow.uturn.backward") { marcar(agenda, semana, dia, .planejada) }
            }
            if sessao.treino.modeloID != nil, !sessao.ehProva {
                Button("Trocar por equivalente", systemImage: "arrow.triangle.2.circlepath") {
                    propor(.trocarTreino(semana: semana, dia: dia), agenda)
                }
            }
            Menu("Mover para", systemImage: "arrow.left.arrow.right") {
                ForEach(0..<7, id: \.self) { outro in
                    if outro != dia {
                        Button(Self.nomesDias[outro] + (agenda.sessao(semana: semana, dia: outro) == nil ? "" : L(" (troca)", " (swap)"))) {
                            propor(.moverTreino(semana: semana, de: dia, para: outro), agenda)
                        }
                    }
                }
            }
        }
    }

    private func marcar(_ agenda: AgendaPlano, _ semana: Int, _ dia: Int, _ status: StatusSessao) {
        var nova = agenda
        nova.marcar(semana: semana, dia: dia, status)
        ativo.agenda = nova
        try? contexto.save()
        EnvioAnilha.planoMudou()
    }

    private func propor(_ correcao: CorrecaoPlano, _ agenda: AgendaPlano) {
        do {
            let novo = try correcao.aplicar(agenda.plano)
            let comparacao = ComparacaoPlano(antes: agenda.plano, depois: novo)
            guard comparacao.mudouAlgo else { mensagem = L("Essa mudança não altera o plano.", "This change does not alter the plan."); return }
            proposta = PropostaCorrecao(correcao: correcao, novo: novo, comparacao: comparacao, motivo: nil, chave: nil)
        } catch {
            mensagem = L("O motor recusou: ", "The engine refused: ") + PreviaPlanoView.explicar(error)
        }
    }

    private func aplicar(_ p: PropostaCorrecao) {
        guard var agenda = ativo.agenda else { return }
        agenda.trocarPlano(p.novo)
        ativo.agenda = agenda
        try? contexto.save()
        EnvioAnilha.planoMudou()
        mensagem = L("Aplicado: ", "Applied: ") + p.correcao.descricao + "."
        proposta = nil
    }
}

/// Começar a usar um plano da prévia: data de início e triagem de segurança na primeira vez.
struct UsarPlanoView: View {
    let plano: Plano
    @Environment(\.modelContext) var contexto
    @Environment(\.dismiss) var fechar
    @Environment(\.openURL) var abrirURL
    @Query var ativos: [PlanoAtivo]
    @AppStorage(PreferenciasPlano.triagemFeita) var triagemFeita = false
    @State var inicio = AgendaPlano.proximaSegunda(.now)
    @State var respostas: [Bool] = Array(repeating: false, count: UsarPlanoView.perguntas.count)
    @State var ciente = false

    /// Perguntas próprias sobre sinais de alerta (o PAR-Q+ oficial não pode ser alterado, então só é indicado).
    static let perguntas = [
        L("Algum médico já falou de problema no coração ou de pressão alta com você?",
          "Has a doctor ever told you that you have a heart condition or high blood pressure?"),
        L("Você sente dor ou aperto no peito em repouso, no dia a dia ou ao fazer esforço?",
          "Do you feel pain or tightness in your chest at rest, during daily activities or when you exert yourself?"),
        L("Nos últimos 12 meses, você desmaiou ou perdeu o equilíbrio por tontura?",
          "In the past 12 months, have you fainted or lost your balance because of dizziness?"),
        L("Você tem alguma doença crônica diagnosticada ou toma remédio de uso contínuo?",
          "Do you have a diagnosed chronic medical condition, or do you take prescription medication regularly?"),
        L("Tem alguma lesão ou problema em osso, articulação ou músculo que piora com esforço?",
          "Do you have a bone, joint or muscle injury or problem that gets worse with physical activity?"),
        L("Está grávida ou teve bebê há pouco tempo?",
          "Are you pregnant, or have you given birth recently?"),
    ]

    var body: some View {
        let algumSim = respostas.contains(true)
        Form {
            Section {
                DatePicker("Começa em", selection: $inicio, displayedComponents: .date)
                Text("A semana 1 começa na segunda da semana escolhida.").font(.footnote).foregroundStyle(.secondary)
            }
            if !triagemFeita {
                Section {
                    ForEach(Self.perguntas.indices, id: \.self) { i in
                        Toggle(Self.perguntas[i], isOn: $respostas[i])
                    }
                    if algumSim {
                        Text("Converse com um médico antes de começar um plano de corrida. O CRUNNING não é aconselhamento médico.")
                            .foregroundStyle(Paleta.foraLeve)
                        Toggle("Entendi e quero seguir assim mesmo", isOn: $ciente)
                    }
                    Button("Ver o questionário oficial PAR-Q+") {
                        if let url = URL(string: "https://eparmedx.com/") { abrirURL(url) }
                    }
                } header: {
                    Text("Antes de começar")
                } footer: {
                    Text("Perguntas de segurança do app. O PAR-Q+ oficial está no site acima.")
                }
            }
            if !ativos.isEmpty {
                Section {
                    Text("Isto substitui o plano em uso. As corridas continuam no histórico.").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Usar este plano")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { fechar() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Começar") {
                    for a in ativos { contexto.delete(a) }
                    contexto.insert(PlanoAtivo(agenda: AgendaPlano(plano: plano, inicio: inicio)))
                    try? contexto.save()
                    triagemFeita = true
                    fechar()
                }
                .disabled(!triagemFeita && algumSim && !ciente)
            }
        }
    }
}

/// PDF do plano inteiro, semana a semana (uma página comprida).
enum PlanoPDF {
    static func titulo(_ s: SemanaPlano, unidade: UnidadeDistancia) -> String {
        let alivio = s.alivio ? L(" · alívio", " · recovery week") : ""
        let volume = Formatador.distancia(s.volumeTreino, unidade: unidade, casas: 0)
        return L("Semana \(s.numero) · \(s.fase.nome)\(alivio) · \(volume)", "Week \(s.numero) · \(s.fase.nome)\(alivio) · \(volume)")
    }

    static func linha(_ agenda: AgendaPlano, semana: Int, dia: Int, sessao: SessaoPlanejada, unidade: UnidadeDistancia) -> String {
        let data = agenda.data(semana: semana, dia: dia).formatted(.dateTime.day().month(.abbreviated))
        let distancia = Formatador.distancia(sessao.distancia, unidade: unidade, casas: 1)
        let blocos = TextoRapido.texto(sessao.treino.blocos)
        return "\(PlanoAtivoView.nomesDias[dia]) \(data): \(sessao.treino.nome), \(distancia) (\(blocos))"
    }

    @MainActor
    static func gerar(_ agenda: AgendaPlano, unidade: UnidadeDistancia) -> URL? {
        let conteudo = VStack(alignment: .leading, spacing: 10) {
            Text("CRUNNING · " + agenda.plano.entrada.objetivo.nome).font(.title2.bold())
            Text(L("\(agenda.plano.semanas.count) semanas, a partir de ", "\(agenda.plano.semanas.count) weeks, starting ") + agenda.inicio.formatted(.dateTime.day().month(.wide).year()))
                .font(.subheadline)
            ForEach(agenda.plano.semanas, id: \.numero) { s in
                VStack(alignment: .leading, spacing: 3) {
                    Text(titulo(s, unidade: unidade)).font(.headline)
                    ForEach(0..<7, id: \.self) { d in
                        if let sessao = s.dias[d] {
                            Text(linha(agenda, semana: s.numero, dia: d, sessao: sessao, unidade: unidade)).font(.caption)
                        }
                    }
                }
            }
        }
        .padding(28)
        .frame(width: 595, alignment: .leading)
        .foregroundStyle(Color.black)
        .background(Color.white)

        let renderer = ImageRenderer(content: conteudo)
        let url = FileManager.default.temporaryDirectory.appending(path: "plano-crunning.pdf")
        var gerado = false
        renderer.render { tamanho, desenhar in
            var caixa = CGRect(origin: .zero, size: tamanho)
            guard let pdf = CGContext(url as CFURL, mediaBox: &caixa, nil) else { return }
            pdf.beginPDFPage(nil)
            desenhar(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            gerado = true
        }
        return gerado ? url : nil
    }
}
