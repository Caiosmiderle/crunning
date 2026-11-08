import CoreLocation
import CrunningCore
import Foundation

/// De onde vêm os pontos: GPS de verdade ou uma rota simulada.
@MainActor
protocol FonteLocalizacao: AnyObject {
    var aoReceber: ((PontoGPS) -> Void)? { get set }
    var aoMudarAutorizacao: ((CLAuthorizationStatus) -> Void)? { get set }
    var autorizacao: CLAuthorizationStatus { get }
    func pedirAutorizacao()
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

/// GPS do iPhone, configurado para corrida e para continuar com a tela bloqueada
/// (modo de segundo plano "location" no Info.plist + indicador azul).
@MainActor
final class LocalizacaoReal: NSObject, FonteLocalizacao, CLLocationManagerDelegate {
    var aoReceber: ((PontoGPS) -> Void)?
    var aoMudarAutorizacao: ((CLAuthorizationStatus) -> Void)?

    private let gerente = CLLocationManager()
    private var sessaoFundo: CLBackgroundActivitySession?
    private var ativo = false

    override init() {
        super.init()
        gerente.delegate = self
        gerente.activityType = .fitness
        gerente.desiredAccuracy = kCLLocationAccuracyBest
        gerente.distanceFilter = kCLDistanceFilterNone
        gerente.pausesLocationUpdatesAutomatically = false
        gerente.showsBackgroundLocationIndicator = true
    }

    var autorizacao: CLAuthorizationStatus { gerente.authorizationStatus }

    func pedirAutorizacao() {
        gerente.requestWhenInUseAuthorization()
    }

    func iniciar() {
        ativo = true
        guard autorizacao == .authorizedWhenInUse || autorizacao == .authorizedAlways else {
            if autorizacao == .notDetermined { pedirAutorizacao() }
            return
        }
        gerente.allowsBackgroundLocationUpdates = true
        if sessaoFundo == nil { sessaoFundo = CLBackgroundActivitySession() }
        gerente.startUpdatingLocation()
    }

    func parar() {
        ativo = false
        gerente.stopUpdatingLocation()
        gerente.allowsBackgroundLocationUpdates = false
        sessaoFundo?.invalidate()
        sessaoFundo = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let pontos = locations.map(PontoGPS.init(local:))
        MainActor.assumeIsolated {
            for ponto in pontos { aoReceber?(ponto) }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            aoMudarAutorizacao?(status)
            // Pediu para iniciar antes da permissão: começa assim que ela chega.
            if ativo, status == .authorizedWhenInUse || status == .authorizedAlways {
                iniciar()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // Falhas temporárias (sem sinal) não param a corrida; o GPS volta sozinho.
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
    let multiplicador: Double

    init(multiplicador: Double) {
        self.multiplicador = max(1, multiplicador)
    }

    var agora: Date {
        inicioReal.addingTimeInterval(Date.now.timeIntervalSince(inicioReal) * multiplicador)
    }
}

/// Reproduz uma rota (gerada ou importada de um .gpx) como se fosse o GPS,
/// no ritmo do relógio acelerado.
@MainActor
final class LocalizacaoSimulada: FonteLocalizacao {
    var aoReceber: ((PontoGPS) -> Void)?
    var aoMudarAutorizacao: ((CLAuthorizationStatus) -> Void)?
    var autorizacao: CLAuthorizationStatus { .authorizedWhenInUse }

    private let pontos: [PontoGPS]
    private let relogio: any Relogio
    private var tarefa: Task<Void, Never>?

    init(pontos: [PontoGPS], relogio: any Relogio) {
        self.pontos = pontos
        self.relogio = relogio
    }

    func pedirAutorizacao() {}

    func iniciar() {
        guard tarefa == nil, let base = pontos.first?.instante else { return }
        let inicioVirtual = relogio.agora
        tarefa = Task { [weak self] in
            guard let self else { return }
            for ponto in self.pontos {
                let alvo = inicioVirtual.addingTimeInterval(ponto.instante.timeIntervalSince(base))
                while self.relogio.agora < alvo {
                    try? await Task.sleep(for: .milliseconds(50))
                    if Task.isCancelled { return }
                }
                var reprogramado = ponto
                reprogramado.instante = alvo
                self.aoReceber?(reprogramado)
            }
        }
    }

    func parar() {
        tarefa?.cancel()
        tarefa = nil
    }
}
