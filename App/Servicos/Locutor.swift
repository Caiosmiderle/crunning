import AudioToolbox
import AVFoundation
import Foundation

/// O que avisar durante a corrida (Ajustes > Avisos durante a corrida).
struct AvisosCorrida {
    var voz: Bool
    var contagem: Bool
    var ritmo: Bool
    var vibracao: Bool
    /// Parcial falada a cada N km (0 = desligado).
    var parciaisKm: Int

    static func atuais() -> AvisosCorrida {
        let d = UserDefaults.standard
        return AvisosCorrida(
            voz: d.object(forKey: Preferencias.avisoVoz) as? Bool ?? true,
            contagem: d.object(forKey: Preferencias.avisoContagem) as? Bool ?? true,
            ritmo: d.object(forKey: Preferencias.avisoRitmo) as? Bool ?? true,
            vibracao: d.object(forKey: Preferencias.avisoVibracao) as? Bool ?? true,
            parciaisKm: d.object(forKey: Preferencias.avisoParciais) as? Int ?? 1
        )
    }
}

/// Voz, bipes e vibração da corrida. A sessão de áudio abaixa a música e pausa podcast só
/// enquanto fala, e devolve o volume no fim. Funciona com a tela bloqueada porque o app tem o
/// modo de segundo plano "audio" e continua vivo pela localização.
@MainActor
final class Locutor: NSObject {
    static let compartilhado = Locutor()

    private let sintetizador = AVSpeechSynthesizer()
    private let voz = AVSpeechSynthesisVoice(language: "pt-BR")
    private var bipeCurto: AVAudioPlayer?
    private var bipeLongo: AVAudioPlayer?
    private var sessaoAtiva = false
    private var tarefaDesligar: Task<Void, Never>?

    override init() {
        super.init()
        sintetizador.delegate = self
        bipeCurto = try? AVAudioPlayer(data: Self.tom(frequencia: 880, duracao: 0.12))
        bipeLongo = try? AVAudioPlayer(data: Self.tom(frequencia: 1320, duracao: 0.35))
        bipeCurto?.prepareToPlay()
        bipeLongo?.prepareToPlay()
    }

    func falar(_ texto: String, interromper: Bool = false) {
        ativarSessao()
        if interromper, sintetizador.isSpeaking { sintetizador.stopSpeaking(at: .immediate) }
        let fala = AVSpeechUtterance(string: texto)
        fala.voice = voz
        fala.rate = AVSpeechUtteranceDefaultSpeechRate
        sintetizador.speak(fala)
    }

    func bipe(longo: Bool) {
        ativarSessao()
        let tocador = longo ? bipeLongo : bipeCurto
        tocador?.currentTime = 0
        tocador?.play()
        agendarDesligar(depois: longo ? 0.8 : 0.5)
    }

    func vibrar() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    func calar() {
        if sintetizador.isSpeaking { sintetizador.stopSpeaking(at: .immediate) }
        agendarDesligar(depois: 0.2)
    }

    // MARK: Sessão de áudio

    private func ativarSessao() {
        tarefaDesligar?.cancel()
        guard !sessaoAtiva else { return }
        let sessao = AVAudioSession.sharedInstance()
        do {
            try sessao.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try sessao.setActive(true)
            sessaoAtiva = true
        } catch {
            // Sem sessão (outra app com prioridade, chamada): a fala sai sem abaixar a música, ou não sai.
        }
    }

    private func agendarDesligar(depois segundos: Double) {
        tarefaDesligar?.cancel()
        tarefaDesligar = Task { [weak self] in
            try? await Task.sleep(for: .seconds(segundos))
            guard !Task.isCancelled else { return }
            self?.desligarSeQuieto()
        }
    }

    private func desligarSeQuieto() {
        guard sessaoAtiva, !sintetizador.isSpeaking, bipeCurto?.isPlaying != true, bipeLongo?.isPlaying != true else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        sessaoAtiva = false
    }

    fileprivate func terminouDeFalar() {
        agendarDesligar(depois: 0.6)
    }

    // MARK: Bipe gerado (sem arquivo de som)

    /// WAV de um tom senoidal curto, com rampa de 5 ms nas pontas para não estalar.
    static func tom(frequencia: Double, duracao: Double, taxa: Int = 44_100) -> Data {
        let total = Int(Double(taxa) * duracao)
        var pcm = Data(capacity: total * 2)
        for i in 0..<total {
            let t = Double(i) / Double(taxa)
            let envelope = min(1, min(t, duracao - t) / 0.005)
            let valor = Int16(sin(2 * Double.pi * frequencia * t) * 0.6 * envelope * Double(Int16.max))
            withUnsafeBytes(of: valor.littleEndian) { pcm.append(contentsOf: $0) }
        }
        var wav = Data()
        func texto(_ s: String) { wav.append(contentsOf: Array(s.utf8)) }
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { wav.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { wav.append(contentsOf: $0) } }
        texto("RIFF"); u32(UInt32(36 + pcm.count)); texto("WAVE")
        texto("fmt "); u32(16); u16(1); u16(1); u32(UInt32(taxa)); u32(UInt32(taxa * 2)); u16(2); u16(16)
        texto("data"); u32(UInt32(pcm.count))
        wav.append(pcm)
        return wav
    }
}

extension Locutor: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.terminouDeFalar() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.terminouDeFalar() }
    }
}
