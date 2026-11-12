import CrunningCore
import Foundation
import SwiftData

/// Uma conversa com o coach, guardada só no aparelho (nada disso é sincronizado). Falas e
/// histórico da IA ficam em JSON, porque são valores do CrunningCore.
@Model
final class ConversaCoach {
    var inicio: Date = Date.now
    var atualizada: Date = Date.now
    var titulo: String = ""
    var falas: Data? = nil
    var mensagens: Data? = nil

    init() {}

    var falasSalvas: [RegistroConversa.Fala] {
        RegistroConversa.decodificar([RegistroConversa.Fala].self, de: falas) ?? []
    }

    var mensagensSalvas: [RegistroConversa.Mensagem] {
        RegistroConversa.decodificar([RegistroConversa.Mensagem].self, de: mensagens) ?? []
    }

    func guardar(falas novas: [RegistroConversa.Fala], mensagens novasMensagens: [RegistroConversa.Mensagem]) {
        falas = RegistroConversa.codificar(novas)
        mensagens = RegistroConversa.codificar(novasMensagens)
        titulo = RegistroConversa.titulo(novas)
        atualizada = .now
    }
}
