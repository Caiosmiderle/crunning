import CoreLocation
import CrunningCore
import Foundation
import Observation
import SwiftData
import UIKit

/// Qualidade do sinal, a partir do raio de incerteza do último ponto.
enum QualidadeGPS: Equatable {
    case procurando
    case fraco
    case bom
    case otimo
    case simulado

    init(precisao: Double) {
        switch precisao {
        case ..<0: self = .procurando
        case ...10: self = .otimo
        case ...20: self = .bom
        case ...40: self = .fraco
        default: self = .procurando
        }
    }
}

/// Aviso curto na tela de corrida (parcial, pausa automática).
struct AvisoCorrida: Equatable, Identifiable {
    let id = UUID()
    let texto: String
    let icone: String
}

/// Rota e velocidade da simulação. A semente refaz a mesma rota se a corrida for retomada.
struct OrigemSimulada {
    var pontos: [PontoGPS]
    var multiplicador: Double
    var semente: UInt64
}

/// Liga o GPS (real ou simulado) ao motor da corrida, mantém o relógio da tela,
/// salva em disco a cada 10 s, anota o diagnóstico do GPS e grava a corrida no
/// histórico no fim. Vive no `EstadoApp`, fora das telas, para continuar gravando
/// com a tela bloqueada e quando o iOS reabre o app em segundo plano.
@MainActor
@Observable
final class GravadorCorrida: Identifiable {
    nonisolated let id = UUID()

    /// Fechado por mais que isto, a corrida volta pausada em vez de seguir gravando.
    static let limiteRetomadaAutomatica: TimeInterval = 30 * 60

    private(set) var sessao: SessaoCorrida
    private(set) var agora: Date
    private(set) var qualidade: QualidadeGPS = .procurando
    private(set) var ultimoAviso: AvisoCorrida?
    private(set) var autorizacao: CLAuthorizationStatus
    private(set) var diagnostico: DiagnosticoGPS

    let simulada: Bool
    let manterTelaAcesa: Bool
    private let multiplicadorSimulacao: Double?
    private let sementeSimulacao: UInt64?
    /// Último salvamento antes de o iOS fechar o app (só em corrida recuperada).
    private let salvaEm: Date?

    /// De onde vêm os pontos da corrida (o GPS de verdade ou a rota simulada).
    private let fonte: any FonteLocalizacao
    /// GPS de verdade. Na simulação ele também liga, só para manter o app vivo com a
    /// tela bloqueada e alimentar o diagnóstico; os pontos dele não entram na corrida.
    private let gps: LocalizacaoReal
    private let relogio: any Relogio
    @ObservationIgnored private var tarefaRelogio: Task<Void, Never>?
    @ObservationIgnored private var ultimoSalvamento = Date.distantPast
    @ObservationIgnored private var observadores: [any NSObjectProtocol] = []
    @ObservationIgnored private var avisosAtivos: Set<DiagnosticoGPS.Tipo> = []

    /// Corrida nova.
    init(configuracao: ConfiguracaoCorrida, simulacao: OrigemSimulada?, manterTelaAcesa: Bool) {
        let gps = LocalizacaoReal()
        let relogio: any Relogio
        let fonte: any FonteLocalizacao
        if let simulacao {
            let acelerado = RelogioAcelerado(multiplicador: simulacao.multiplicador)
            relogio = acelerado
            fonte = LocalizacaoSimulada(pontos: simulacao.pontos, relogio: acelerado)
        } else {
            relogio = RelogioReal()
            fonte = gps
        }
        self.gps = gps
        self.relogio = relogio
        self.fonte = fonte
        self.simulada = simulacao != nil
        self.multiplicadorSimulacao = simulacao?.multiplicador
        self.sementeSimulacao = simulacao?.semente
        self.salvaEm = nil
        self.manterTelaAcesa = manterTelaAcesa
        self.sessao = SessaoCorrida(configuracao: configuracao)
        self.diagnostico = DiagnosticoGPS()
        self.agora = relogio.agora
        self.autorizacao = gps.autorizacao
        ligarFontes()
    }

