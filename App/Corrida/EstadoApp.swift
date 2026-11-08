import CrunningCore
import Foundation
import Observation
import SwiftData

/// Estado do app inteiro: a corrida aberta e a corrida a recuperar.
@MainActor
@Observable
final class EstadoApp {
    var gravadorAtivo: GravadorCorrida?
    var sessaoParaRecuperar: SessaoSalva?

    func abrirCorridaLivre(sessaoRecuperada: SessaoCorrida? = nil) {
        guard gravadorAtivo == nil else { return }
        let padroes = UserDefaults.standard
        let pausaAutomatica = padroes.object(forKey: Preferencias.pausaAutomatica) as? Bool ?? true
        let telaAcesa = padroes.object(forKey: Preferencias.telaAcesa) as? Bool ?? true
        let simular = padroes.bool(forKey: Preferencias.modoDesenvolvimento) && padroes.bool(forKey: Preferencias.simularGPS)
        let multiplicador = padroes.object(forKey: Preferencias.velocidadeSimulacao) as? Double ?? 10

        gravadorAtivo = GravadorCorrida(
            configuracao: ConfiguracaoCorrida(pausaAutomatica: pausaAutomatica),
            pontosSimulados: simular && sessaoRecuperada == nil ? Simulacao.pontos() : nil,
            multiplicadorSimulacao: multiplicador,
            manterTelaAcesa: telaAcesa,
            sessaoRecuperada: sessaoRecuperada
        )
    }

    /// Ao abrir o app: há uma corrida que não chegou a ser salva?
    func verificarSessaoPendente() {
        guard gravadorAtivo == nil, sessaoParaRecuperar == nil,
              let salva = ArmazemSessao.carregar(), salva.sessao.estado != .pronta else { return }
        sessaoParaRecuperar = salva
    }

    /// Continua de onde parou, pausada no último instante conhecido
    /// (o tempo em que o app ficou fechado não conta como movimento).
    func continuar(_ salva: SessaoSalva) {
        var sessao = salva.sessao
        sessao.pausar(em: salva.salvaEm)
        sessaoParaRecuperar = nil
        abrirCorridaLivre(sessaoRecuperada: sessao)
    }

    func salvarComoEsta(_ salva: SessaoSalva, em contexto: ModelContext) {
        var sessao = salva.sessao
        sessao.finalizar(em: salva.salvaEm)
        contexto.insert(Corrida.de(sessao: sessao, simulada: salva.simulada, esforco: nil, agora: salva.salvaEm))
        try? contexto.save()
        ArmazemSessao.apagar()
        sessaoParaRecuperar = nil
    }

    func descartarRecuperacao() {
        ArmazemSessao.apagar()
        sessaoParaRecuperar = nil
    }
}
