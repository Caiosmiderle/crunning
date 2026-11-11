import CoreBluetooth
import CrunningCore
import Foundation
import Observation

/// Lê o batimento da Mi Band (com a transmissão de frequência cardíaca ligada no app oficial
/// da pulseira) por dois caminhos, sem parear e sem servidor nenhum:
///
/// 1. Conexão ao serviço de frequência cardíaca padrão do Bluetooth (0x180D, medição 0x2A37),
///    o mesmo que apps como Wahoo e RunKeeper usam. Com o modo de segundo plano
///    `bluetooth-central`, continua com a tela bloqueada.
/// 2. Anúncio da pulseira (dados de fabricante da Xiaomi). Sem serviço declarado, o iOS só
///    entrega com o app na frente: fica como reserva com a tela acesa.
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
    /// Conectada ao serviço padrão: o batimento continua com a tela bloqueada.
    private(set) var conectada = false

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var querOuvir = false
    @ObservationIgnored private var procurando = false
    /// A pulseira escolhida, guardada enquanto a conexão é pedida ou está aberta.
    @ObservationIgnored private var periferico: CBPeripheral?

    nonisolated static let servicoFC = "180D"
    nonisolated static let medicaoFC = "2A37"

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
        desconectar()
        conectarSePuder()
    }

    func esquecer() {
        desconectar()
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
        desconectar()
    }

    private func comecarSePuder() {
        guard querOuvir, let central, central.state == .poweredOn else { return }
        // Repetidos ligados: cada anúncio novo traz o batimento atualizado.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        conectarSePuder()
    }

    /// Pede a conexão à pulseira escolhida. O pedido não expira: se ela estiver longe ou ocupada,
    /// o iOS conecta quando der, também em segundo plano.
    private func conectarSePuder() {
        guard querOuvir, let central, central.state == .poweredOn, let id = pulseira else { return }
        if let periferico, periferico.identifier == id, periferico.state != .disconnected { return }
        guard let alvo = periferico?.identifier == id ? periferico : central.retrievePeripherals(withIdentifiers: [id]).first else { return }
        periferico = alvo
        alvo.delegate = self
        central.connect(alvo)
    }

    private func desconectar() {
        if let periferico { central?.cancelPeripheralConnection(periferico) }
        periferico = nil
        conectada = false
    }

    fileprivate func conectou(_ id: UUID) {
        guard id == periferico?.identifier else { return }
        periferico?.discoverServices([CBUUID(string: Self.servicoFC)])
    }

    fileprivate func caiu(_ id: UUID) {
        guard id == periferico?.identifier else { return }
        conectada = false
        // Durante a corrida, volta a pedir a conexão (a pulseira pode ter ficado fora de alcance).
        if querOuvir, let central, let periferico { central.connect(periferico) }
    }

    fileprivate func assinando(_ id: UUID) {
        guard id == periferico?.identifier else { return }
        conectada = true
    }

    fileprivate func mediu(_ id: UUID, bytes: [UInt8]) {
        guard id == pulseira, let lido = FrequenciaCardiaca.lerMedicaoPadrao(bytes) else { return }
        conectada = true
        bpm = lido
        lidoEm = .now
    }

    fileprivate func mudouEstado(_ estado: CBManagerState) {
        bluetoothLigado = estado == .poweredOn
        semPermissao = estado == .unauthorized
        if estado != .poweredOn { conectada = false }
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

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let id = peripheral.identifier
        MainActor.assumeIsolated { self.conectou(id) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        let id = peripheral.identifier
        MainActor.assumeIsolated { self.caiu(id) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        let id = peripheral.identifier
        MainActor.assumeIsolated { self.caiu(id) }
    }
}

extension MonitorCardiaco: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        for servico in peripheral.services ?? [] where servico.uuid == CBUUID(string: Self.servicoFC) {
            peripheral.discoverCharacteristics([CBUUID(string: Self.medicaoFC)], for: servico)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        for c in service.characteristics ?? [] where c.uuid == CBUUID(string: Self.medicaoFC) {
            peripheral.setNotifyValue(true, for: c)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard error == nil, characteristic.isNotifying else { return }
        let id = peripheral.identifier
        MainActor.assumeIsolated { self.assinando(id) }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard error == nil, characteristic.uuid == CBUUID(string: Self.medicaoFC), let dados = characteristic.value else { return }
        let id = peripheral.identifier
        let bytes = [UInt8](dados)
        MainActor.assumeIsolated { self.mediu(id, bytes: bytes) }
    }
}