    /// Corrida que estava em andamento quando o iOS fechou o app.
    init(recuperada salva: SessaoSalva, manterTelaAcesa: Bool) {
        let gps = LocalizacaoReal()
        let relogio: any Relogio
        let fonte: any FonteLocalizacao
        if salva.simulada {
            let multiplicador = salva.multiplicador ?? 10
            let semente = salva.sementeSimulacao ?? 1
            // O relógio da simulação continua do instante salvo: o tempo fechado não existe para ela.
            let acelerado = RelogioAcelerado(multiplicador: multiplicador, comecandoEm: salva.salvaEm)
            relogio = acelerado
            fonte = LocalizacaoSimulada(pontos: Simulacao.pontos(semente: semente), relogio: acelerado, ancora: salva.sessao.inicio)
            self.multiplicadorSimulacao = multiplicador
            self.sementeSimulacao = semente
        } else {
            relogio = RelogioReal()
            fonte = gps
            self.multiplicadorSimulacao = nil
            self.sementeSimulacao = nil
        }
        self.gps = gps
        self.relogio = relogio
        self.fonte = fonte
        self.simulada = salva.simulada
        self.salvaEm = salva.salvaEm
        self.manterTelaAcesa = manterTelaAcesa
        self.sessao = salva.sessao
        self.diagnostico = salva.diagnostico ?? DiagnosticoGPS()
        self.agora = relogio.agora
        self.autorizacao = gps.autorizacao
        ligarFontes()
    }

    var permissaoNegada: Bool {
        !simulada && (autorizacao == .denied || autorizacao == .restricted)
    }

    // MARK: Comandos

    /// Liga o GPS ao abrir a tela de corrida (o sinal vai firmando antes do início)
    /// e, numa corrida já começada, volta a gravar. Pode ser chamado mais de uma vez.
    func prepararGPS(reaberta: Bool = false) {
        guard sessao.estado != .finalizada else { return }
        // A Apple pede para não ligar a localização na abertura se a permissão nunca foi pedida.
        if !(reaberta && gps.autorizacao == .notDetermined) { gps.iniciar() }
        observarApp()
        if sessao.estado != .pronta { ligarGravacao() }
    }

    func iniciar() {
        guard sessao.estado == .pronta else { return }
        sessao.iniciar(em: relogio.agora)
        ligarGravacao()
        salvarSessao(forcar: true)
    }

    func pausar() {
        sessao.pausar(em: relogio.agora)
        atualizarRelogio()
        salvarSessao(forcar: true)
    }

    func retomar() {
        sessao.retomar(em: relogio.agora)
        UIApplication.shared.isIdleTimerDisabled = manterTelaAcesa
        atualizarRelogio()
        salvarSessao(forcar: true)
    }

    func finalizar() {
        sessao.finalizar(em: relogio.agora)
        pararTudo()
        atualizarRelogio()
        salvarSessao(forcar: true)
    }

    /// Fecha sem gravar (antes de começar, ou descartando no resumo).
    func descartar() {
        pararTudo()
        ArmazemSessao.apagar()
    }

    /// Grava no histórico e apaga a cópia de segurança.
    @discardableResult
    func salvar(em contexto: ModelContext, esforco: Int?) -> Corrida {
        if sessao.estado != .finalizada { finalizar() }
        let corrida = Corrida.de(sessao: sessao, simulada: simulada, esforco: esforco, agora: relogio.agora, diagnostico: diagnostico)
        contexto.insert(corrida)
        try? contexto.save()
        ArmazemSessao.apagar()
        return corrida
    }

    /// A corrida voltou depois de o iOS fechar o app (reaberto em segundo plano pelo
    /// próprio iOS ou por você). Continua do jeito que estava; se ficou fechado por
    /// muito tempo, volta pausada no último instante salvo.
    func continuarDepoisDeReaberta() {
        guard sessao.estado != .pronta, sessao.estado != .finalizada else { return }
        diagnostico.registrar(.reaberto, em: Date.now)
        if !simulada, sessao.estado == .correndo || sessao.estado == .pausadaAuto,
           let salvaEm, relogio.agora.timeIntervalSince(salvaEm) > Self.limiteRetomadaAutomatica {
            sessao.pausar(em: salvaEm)
        }
        prepararGPS(reaberta: true)
        atualizarRelogio()
        salvarSessao(forcar: true)
        ultimoAviso = AvisoCorrida(
            texto: sessao.estado == .pausadaManual ? "Corrida recuperada (pausada)" : "Corrida recuperada",
            icone: "arrow.clockwise.circle.fill"
        )
    }

