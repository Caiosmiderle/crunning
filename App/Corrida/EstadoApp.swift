import CrunningCore
import Foundation
import Observation

/// Estado do app inteiro: a corrida aberta. Existe um só, criado na abertura do
/// processo e independente das telas, porque o iOS pode reabrir o app em segundo
/// plano (sem tela nenhuma) para entregar localização no meio de uma corrida.
@MainActor
@Observable
final class EstadoApp {
    static let compartilhado = EstadoApp()

    var gravadorAtivo: GravadorCorrida?
    @ObservationIgnored private var verificouPendente = false

    private init() {}

    /// Corrida livre, com GPS ou na esteira.
    func abrirCorridaLivre(esteira: Bool = false) {
        abrir(execucao: nil, esteira: esteira)
    }

    /// Treino por blocos. O aquecimento guiado segue Ajustes, a não ser que a tela diga outra coisa.
    func abrirTreino(_ treino: Treino, esteira: Bool = false, aquecimentoGuiado: Bool? = nil, plano: (semana: Int, dia: Int)? = nil) {
        let guiado = aquecimentoGuiado ?? (UserDefaults.standard.object(forKey: Preferencias.aquecimentoGuiado) as? Bool ?? true)
        let execucao = ExecucaoTreino(treino: treino, zonas: ZonasDoUsuario.atuais(), aquecimentoGuiado: guiado, esteira: esteira)
        abrir(execucao: execucao, esteira: esteira)
        gravadorAtivo?.sessaoPlano = plano
    }

    private func abrir(execucao: ExecucaoTreino?, esteira: Bool) {
        guard gravadorAtivo == nil else { return }
        let padroes = UserDefaults.standard
        let pausaAutomatica = padroes.object(forKey: Preferencias.pausaAutomatica) as? Bool ?? true
        let simular = !esteira && padroes.bool(forKey: Preferencias.modoDesenvolvimento) && padroes.bool(forKey: Preferencias.simularGPS)
        let multiplicador = padroes.object(forKey: Preferencias.velocidadeSimulacao) as? Double ?? 10

        var simulacao: OrigemSimulada?
        if simular {
            let semente = Simulacao.novaSemente()
            simulacao = OrigemSimulada(pontos: Simulacao.pontos(semente: semente), multiplicador: multiplicador, semente: semente)
        }
        gravadorAtivo = GravadorCorrida(
            configuracao: ConfiguracaoCorrida(pausaAutomatica: pausaAutomatica && !esteira),
            simulacao: simulacao,
            manterTelaAcesa: Self.manterTelaAcesa,
            execucao: execucao,
            esteira: esteira
        )
    }

    /// Na abertura do processo: se havia uma corrida em andamento quando o iOS fechou
    /// o app, ela volta na hora, com o GPS e as sessões de localização recriados
    /// (é o que a Apple pede para a gravação continuar depois de o app ser reaberto
    /// em segundo plano). A tela de corrida aparece assim que você abrir o app.
    func restaurarCorridaPendente() {
        guard !verificouPendente else { return }
        verificouPendente = true
        guard gravadorAtivo == nil,
              let salva = ArmazemSessao.carregar(),
              salva.sessao.estado != .pronta else { return }
        let gravador = GravadorCorrida(recuperada: salva, manterTelaAcesa: Self.manterTelaAcesa)
        gravadorAtivo = gravador
        gravador.continuarDepoisDeReaberta()
    }

    private static var manterTelaAcesa: Bool {
        UserDefaults.standard.object(forKey: Preferencias.telaAcesa) as? Bool ?? true
    }
}
