import Foundation

/// Tipo de treino ou de bloco, do mais leve ao mais intenso. A cor de cada um
/// é a mesma no app inteiro (linha do tempo, execução, calendário); a cor em si
/// fica no app, aqui só a identidade e a ordem.
/// Zonas e limites de cada um: `Zonas`, `RegrasPlano` e docs/CIENCIA.md.
public enum TipoTreino: String, CaseIterable, Codable, Sendable, Identifiable {
    case caminhada
    case recuperacao
    case facil
    case longao
    case ritmoProva
    case limiar
    case intervalado
    case repeticoes
    case prova

    public var id: String { rawValue }

    public var nome: String {
        switch self {
        case .caminhada: L("Caminhada", "Walk")
        case .recuperacao: L("Recuperação", "Recovery")
        case .facil: L("Fácil", "Easy")
        case .longao: L("Longão", "Long run")
        case .ritmoProva: L("Ritmo de prova", "Race pace")
        case .limiar: L("Limiar", "Threshold")
        case .intervalado: L("Intervalado", "Intervals")
        case .repeticoes: L("Repetições", "Repetitions")
        case .prova: L("Prova", "Race")
        }
    }

    /// Ordem de intensidade (0 = mais leve). O longão é fácil na intensidade,
    /// mas tem cor própria porque é o treino-chave da semana.
    public var ordemIntensidade: Int {
        switch self {
        case .caminhada: 0
        case .recuperacao: 1
        case .facil: 2
        case .longao: 2
        case .ritmoProva: 3
        case .limiar: 3
        case .intervalado: 4
        case .repeticoes: 5
        case .prova: 6
        }
    }

    /// Treino de qualidade (conta no limite de treinos fortes por semana).
    public var ehQualidade: Bool { ordemIntensidade >= 3 }
}