    func salvarSessao(forcar: Bool) {
        guard sessao.estado != .pronta else { return }
        let instante = Date.now
        guard forcar || instante.timeIntervalSince(ultimoSalvamento) >= 10 else { return }
        ultimoSalvamento = instante
        ArmazemSessao.salvar(SessaoSalva(
            sessao: sessao,
            simulada: simulada,
            salvaEm: relogio.agora,
            diagnostico: diagnostico,
            multiplicador: multiplicadorSimulacao,
            sementeSimulacao: sementeSimulacao
        ))
    }

    // MARK: Internos

    private func ligarFontes() {
        if simulada { qualidade = .simulado }
        fonte.aoLer = { [weak self] leitura in self?.receberDaCorrida(leitura) }
        if simulada {
            gps.aoLer = { [weak self] leitura in self?.anotar(leitura) }
        }
        gps.aoMudarAutorizacao = { [weak self] status in self?.autorizacao = status }
    }

    private func ligarGravacao() {
        fonte.iniciar()
        UIApplication.shared.isIdleTimerDisabled = manterTelaAcesa
        comecarRelogio()
        atualizarRelogio()
    }

    private func receberDaCorrida(_ leitura: LeituraGPS) {
        if !simulada {
            anotar(leitura)
            if leitura.semSinal { qualidade = .procurando }
        }
        if let ponto = leitura.ponto {
            if !simulada { qualidade = QualidadeGPS(precisao: ponto.precisaoHorizontal) }
            tratar(sessao.receber(ponto))
        }
        if leitura.parado, !simulada {
            tratar(sessao.marcarParado(em: leitura.instante))
        }
        atualizarRelogio()
    }

    /// Diagnóstico: pontos com o app na frente e em segundo plano, e cada aviso do iOS
    /// quando ele começa (o iOS repete o mesmo aviso a cada atualização).
    private func anotar(_ leitura: LeituraGPS) {
        guard sessao.estado != .pronta, sessao.estado != .finalizada else { return }
        if leitura.ponto != nil {
            let fundo = UIApplication.shared.applicationState == .background
            diagnostico.registrarPonto(em: leitura.instante, segundoPlano: fundo)
        }
        let sinais: [(DiagnosticoGPS.Tipo, Bool)] = [
            (.parado, leitura.parado),
            (.semSinal, leitura.semSinal),
            (.usoInsuficiente, leitura.usoInsuficiente),
            (.precisaoReduzida, leitura.precisaoReduzida),
            (.semPermissao, leitura.semPermissao),
        ]
        for (tipo, ligado) in sinais {
            if ligado, !avisosAtivos.contains(tipo) {
                avisosAtivos.insert(tipo)
                diagnostico.registrar(tipo, em: leitura.instante)
            } else if !ligado {
                avisosAtivos.remove(tipo)
            }
        }
    }

    private func tratar(_ eventos: [EventoCorrida]) {
        for evento in eventos {
            switch evento {
            case .pausouSozinha:
                ultimoAviso = AvisoCorrida(texto: "Pausa automática", icone: "pause.circle.fill")
            case .retomouSozinha:
                ultimoAviso = AvisoCorrida(texto: "Retomando", icone: "play.circle.fill")
            case let .parcial(numero, duracao):
                ultimoAviso = AvisoCorrida(texto: "Km \(numero) · \(Formatador.duracao(duracao))", icone: "flag.fill")
            }
        }
    }

    private func observarApp() {
        guard observadores.isEmpty else { return }
        let centro = NotificationCenter.default
        observadores.append(centro.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.mudouDePlano(segundoPlano: true) }
        })
        observadores.append(centro.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.mudouDePlano(segundoPlano: false) }
        })
    }

    private func mudouDePlano(segundoPlano: Bool) {
        guard sessao.estado != .pronta, sessao.estado != .finalizada else { return }
        diagnostico.registrar(segundoPlano ? .segundoPlano : .primeiroPlano, em: Date.now)
        atualizarRelogio()
        if segundoPlano { salvarSessao(forcar: true) }
    }

    private func comecarRelogio() {
        tarefaRelogio?.cancel()
        tarefaRelogio = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.atualizarRelogio()
                self.salvarSessao(forcar: false)
            }
        }
    }

    private func atualizarRelogio() {
        agora = relogio.agora
    }

    private func pararTudo() {
        fonte.parar()
        gps.parar()
        tarefaRelogio?.cancel()
        tarefaRelogio = nil
        for observador in observadores { NotificationCenter.default.removeObserver(observador) }
        observadores.removeAll()
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
