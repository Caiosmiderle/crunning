import CoreLocation
import CrunningCore
import Foundation

/// Uma entrega da fonte de localização: o ponto (se veio) e os avisos do iOS.
struct LeituraGPS: Sendable {
    var instante: Date
    var ponto: PontoGPS?
    var parado = false
    var semSinal = false
    var usoInsuficiente = false
    var precisaoReduzida = false
    var semPermissao = false
}

/// De onde vêm os pontos: GPS de verdade ou uma rota simulada.
@MainActor
protocol FonteLocalizacao: AnyObject {
    var aoLer: ((LeituraGPS) -> Void)? { get set }
    func iniciar()
    func parar()
}

extension PontoGPS {
    init(local: CLLocation) {
        self.init(
            instante: local.timestamp,
            latitude: local.coordinate.latitude,
            longitude: local.coordinate.longitude,
            altitude: local.verticalAccuracy >= 0 ? local.altitude : nil,
            precisaoHorizontal: local.horizontalAccuracy,
            precisaoVertical: local.verticalAccuracy >= 0 ? local.verticalAccuracy : nil,
            velocidade: local.speed >= 0 ? local.speed : nil
        )
    }
}

extension LeituraGPS {
    init(_ atualizacao: CLLocationUpdate) {
        let ponto = atualizacao.location.map(PontoGPS.init(local:))
        self.init(
            instante: ponto?.instante ?? .now,
            ponto: ponto,
            parado: atualizacao.stationary,
            semSinal: atualizacao.locationUnavailable,
            usoInsuficiente: atualizacao.insufficientlyInUse,
            precisaoReduzida: atualizacao.accuracyLimited,
            semPermissao: atualizacao.authorizationDenied || atualizacao.authorizationDeniedGlobally
                || atualizacao.authorizationRestricted
        )
    }
}

/// GPS do iPhone pelo caminho que a Apple indica para treino com a tela bloqueada:
/// `CLServiceSession` (permissão "durante o uso"), `CLBackgroundActivitySession`
/// (mantém o app "em uso" em segundo plano, com o indicador azul) e
/// `CLLocationUpdate.liveUpdates(.fitness)`. Se o iOS fechar o app no meio, ele o
/// reabre em segundo plano quando há localização nova; aí o app recria as sessões
/// logo na abertura (veja `EstadoApp.restaurarCorridaPendente`) e a gravação continua.
@MainActor
final class LocalizacaoReal: NSObject, FonteLocalizacao, CLLocationManagerDelegate {
    var aoLer: ((LeituraGPS) -> Void)?
    var aoMudarAutorizacao: ((CLAuthorizationStatus) -> Void)?

    /// Só para ler e acompanhar a permissão; os pontos vêm do `liveUpdates`.
    private let gerente = CLLocationManager()
    private var sessaoServico: CLServiceSession?
    private var sessaoFundo: CLBackgroundActivitySession?
    private var tarefa: Task<Void, Never>?

    override init() {
        super.init()
        gerente.delegate = self
    }

    var autorizacao: CLAuthorizationStatus { gerente.authorizationStatus }

    var ativo: Bool { tarefa != nil }

    func iniciar() {
        guard tarefa == nil else { return }
        // As sessões vêm antes das atualizações. A de serviço pede a permissão "durante o uso"
        // se ainda não foi dada; a de segundo plano mantém o app recebendo com a tela bloqueada.
        if sessaoServico == nil { sessaoServico = CLServiceSession(authorization: .whenInUse) }
        if sessaoFundo == nil { sessaoFundo = CLBackgroundActivitySession() }
        let entregar: @MainActor @Sendable (LeituraGPS) -> Void = { [weak self] leitura in
            self?.aoLer?(leitura)
        }
        tarefa = Task { await Self.escutar(entregar: entregar) }
    }

    func parar() {
        tarefa?.cancel()
        tarefa = nil
        sessaoFundo?.invalidate()
        sessaoFundo = nil
        sessaoServico?.invalidate()
        sessaoServico = nil
    }

    /// Lê as atualizações fora da thread principal e entrega cada uma já convertida.
    nonisolated private static func escutar(entregar: @escaping @MainActor @Sendable (LeituraGPS) -> Void) async {
        do {
            for try await atualizacao in CLLocationUpdate.liveUpdates(.fitness) {
                if Task.isCancelled { break }
                let leitura = LeituraGPS(atualizacao)
                await entregar(leitura)
            }
        } catch {
            // A sequência só termina com erro em falha grave do serviço; a corrida
            // continua com o que já tem e o diagnóstico mostra o buraco.
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            aoMudarAutorizacao?(status)
        }
    }
}

/// Relógio da gravação: o real, ou um acelerado para a simulação.
@MainActor
protocol Relogio: AnyObject {
    var agora: Date { get }
}

@MainActor
final class RelogioReal: Relogio {
    var agora: Date { Date.now }
}

@MainActor
final class RelogioAcelerado: Relogio {
    private let inicioReal = Date.now
    /// Onde o relógio da simulação começa (o instante salvo, quando a simulação é retomada).
    private let inicioVirtual: Date
    let multiplicador: Double

    init(multiplicador: Double, comecandoEm inicioVirtual: Date? = nil) {
        self.multiplicador = max(1, multiplicador)
        self.inicioVirtual = inicioVirtual ?? inicioReal
    }

    var agora: Date {
        inicioVirtual.addingTimeInterval(Date.now.timeIntervalSince(inicioReal) * multiplicador)
    }
}

/// Reproduz uma rota (gerada ou importada de um .gpx) como se fosse o GPS,
/// no ritmo do relógio acelerado.
@MainActor
final class LocalizacaoSimulada: FonteLocalizacao {
    var aoLer: ((LeituraGPS) -> Void)?

    private let pontos: [PontoGPS]
    private let relogio: any Relogio
    /// Início da corrida simulada, quando ela é retomada depois de o iOS fechar o app:
    /// a rota continua do ponto em que parou em vez de recomeçar.
    private let ancora: Date?
    private var tarefa: Task<Void, Never>?

    init(pontos: [PontoGPS], relogio: any Relogio, ancora: Date? = nil) {
        self.pontos = pontos
        self.relogio = relogio
        self.ancora = ancora
    }

    func iniciar() {
        guard tarefa == nil, let base = pontos.first?.instante else { return }
        let inicioVirtual = ancora ?? relogio.agora
        let jaPassou = ancora == nil ? nil : relogio.agora
        tarefa = Task { [weak self] in
            guard let self else { return }
            for ponto in self.pontos {
                let alvo = inicioVirtual.addingTimeInterval(ponto.instante.timeIntervalSince(base))
                if let jaPassou, alvo <= jaPassou { continue }
                while self.relogio.agora < alvo {
                    try? await Task.sleep(for: .milliseconds(50))
                    if Task.isCancelled { return }
                }
                var reprogramado = ponto
                reprogramado.instante = alvo
                self.aoLer?(LeituraGPS(instante: alvo, ponto: reprogramado))
            }
        }
    }

    func parar() {
        tarefa?.cancel()
        tarefa = nil
    }
}
