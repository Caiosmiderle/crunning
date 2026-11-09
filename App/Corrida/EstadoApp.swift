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
    /// A corrida segue gravando, mas a tela dela vira uma barra acima das abas.
    var corridaMinimizada = false
    @ObservationIgnored private var verificouPendente = false

    private init() {}

    /// Corrida livre, com GPS ou na esteira.
    func abrirCorridaLivre(esteira: Bool = false) {
        abrir(execucao: nil, esteira: esteira)
    }

    /// Treino por blocos. Os exercícios de aquecimento ficam de fora do relógio: aparecem como
    /// sugestão antes de começar (SugestaoAquecimento), não como etapas do treino.
    func abrirTreino(_ treino: Treino, esteira: Bool = false, plano: (semana: Int, dia: Int)? = nil, ajusteCalor: Double = 0) {
        let execucao = ExecucaoTreino(treino: treino, zonas: ZonasDoUsuario.atuais(), aquecimentoGuiado: false, esteira: esteira, ajusteCalor: ajusteCalor)
        if abrir(execucao: execucao, esteira: esteira) {
            gravadorAtivo?.sessaoPlano = plano
        }
    }

    /// A barra da corrida minimizada usa um modificador do iOS 26.1.
    static var podeMinimizar: Bool {
        if #available(iOS 26.1, *) { return true }
        return false
    }

    /// Abre a tela de corrida. Se já houver uma corrida (minimizada), ela volta para a tela e
    /// nada novo começa.
    @discardableResult
    private func abrir(execucao: ExecucaoTreino?, esteira: Bool) -> Bool {
        corridaMinimizada = false
        guard gravadorAtivo == nil else { return false }
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
        return true
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
