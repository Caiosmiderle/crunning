import CrunningCore
import Foundation
import SwiftData

/// Treino montado no construtor (ou salvo de um modelo pronto). O treino em si fica em JSON,
/// porque blocos e repetições são valores do CrunningCore.
@Model
final class TreinoSalvo {
    var nome: String = "Treino"
    var criadoEm: Date = Date.now
    var atualizadoEm: Date = Date.now
    /// Aparece em "Meus modelos" (base para treinos novos).
    var ehModelo: Bool = false
    var dados: Data? = nil

    init(treino: Treino, ehModelo: Bool = false) {
        self.nome = treino.nome
        self.ehModelo = ehModelo
        self.dados = try? JSONEncoder().encode(treino)
    }

    var treino: Treino? {
        guard let dados else { return nil }
        return try? JSONDecoder().decode(Treino.self, from: dados)
    }

    func atualizar(_ treino: Treino) {
        nome = treino.nome
        dados = try? JSONEncoder().encode(treino)
        atualizadoEm = .now
    }
}

/// Ritmos do usuário a partir da prova de referência de Meus ritmos (nil sem prova).
enum ZonasDoUsuario {
    /// FC máxima: a medida (Ajustes > Meus ritmos) ou, sem ela, a estimada pela idade (Tanaka).
    static func fcMaxima() -> (valor: Double, estimada: Bool)? {
        let d = UserDefaults.standard
        let medida = d.integer(forKey: Preferencias.fcMaximaMedida)
        if (120...230).contains(medida) { return (Double(medida), false) }
        let idade = d.integer(forKey: Preferencias.idade)
        if (10...100).contains(idade) { return (FrequenciaCardiaca.maximaEstimada(idade: idade), true) }
        return nil
    }

    /// Zona de batimento da intensidade (nil sem FC máxima ou sem faixa para a intensidade).
    static func zonaFC(_ intensidade: Intensidade) -> ZonaFC? {
        fcMaxima().flatMap { FrequenciaCardiaca.zona(intensidade, fcMaxima: $0.valor) }
    }

    static func atuais() -> Zonas? {
        let d = UserDefaults.standard
        let tempo = d.double(forKey: Preferencias.provaTempo)
        let distancia = d.object(forKey: Preferencias.provaDistancia) as? Double ?? 5000
        guard tempo > 0 else { return nil }
        return Zonas(distanciaMetros: distancia, tempoSegundos: tempo)
    }
}
