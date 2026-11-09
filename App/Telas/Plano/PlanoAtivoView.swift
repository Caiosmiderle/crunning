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

    static let nomesDias = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]

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
        return Tela(selo: "Semana \(numero) de \(agenda.plano.semanas.count) · \(semana.fase.nome)" + (semana.alivio ? " · alívio" : ""),
                    iconeSelo: "calendar", titulo: agenda.plano.entrada.objetivo.nome) {
            HStack {
                Button { semanaVista = numero - 1 } label: { Image(systemName: "chevron.left") }
                    .disabled(numero <= 1)
                Spacer()
                VStack(spacing: 2) {
                    Text(intervalo(agenda, numero)).font(.subheadline.weight(.semibold))
                    Text(Formatador.distancia(semana.volumeTreino, unidade: unidade, casas: 0) + " planejados" + (semana.temProva ? " + prova" : ""))
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
                linhaDia(agenda, semana: numero, dia: dia, hoje: hoje)
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
                            mensagem = "Voltou ao plano de antes da última mudança."
                        }
                    }
                }
                Button(sincronizar ? "Parar de sincronizar com o Calendário" : "Sincronizar com o Calendário", systemImage: "calendar") {
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
                NavigationLink {
                    PreviaPlanoView()
                } label: {
                    Label("Montar outro plano (prévia)", systemImage: "wand.and.stars")
                }
                Button("Encerrar este plano", systemImage: "xmark.circle", role: .destructive) { confirmandoEncerrar = true }
            } label: {
                Label("Opções do plano", systemImage: "ellipsis.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.glass)
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
            mensagem = "Os treinos saíram do calendário CRUNNING."
            return
        }
        guard await CalendarioSync.pedirAcesso() else {
            mensagem = "Sem acesso ao Calendário. Libere em Ajustes do iPhone > CRUNNING > Calendários > Acesso total."
            return
        }
        sincronizar = true
        if let n = CalendarioSync.sincronizar(agenda) {
            mensagem = "\(n) treinos no calendário CRUNNING do app Calendário. Ele se atualiza quando o plano muda."
        } else {
            mensagem = "Não deu para criar o calendário CRUNNING."
        }
    }

    private func intervalo(_ agenda: AgendaPlano, _ semana: Int) -> String {
        let a = agenda.data(semana: semana, dia: 0), b = agenda.data(semana: semana, dia: 6)
        return a.formatted(.dateTime.day().month(.abbreviated).locale(.ptBR)) + " a " + b.formatted(.dateTime.day().month(.abbreviated).locale(.ptBR))
    }

    @ViewBuilder
    private func linhaDia(_ agenda: AgendaPlano, semana: Int, dia: Int, hoje: Date) -> some View {
        let data = agenda.data(semana: semana, dia: dia)
        let ehHoje = Calendar.current.isDate(data, inSameDayAs: hoje)
        let status = agenda.status(semana: semana, dia: dia)
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(Self.nomesDias[dia]).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(data.formatted(.dateTime.day().locale(.ptBR))).font(.headline.monospacedDigit())
            }
            .frame(width: 40)
            if let sessao = agenda.sessao(semana: semana, dia: dia) {
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(sessao.tipo.cor).frame(width: 6, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessao.treino.nome).font(.body.weight(.medium))
                    Text(Formatador.distancia(sessao.distancia, unidade: unidade, casas: 1) + " · " + Formatador.duracao(sessao.duracao))
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
        .padding(12)
        .background {
            if ehHoje { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.accentColor, lineWidth: 1.5) }
        }
        .cartaoVidro(raio: 18)
        .contentShape(Rectangle())
        .contextMenu { menuDia(agenda, semana: semana, dia: dia) }
        .accessibilityElement(children: .combine)
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
                        Button(Self.nomesDias[outro] + (agenda.sessao(semana: semana, dia: outro) == nil ? "" : " (troca)")) {
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
    }

    private func propor(_ correcao: CorrecaoPlano, _ agenda: AgendaPlano) {
        do {
            let novo = try correcao.aplicar(agenda.plano)
            let comparacao = ComparacaoPlano(antes: agenda.plano, depois: novo)
            guard comparacao.mudouAlgo else { mensagem = "Essa mudança não altera o plano."; return }
            proposta = PropostaCorrecao(correcao: correcao, novo: novo, comparacao: comparacao, motivo: nil, chave: nil)
        } catch {
            mensagem = "O motor recusou: " + PreviaPlanoView.explicar(error)
        }
    }

    private func aplicar(_ p: PropostaCorrecao) {
        guard var agenda = ativo.agenda else { return }
        agenda.trocarPlano(p.novo)
        ativo.agenda = agenda
        try? contexto.save()
        mensagem = "Aplicado: " + p.correcao.descricao + "."
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
        "Algum médico já falou de problema no coração ou de pressão alta com você?",
        "Você sente dor ou aperto no peito em repouso, no dia a dia ou ao fazer esforço?",
        "Nos últimos 12 meses, você desmaiou ou perdeu o equilíbrio por tontura?",
        "Você tem alguma doença crônica diagnosticada ou toma remédio de uso contínuo?",
        "Tem alguma lesão ou problema em osso, articulação ou músculo que piora com esforço?",
        "Está grávida ou teve bebê há pouco tempo?",
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
        let alivio = s.alivio ? " · alívio" : ""
        let volume = Formatador.distancia(s.volumeTreino, unidade: unidade, casas: 0)
        return "Semana \(s.numero) · \(s.fase.nome)\(alivio) · \(volume)"
    }

    static func linha(_ agenda: AgendaPlano, semana: Int, dia: Int, sessao: SessaoPlanejada, unidade: UnidadeDistancia) -> String {
        let data = agenda.data(semana: semana, dia: dia).formatted(.dateTime.day().month(.abbreviated).locale(.ptBR))
        let distancia = Formatador.distancia(sessao.distancia, unidade: unidade, casas: 1)
        let blocos = TextoRapido.texto(sessao.treino.blocos)
        return "\(PlanoAtivoView.nomesDias[dia]) \(data): \(sessao.treino.nome), \(distancia) (\(blocos))"
    }

    @MainActor
    static func gerar(_ agenda: AgendaPlano, unidade: UnidadeDistancia) -> URL? {
        let conteudo = VStack(alignment: .leading, spacing: 10) {
            Text("CRUNNING · " + agenda.plano.entrada.objetivo.nome).font(.title2.bold())
            Text("\(agenda.plano.semanas.count) semanas, a partir de " + agenda.inicio.formatted(.dateTime.day().month(.wide).year().locale(.ptBR)))
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
