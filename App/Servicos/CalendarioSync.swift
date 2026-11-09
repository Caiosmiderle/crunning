import CrunningCore
import EventKit
import Foundation

/// Põe os treinos do plano num calendário próprio ("CRUNNING") do app Calendário e o refaz
/// quando o plano muda. Só mexe nesse calendário. Precisa de acesso total (para criar o
/// calendário e apagar os eventos antigos dele).
enum CalendarioSync {
    static let titulo = "CRUNNING"

    static var ligado: Bool {
        UserDefaults.standard.bool(forKey: Preferencias.sincronizarCalendario)
    }

    static var autorizado: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Pede o acesso (a primeira vez abre o aviso do iOS). Devolve se ficou autorizado.
    @MainActor
    static func pedirAcesso() async -> Bool {
        if autorizado { return true }
        let loja = EKEventStore()
        return await withCheckedContinuation { continuacao in
            loja.requestFullAccessToEvents { concedido, _ in
                continuacao.resume(returning: concedido)
            }
        }
    }

    /// Refaz os eventos se a sincronização estiver ligada e autorizada.
    static func sincronizarSeLigado(_ agenda: AgendaPlano) {
        guard ligado, autorizado else { return }
        _ = sincronizar(agenda)
    }

    /// Apaga os eventos do calendário CRUNNING e cria um por sessão do plano (dia inteiro).
    /// Devolve quantos eventos criou, ou nil se não deu.
    @discardableResult
    static func sincronizar(_ agenda: AgendaPlano) -> Int? {
        guard autorizado else { return nil }
        let loja = EKEventStore()
        guard let calendario = calendarioDoApp(loja) else { return nil }
        apagarEventos(loja, calendario)
        var criados = 0
        for semana in agenda.plano.semanas {
            for dia in 0..<7 {
                guard let sessao = semana.dias[dia] else { continue }
                let inicio = agenda.data(semana: semana.numero, dia: dia)
                let evento = EKEvent(eventStore: loja)
                evento.calendar = calendario
                evento.isAllDay = true
                evento.startDate = inicio
                evento.endDate = Calendar.current.date(byAdding: .day, value: 1, to: inicio) ?? inicio
                evento.title = "\(sessao.treino.nome) · " + Formatador.distancia(sessao.distancia, casas: 1)
                var notas = "Semana \(semana.numero) (\(semana.fase.nome)). " + TextoRapido.texto(sessao.treino.blocos)
                if let porque = sessao.treino.modeloID.flatMap({ Modelos.modelo(id: $0)?.porque }) { notas += "\n\n" + porque }
                evento.notes = notas
                if (try? loja.save(evento, span: .thisEvent, commit: false)) != nil { criados += 1 }
            }
        }
        try? loja.commit()
        return criados
    }

    /// Apaga os eventos do calendário CRUNNING (ao encerrar o plano ou desligar a sincronização).
    static func limpar() {
        guard autorizado else { return }
        let loja = EKEventStore()
        guard let calendario = loja.calendars(for: .event).first(where: { $0.title == titulo }) else { return }
        apagarEventos(loja, calendario)
        try? loja.commit()
    }

    private static func apagarEventos(_ loja: EKEventStore, _ calendario: EKCalendar) {
        let inicio = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
        let fim = Calendar.current.date(byAdding: .year, value: 2, to: .now) ?? .now
        let busca = loja.predicateForEvents(withStart: inicio, end: fim, calendars: [calendario])
        for evento in loja.events(matching: busca) {
            try? loja.remove(evento, span: .thisEvent, commit: false)
        }
    }

    /// O calendário CRUNNING, criado na primeira vez na mesma conta do calendário padrão.
    private static func calendarioDoApp(_ loja: EKEventStore) -> EKCalendar? {
        if let existente = loja.calendars(for: .event).first(where: { $0.title == titulo }) { return existente }
        let novo = EKCalendar(for: .event, eventStore: loja)
        novo.title = titulo
        novo.cgColor = CGColor(red: 0x8B / 255, green: 0xE1 / 255, blue: 0x05 / 255, alpha: 1)
        guard let fonte = loja.defaultCalendarForNewEvents?.source ?? loja.sources.first(where: { $0.sourceType == .local }) else { return nil }
        novo.source = fonte
        return (try? loja.saveCalendar(novo, commit: true)) != nil ? novo : nil
    }
}
