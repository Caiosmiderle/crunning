import ActivityKit
import Foundation

/// Dados da Live Activity (tela de bloqueio e Dynamic Island), compartilhados
/// entre o app e a extensão. O app passa a iniciar a atividade na fase 6.
struct TreinoAtividadeAtributos: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var nomeBloco: String
        /// Fim previsto do bloco atual, para o cronômetro rodar sozinho (Text(timerInterval:)).
        var fimDoBloco: Date?
        var distanciaMetros: Double
        var ritmoSegundosPorKm: Double?
    }

    var tituloTreino: String
}
