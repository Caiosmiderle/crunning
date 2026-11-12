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
        CalendarioSync.sincronizarSeLigado(agenda)
    }

    /// Ler e gravar o plano. Quando o plano (não só um registro) muda, o calendário é refeito.
    var agenda: AgendaPlano? {
        get { dados.flatMap { try? JSONDecoder().decode(AgendaPlano.self, from: $0) } }
        set {
            let antigo = agenda
            dados = newValue.flatMap { try? JSONEncoder().encode($0) }
            if let novo = newValue, antigo?.plano != novo.plano || antigo?.inicio != novo.inicio {
                CalendarioSync.sincronizarSeLigado(novo)
            }
        }
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
    /// Km que o tênis já tinha quando entrou no app (somados aos das corridas).
    var kmIniciais: Double = 0

    init(nome: String, limiteKm: Double = 700, kmIniciais: Double = 0) {
        self.nome = nome
        self.limiteKm = limiteKm
        self.kmIniciais = max(0, kmIniciais)
    }
}

enum PreferenciasPlano {
    /// Triagem de segurança respondida (antes do primeiro plano).
    static let triagemFeita = "triagemFeita"
    /// Antigo "último tênis usado"; só serve de ponto de partida para o principal.
    static let ultimoTenis = "ultimoTenis"
    /// Tênis principal (Tenis.codigo): toda corrida começa com ele (Ajustes > Tênis).
    static let tenisPrincipal = "tenisPrincipal"
    /// Aba Plano mostrando o mês inteiro em vez da semana.
    static let verMes = "planoVerMes"

    static var principal: String? {
        let d = UserDefaults.standard
        let codigo = d.string(forKey: tenisPrincipal) ?? d.string(forKey: ultimoTenis)
        return (codigo?.isEmpty ?? true) ? nil : codigo
    }
}
