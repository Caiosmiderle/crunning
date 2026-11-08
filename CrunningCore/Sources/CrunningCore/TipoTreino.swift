import Foundation

/// Tipo de treino ou de bloco, do mais leve ao mais intenso. A cor de cada um
/// é a mesma no app inteiro (linha do tempo, execução, calendário); a cor em si
/// fica no app, aqui só a identidade e a ordem.
/// Os detalhes fisiológicos (zonas, limites) chegam na fase 4, com fontes em docs/CIENCIA.md.
public enum TipoTreino: String, CaseIterable, Codable, Sendable, Identifiable {
    case caminhada
    case recuperacao
    case facil
    case longao
    case limiar
    case intervalado
    case repeticoes

    public var id: String { rawValue }

    public var nome: String {
        switch self {
        case .caminhada: "Caminhada"
        case .recuperacao: "Recuperação"
        case .facil: "Fácil"
        case .longao: "Longão"
        case .limiar: "Limiar"
        case .intervalado: "Intervalado"
        case .repeticoes: "Repetições"
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
        case .limiar: 3
        case .intervalado: 4
        case .repeticoes: 5
        }
    }

    /// Treino de qualidade (conta no limite de treinos fortes por semana).
    public var ehQualidade: Bool { ordemIntensidade >= 3 }
}
