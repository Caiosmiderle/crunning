import Foundation

/// Conversa com o coach guardada no aparelho: o que aparece na tela (falas) e o que vai para a
/// IA (mensagens). Nada disso sai do iPhone a não ser as mensagens enviadas na hora de responder.
public enum RegistroConversa {
    /// Uma fala na tela.
    public struct Fala: Codable, Sendable, Equatable {
        public var doCoach: Bool
        public var texto: String
        public var instante: Date

        public init(doCoach: Bool, texto: String, instante: Date = .now) {
            self.doCoach = doCoach
            self.texto = texto
            self.instante = instante
        }
    }

    /// Uma mensagem do histórico enviado à IA ("user" ou "assistant").
    public struct Mensagem: Codable, Sendable, Equatable {
        public var papel: String
        public var texto: String

        public init(papel: String, texto: String) {
            self.papel = papel
            self.texto = texto
        }
    }

    /// Quantas mensagens do histórico vão para a IA ao continuar uma conversa. A tela mostra tudo;
    /// mandar só o fim limita o custo de cada resposta numa conversa longa.
    public static let maximoParaIA = 20

    /// As últimas `maximo` mensagens, começando sempre por uma do usuário (a API pede que a
    /// conversa comece por ele).
    public static func recorte(_ mensagens: [Mensagem], maximo: Int = maximoParaIA) -> [Mensagem] {
        var fim = Array(mensagens.suffix(max(1, maximo)))
        while let primeira = fim.first, primeira.papel != "user" { fim.removeFirst() }
        return fim
    }

    /// Título da conversa: a primeira fala do usuário, numa linha e curta.
    public static func titulo(_ falas: [Fala], limite: Int = 60) -> String {
        guard let primeira = falas.first(where: { !$0.doCoach }) else { return "" }
        let linha = primeira.texto.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard linha.count > limite else { return linha }
        return String(linha.prefix(limite - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    public static func codificar<T: Encodable>(_ valor: T) -> Data? { try? JSONEncoder().encode(valor) }

    public static func decodificar<T: Decodable>(_ tipo: T.Type, de dados: Data?) -> T? {
        guard let dados else { return nil }
        return try? JSONDecoder().decode(tipo, from: dados)
    }
}
