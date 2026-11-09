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
    case esteira

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

/// Sem fonte de pontos: corrida na esteira (o GPS liga só para manter o app vivo com a tela bloqueada).
@MainActor
final class FonteNenhuma: FonteLocalizacao {
    var aoLer: ((LeituraGPS) -> Void)?
    func iniciar() {}
    func parar() {}
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
    /// Treino por blocos em andamento (nil na corrida livre).
    private(set) var execucao: ExecucaoTreino?
    /// Sobe a cada troca de etapa (anima a tela).
    private(set) var transicoes = 0
    /// Número da contagem regressiva na tela (3, 2, 1), ou nil.
    private(set) var contagemVisivel: Int?
    /// Sessão do plano que esta corrida cumpre (marcada como feita ao salvar).
    var sessaoPlano: (semana: Int, dia: Int)?

    let simulada: Bool
    let esteira: Bool
    /// Lidos de novo quando as preferências mudam no meio da corrida.
    private(set) var avisos: AvisosCorrida
    private(set) var manterTelaAcesa: Bool
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
    private let locutor = Locutor.compartilhado
    private let atividade = AtividadeAoVivo()
    @ObservationIgnored private var contagemEm: Date?

    /// Corrida nova.
    init(configuracao: ConfiguracaoCorrida, simulacao: OrigemSimulada?, manterTelaAcesa: Bool,
         execucao: ExecucaoTreino? = nil, esteira: Bool = false) {
        let gps = LocalizacaoReal()
        let relogio: any Relogio
        let fonte: any FonteLocalizacao
        if esteira {
            relogio = RelogioReal()
            fonte = FonteNenhuma()
        } else if let simulacao {
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
        self.execucao = execucao
        self.esteira = esteira
        self.avisos = AvisosCorrida.atuais()
        self.agora = relogio.agora
        self.autorizacao = gps.autorizacao
        ligarFontes()
    }

    /// Corrida que estava em andamento quando o iOS fechou o app.
    init(recuperada salva: SessaoSalva, manterTelaAcesa: Bool) {
        let gps = LocalizacaoReal()
        let relogio: any Relogio
        let fonte: any FonteLocalizacao
        let esteira = salva.esteira ?? false
        if esteira {
            relogio = RelogioReal()
            fonte = FonteNenhuma()
            self.multiplicadorSimulacao = nil
            self.sementeSimulacao = nil
        } else if salva.simulada {
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
        self.execucao = salva.execucao
        if let s = salva.planoSemana, let d = salva.planoDia { self.sessaoPlano = (s, d) }
        self.esteira = esteira
        self.avisos = AvisosCorrida.atuais()
        self.agora = relogio.agora
        self.autorizacao = gps.autorizacao
        ligarFontes()
    }

    var permissaoNegada: Bool {
        !simulada && !esteira && (autorizacao == .denied || autorizacao == .restricted)
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
        agora = relogio.agora
        if let nome = execucao?.treino.nome, avisos.voz { locutor.falar(Fala.inicioTreino(nome)) }
        let eventos = execucao?.iniciar(leitura()) ?? []
        tratarExecucao(eventos, interromperFala: false)
        ligarGravacao()
        salvarSessao(forcar: true)
        iniciarAtividade()
    }

    private func iniciarAtividade() {
        let titulo = execucao?.treino.nome ?? (esteira ? "Esteira" : simulada ? "Corrida simulada" : "Corrida livre")
        atividade.iniciar(titulo: titulo, esteira: esteira, estado: estadoAtividade())
    }

    /// O que a Live Activity mostra agora. Os cronômetros usam o relógio real do iPhone.
    private func estadoAtividade() -> TreinoAtividadeAtributos.ContentState {
        let l = leitura()
        let pausada = sessao.estado == .pausadaManual || sessao.estado == .pausadaAuto
        var nome = esteira ? "Esteira" : "Corrida livre"
        var detalhe: String?
        var fim: Date?
        var restanteTexto: String?
        var parado: TimeInterval?
        var progresso = 0.0
        var cor = TipoTreino.facil.hex
        if let execucao, let etapa = execucao.etapaAtual {
            nome = etapa.nome
            cor = etapa.tipo.hex
            if let k = etapa.repeticao, let n = etapa.totalRepeticoes, n > 1 {
                detalhe = "Repetição \(k) de \(n)"
            } else if let faixa = etapa.faixa {
                detalhe = "Alvo " + TextoTreino.faixa(faixa, unidade: unidade)
            }
            progresso = execucao.progressoTotal(l)
            let resta = max(0, execucao.restante(l) ?? 0)
            switch etapa.medida {
            case .tempo:
                if pausada { parado = resta } else { fim = Date.now.addingTimeInterval(resta) }
            case .distancia:
                restanteTexto = resta < 1000 ? "\(Int(resta.rounded())) m" : Formatador.distancia(resta, casas: 2)
            }
        } else if execucao?.terminou == true {
            nome = "Treino concluído"
            progresso = 1
            cor = TipoTreino.prova.hex
        }
        var inicio: Date?
        if fim == nil, restanteTexto == nil, parado == nil {
            let movimento = sessao.tempoEmMovimento(em: agora)
            if pausada { parado = movimento } else { inicio = Date.now.addingTimeInterval(-movimento) }
        }
        return TreinoAtividadeAtributos.ContentState(
            nomeBloco: nome, detalhe: detalhe, fimDoBloco: fim, restanteTexto: restanteTexto,
            inicioCronometro: inicio, tempoParado: parado,
            distanciaMetros: esteira ? 0 : sessao.distancia,
            ritmoSegundosPorKm: esteira ? nil : sessao.ritmoAtual(em: agora),
            progresso: progresso, pausada: pausada, corHex: cor
        )
    }

    /// Pula a etapa atual do treino (a tela confirma antes, menos nos exercícios do aquecimento).
    func pularEtapa() {
        guard execucao != nil, sessao.estado != .pronta, sessao.estado != .finalizada else { return }
        agora = relogio.agora
        let eventos = execucao?.pular(leitura()) ?? []
        tratarExecucao(eventos)
        salvarSessao(forcar: true)
    }

    /// Volta manual: anuncia o tempo e a distância desde a volta anterior.
    func marcarVolta() {
        guard execucao != nil, sessao.estado != .pronta, sessao.estado != .finalizada else { return }
        agora = relogio.agora
        let eventos = execucao?.marcarVolta(leitura()) ?? []
        tratarExecucao(eventos)
        salvarSessao(forcar: true)
    }

    /// Leitura da gravação para o motor de blocos.
    func leitura() -> LeituraExecucao {
        LeituraExecucao(
            instante: agora,
            distancia: sessao.distancia,
            tempoMovimento: sessao.tempoEmMovimento(em: agora),
            ritmoAtual: esteira ? nil : sessao.ritmoAtual(em: agora),
            pausadaManual: sessao.estado == .pausadaManual
        )
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
        atividade.encerrar()
        agora = relogio.agora
        execucao?.encerrar(leitura())
        contagemVisivel = nil
        locutor.calar()
        sessao.finalizar(em: relogio.agora)
        pararTudo()
        atualizarRelogio()
        salvarSessao(forcar: true)
    }

    /// Fecha sem gravar (antes de começar, ou descartando no resumo).
    func descartar() {
        atividade.encerrar()
        pararTudo()
        ArmazemSessao.apagar()
    }

    /// Grava no histórico e apaga a cópia de segurança.
    @discardableResult
    func salvar(em contexto: ModelContext, esforco: Int?, distanciaEsteira: Double? = nil, tenis: String? = nil) -> Corrida {
        if sessao.estado != .finalizada { finalizar() }
        let corrida = Corrida.de(
            sessao: sessao, simulada: simulada, esforco: esforco, agora: relogio.agora,
            diagnostico: esteira ? nil : diagnostico, execucao: execucao, esteira: esteira, distanciaEsteira: distanciaEsteira
        )
        corrida.planoSemana = sessaoPlano?.semana
        corrida.planoDia = sessaoPlano?.dia
        corrida.tenis = tenis
        contexto.insert(corrida)
        try? contexto.save()
        if let s = sessaoPlano {
            PlanoAtivo.registrarFeita(semana: s.semana, dia: s.dia, esforco: esforco, em: contexto)
        }
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
        iniciarAtividade()
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
            sementeSimulacao: sementeSimulacao,
            execucao: execucao,
            esteira: esteira,
            planoSemana: sessaoPlano?.semana,
            planoDia: sessaoPlano?.dia
        ))
    }

