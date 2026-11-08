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

/// Liga o GPS (real ou simulado) ao motor da corrida, mantém o relógio da tela,
/// salva em disco a cada 10 s e grava a corrida no histórico no fim.
@MainActor
@Observable
final class GravadorCorrida: Identifiable {
    nonisolated let id = UUID()

    private(set) var sessao: SessaoCorrida
    private(set) var agora: Date
    private(set) var qualidade: QualidadeGPS = .procurando
    private(set) var ultimoAviso: AvisoCorrida?
    private(set) var autorizacao: CLAuthorizationStatus

    let simulada: Bool
    let manterTelaAcesa: Bool

    private let fonte: any FonteLocalizacao
    private let relogio: any Relogio
    @ObservationIgnored private var tarefaRelogio: Task<Void, Never>?
    @ObservationIgnored private var ultimoSalvamento = Date.distantPast

    init(
        configuracao: ConfiguracaoCorrida,
        pontosSimulados: [PontoGPS]?,
        multiplicadorSimulacao: Double,
        manterTelaAcesa: Bool,
        sessaoRecuperada: SessaoCorrida? = nil
    ) {
        let relogio: any Relogio
        let fonte: any FonteLocalizacao
        if let pontosSimulados {
            let acelerado = RelogioAcelerado(multiplicador: multiplicadorSimulacao)
            relogio = acelerado
            fonte = LocalizacaoSimulada(pontos: pontosSimulados, relogio: acelerado)
        } else {
            relogio = RelogioReal()
            fonte = LocalizacaoReal()
        }
        self.relogio = relogio
        self.fonte = fonte
        self.simulada = pontosSimulados != nil
        self.manterTelaAcesa = manterTelaAcesa
        self.sessao = sessaoRecuperada ?? SessaoCorrida(configuracao: configuracao)
        self.agora = relogio.agora
        self.autorizacao = fonte.autorizacao
        if simulada { qualidade = .simulado }

        fonte.aoReceber = { [weak self] ponto in self?.receber(ponto) }
        fonte.aoMudarAutorizacao = { [weak self] status in self?.autorizacao = status }
    }

    var permissaoNegada: Bool {
        !simulada && (autorizacao == .denied || autorizacao == .restricted)
    }

    // MARK: Comandos

    /// Liga o GPS ao abrir a tela (o sinal vai firmando antes do início).
    func prepararGPS() {
        if !simulada { fonte.iniciar() }
        if sessao.estado != .pronta { comecarRelogio() }
    }

    func iniciar() {
        guard sessao.estado == .pronta else { return }
        sessao.iniciar(em: relogio.agora)
        if simulada { fonte.iniciar() }
        UIApplication.shared.isIdleTimerDisabled = manterTelaAcesa
        comecarRelogio()
        atualizarRelogio()
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
        let corrida = Corrida.de(sessao: sessao, simulada: simulada, esforco: esforco, agora: relogio.agora)
        contexto.insert(corrida)
        try? contexto.save()
        ArmazemSessao.apagar()
        return corrida
    }

    func salvarSessao(forcar: Bool) {
        guard sessao.estado != .pronta else { return }
        let instante = Date.now
        guard forcar || instante.timeIntervalSince(ultimoSalvamento) >= 10 else { return }
        ultimoSalvamento = instante
        ArmazemSessao.salvar(SessaoSalva(sessao: sessao, simulada: simulada, salvaEm: relogio.agora))
    }

    // MARK: Internos

    private func receber(_ ponto: PontoGPS) {
        if !simulada { qualidade = QualidadeGPS(precisao: ponto.precisaoHorizontal) }
        for evento in sessao.receber(ponto) {
            switch evento {
            case .pausouSozinha:
                ultimoAviso = AvisoCorrida(texto: "Pausa automática", icone: "pause.circle.fill")
            case .retomouSozinha:
                ultimoAviso = AvisoCorrida(texto: "Retomando", icone: "play.circle.fill")
            case let .parcial(numero, duracao):
                ultimoAviso = AvisoCorrida(texto: "Km \(numero) · \(Formatador.duracao(duracao))", icone: "flag.fill")
            }
        }
        atualizarRelogio()
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
        tarefaRelogio?.cancel()
        tarefaRelogio = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
