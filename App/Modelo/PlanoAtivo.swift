import CrunningCore
import Foundation
import SwiftData

/// O plano em uso (só um por vez), com o calendário e o que foi feito, em JSON.
@Model
final class PlanoAtivo {
    var criadoEm: Date = Date.now
    var dados: Data? = nil

    init(agenda: AgendaPlano) {
        dados = try? JSONEncoder().encode(agenda)
    }

    var agenda: AgendaPlano? {
        get { dados.flatMap { try? JSONDecoder().decode(AgendaPlano.self, from: $0) } }
        set { dados = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    /// Marca a sessão de um dia como feita (chamado ao salvar uma corrida pelo plano).
    static func registrarFeita(semana: Int, dia: Int, esforco: Int?, em contexto: ModelContext) {
        guard let ativo = try? contexto.fetch(FetchDescriptor<PlanoAtivo>()).first, var agenda = ativo.agenda else { return }
        agenda.marcar(semana: semana, dia: dia, .feita, esforco: esforco)
        ativo.agenda = agenda
        try? contexto.save()
    }
}

/// Um par de tênis, para somar a quilometragem.
@Model
final class Tenis {
    var codigo: String = UUID().uuidString
    var nome: String = "Tênis"
    /// Aviso ao passar desta quilometragem (você escolhe; 0 = sem aviso).
    var limiteKm: Double = 700
    var aposentado: Bool = false
    var criadoEm: Date = Date.now

    init(nome: String, limiteKm: Double = 700) {
        self.nome = nome
        self.limiteKm = limiteKm
    }
}

enum PreferenciasPlano {
    /// Triagem de segurança respondida (antes do primeiro plano).
    static let triagemFeita = "triagemFeita"
    static let ultimoTenis = "ultimoTenis"
}
