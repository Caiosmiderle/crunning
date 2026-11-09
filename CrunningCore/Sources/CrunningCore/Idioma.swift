import Foundation

/// Idioma dos textos do motor (nomes, mensagens, voz). O app escolhe na abertura, pelo idioma
/// do iPhone: português ou inglês. O padrão (e o dos testes) é português.
public enum Idioma: Sendable, Equatable {
    case portugues
    case ingles

    /// Escrito uma vez, na abertura do app, antes de qualquer tela.
    nonisolated(unsafe) public static var atual: Idioma = .portugues

    /// Português se o primeiro idioma suportado do app for português; senão, inglês.
    public static func doSistema(_ preferidos: [String]) -> Idioma {
        (preferidos.first ?? "pt").lowercased().hasPrefix("pt") ? .portugues : .ingles
    }

    /// Código para a voz e para o Coach de IA.
    public var codigoVoz: String { self == .ingles ? "en-US" : "pt-BR" }
}

/// Texto em português ou inglês, conforme `Idioma.atual`.
@inline(__always)
public func L(_ pt: String, _ en: String) -> String {
    Idioma.atual == .ingles ? en : pt
}
