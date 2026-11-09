import ActivityKit
import Foundation

/// Dados da Live Activity (tela de bloqueio e Dynamic Island), compartilhados entre o app e a
/// extensão. O app inicia, atualiza (no máximo a cada 10 s, ou na troca de bloco e na pausa)
/// e encerra a atividade; os cronômetros rodam sozinhos com `Text(timerInterval:)`.
struct TreinoAtividadeAtributos: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var nomeBloco: String
        /// "Repetição 3 de 6", "Alvo 4:05–4:15 /km"...
        var detalhe: String?
        /// Fim previsto do bloco por tempo (o cronômetro conta para trás sozinho).
        var fimDoBloco: Date?
        /// Bloco por distância: o que falta, já formatado ("250 m").
        var restanteTexto: String?
        /// Corrida livre: início do cronômetro de tempo em movimento.
        var inicioCronometro: Date?
        /// Tempo parado (pausa), para mostrar sem cronômetro rodando.
        var tempoParado: TimeInterval?
        var distanciaMetros: Double
        var ritmoSegundosPorKm: Double?
        var progresso: Double
        var pausada: Bool
        /// Cor do bloco (hex), a mesma do app.
        var corHex: UInt32
    }

    var tituloTreino: String
    var esteira: Bool
}