    // MARK: Internos

    private func ligarFontes() {
        if simulada { qualidade = .simulado }
        if esteira { qualidade = .esteira }
        fonte.aoLer = { [weak self] leitura in self?.receberDaCorrida(leitura) }
        if simulada || esteira {
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
                if avisos.voz { locutor.falar("Pausa automática.") }
            case .retomouSozinha:
                ultimoAviso = AvisoCorrida(texto: "Retomando", icone: "play.circle.fill")
                if avisos.voz { locutor.falar(Fala.retomada) }
            case let .parcial(numero, duracao):
                ultimoAviso = AvisoCorrida(texto: "Km \(numero) · \(Formatador.duracao(duracao))", icone: "flag.fill")
                if avisos.voz, avisos.parciaisKm > 0, numero % avisos.parciaisKm == 0 {
                    locutor.falar(Fala.parcial(numero: numero, duracao: duracao))
                }
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
        observadores.append(centro.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.recarregarPreferencias() }
        })
    }

    /// Avisos e tela acesa mudados no meio da corrida (engrenagem da tela de corrida ou aba
    /// Ajustes com a corrida minimizada) valem na hora.
    private func recarregarPreferencias() {
        let novos = AvisosCorrida.atuais()
        if novos != avisos {
            if avisos.voz, !novos.voz { locutor.calar() }
            avisos = novos
        }
        let tela = UserDefaults.standard.object(forKey: Preferencias.telaAcesa) as? Bool ?? true
        if tela != manterTelaAcesa {
            manterTelaAcesa = tela
            if sessao.estado == .correndo || sessao.estado == .pausadaAuto || sessao.estado == .pausadaManual {
                UIApplication.shared.isIdleTimerDisabled = tela
            }
        }
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
        avancarExecucao()
        if sessao.estado != .pronta, sessao.estado != .finalizada, atividade.ativa {
            atividade.atualizar(estadoAtividade())
        }
    }

    // MARK: Treino por blocos

    private func avancarExecucao() {
        guard execucao != nil, sessao.estado != .pronta, sessao.estado != .finalizada else { return }
        let eventos = execucao?.atualizar(leitura()) ?? []
        tratarExecucao(eventos)
    }

    private var unidade: UnidadeDistancia {
        UnidadeDistancia(rawValue: UserDefaults.standard.string(forKey: Preferencias.unidade) ?? "") ?? .quilometros
    }

    private func tratarExecucao(_ eventos: [EventoExecucao], interromperFala: Bool = true) {
        guard let execucao else { return }
        for evento in eventos {
            switch evento {
            case let .comecouEtapa(i):
                transicoes += 1
                contagemVisivel = nil
                if avisos.vibracao { locutor.vibrar() }
                if avisos.bipe { locutor.bipe(longo: true) }
                if avisos.voz { locutor.falar(Fala.etapa(execucao.etapas[i], unidade: unidade), interromper: interromperFala) }
                salvarSessao(forcar: true)
            case let .contagem(n):
                contagemVisivel = n
                contagemEm = agora
                if avisos.contagem {
                    if avisos.bipe { locutor.bipe(longo: false) }
                    if avisos.voz { locutor.falar(Fala.contagem(n)) }
                }
            case let .ritmo(aviso):
                guard avisos.ritmo else { continue }
                switch aviso {
                case .acelerar: ultimoAviso = AvisoCorrida(texto: "Acelere um pouco", icone: "hare.fill")
                case .reduzir: ultimoAviso = AvisoCorrida(texto: "Reduza um pouco", icone: "tortoise.fill")
                case .voltouAoRitmo: ultimoAviso = AvisoCorrida(texto: "No ritmo", icone: "checkmark.circle.fill")
                }
                if avisos.voz { locutor.falar(Fala.ritmo(aviso)) }
            case let .volta(numero, duracao, distancia):
                ultimoAviso = AvisoCorrida(texto: "Volta \(numero) · \(Formatador.duracao(duracao))", icone: "flag.2.crossed.fill")
                if avisos.voz { locutor.falar(Fala.volta(numero: numero, duracao: duracao, distancia: distancia)) }
            case .terminouTreino:
                transicoes += 1
                contagemVisivel = nil
                ultimoAviso = AvisoCorrida(texto: "Treino concluído", icone: "checkmark.seal.fill")
                if avisos.vibracao { locutor.vibrar() }
                if avisos.voz { locutor.falar(Fala.fimTreino, interromper: true) }
                salvarSessao(forcar: true)
            }
        }
        // A contagem some da tela se a etapa não acabou logo depois (ritmo caiu numa etapa por distância, pausa).
        if contagemVisivel != nil, let em = contagemEm, agora.timeIntervalSince(em) > 1.5 {
            contagemVisivel = nil
        }
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
