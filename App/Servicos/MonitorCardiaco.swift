import CoreBluetooth
import CrunningCore
import Foundation
import Observation

/// Lê o batimento que a Mi Band transmite no anúncio Bluetooth (com a transmissão de
/// frequência cardíaca ligada no app oficial da pulseira). Não pareia, não conecta e não
/// fala com servidor nenhum: só escuta os anúncios da pulseira escolhida.
///
/// Limite do iOS: anúncio sem serviço declarado só chega com o app na frente. Com a tela
/// acesa (padrão do CRUNNING na corrida) funciona; com a tela bloqueada, a leitura para e
/// volta quando o app reaparece.
@MainActor
@Observable
final class MonitorCardiaco: NSObject {
    static let compartilhado = MonitorCardiaco()

    struct Encontrada: Identifiable, Equatable {
        let id: UUID
        var nome: String
        var bpm: Int?
        var bruto: String
        var vistaEm: Date
    }

    /// Último batimento da pulseira escolhida e quando chegou.
    private(set) var bpm: Int?
    private(set) var lidoEm: Date?
    /// Pulseiras Xiaomi ouvidas na procura (tela de escolher a pulseira).
    private(set) var encontradas: [Encontrada] = []
    private(set) var bluetoothLigado = false
    private(set) var semPermissao = false

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var querOuvir = false
    @ObservationIgnored private var procurando = false

    /// Pulseira escolhida (identificador que o iOS dá a ela neste iPhone).
    var pulseira: UUID? {
        UserDefaults.standard.string(forKey: Preferencias.pulseiraFC).flatMap(UUID.init(uuidString:))
    }

    var nomePulseira: String? { UserDefaults.standard.string(forKey: Preferencias.nomePulseiraFC) }

    /// Usar na corrida: pulseira escolhida e a opção ligada em Ajustes.
    var usarNaCorrida: Bool {
        pulseira != nil && (UserDefaults.standard.object(forKey: Preferencias.usarFC) as? Bool ?? true)
    }

    /// Batimento atual, se chegou há no máximo 5 segundos.
    func atual(agora: Date = .now) -> Int? {
        guard let bpm, let lidoEm, agora.timeIntervalSince(lidoEm) <= 5 else { return nil }
        return bpm
    }

    func escolher(_ encontrada: Encontrada) {
        UserDefaults.standard.set(encontrada.id.uuidString, forKey: Preferencias.pulseiraFC)
        UserDefaults.standard.set(encontrada.nome, forKey: Preferencias.nomePulseiraFC)
        bpm = encontrada.bpm
        lidoEm = encontrada.bpm == nil ? nil : encontrada.vistaEm
    }

    func esquecer() {
        UserDefaults.standard.removeObject(forKey: Preferencias.pulseiraFC)
        UserDefaults.standard.removeObject(forKey: Preferencias.nomePulseiraFC)
        bpm = nil
        lidoEm = nil
    }

    /// Começa a ouvir. `procura` também lista as pulseiras por perto.
    func ligar(procura: Bool = false) {
        querOuvir = true
        procurando = procurando || procura
        if procura { encontradas = [] }
        if central == nil {
            // Cria o gerenciador só quando precisa: é aqui que o iOS pede a permissão de Bluetooth.
            central = CBCentralManager(delegate: self, queue: nil)
        } else {
            comecarSePuder()
        }
    }

    func pararProcura() {
        procurando = false
    }

    func desligar() {
        querOuvir = false
        procurando = false
        central?.stopScan()
    }

    private func comecarSePuder() {
        guard querOuvir, let central, central.state == .poweredOn else { return }
        // Repetidos ligados: cada anúncio novo traz o batimento atualizado.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    fileprivate func mudouEstado(_ estado: CBManagerState) {
        bluetoothLigado = estado == .poweredOn
        semPermissao = estado == .unauthorized
        comecarSePuder()
    }

    fileprivate func recebeu(id: UUID, nome: String, bytes: [UInt8]) {
        guard FrequenciaCardiaca.ehXiaomi(bytes) else { return }
        let lido = FrequenciaCardiaca.lerAnuncioMiBand(bytes)
        let agora = Date.now
        if id == pulseira, let lido {
            bpm = lido
            lidoEm = agora
        }
        guard procurando else { return }
        let bruto = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        let item = Encontrada(id: id, nome: nome, bpm: lido, bruto: bruto, vistaEm: agora)
        if let i = encontradas.firstIndex(where: { $0.id == id }) {
            // Atualiza no máximo a cada meio segundo, para a lista não piscar.
            if agora.timeIntervalSince(encontradas[i].vistaEm) >= 0.5 { encontradas[i] = item }
        } else {
            encontradas.append(item)
        }
    }
}

extension MonitorCardiaco: CBCentralManagerDelegate {
    // O gerenciador foi criado com a fila principal, então os retornos chegam nela.
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let estado = central.state
        MainActor.assumeIsolated { self.mudouEstado(estado) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard let dados = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else { return }
        let bytes = [UInt8](dados)
        let id = peripheral.identifier
        let nome = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? L("Pulseira Xiaomi", "Xiaomi band")
        MainActor.assumeIsolated { self.recebeu(id: id, nome: nome, bytes: bytes) }
    }
}
