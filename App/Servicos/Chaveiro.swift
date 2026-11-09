import Foundation
import Security

/// Guarda a chave da API da Anthropic no Keychain do iPhone (só neste aparelho, só com ele
/// desbloqueado). A chave nunca vai para o repositório, o .ipa, o CI ou logs.
enum Chaveiro {
    private static let servico = "io.github.caiosmiderle.crunning.anthropic"
    private static let conta = "chave-api"

    private static var consultaBase: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: conta,
        ]
    }

    @discardableResult
    static func salvar(_ chave: String) -> Bool {
        apagar()
        var item = consultaBase
        item[kSecValueData as String] = Data(chave.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func ler() -> String? {
        var consulta = consultaBase
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let dados = resultado as? Data,
              let chave = String(data: dados, encoding: .utf8),
              !chave.isEmpty else { return nil }
        return chave
    }

    @discardableResult
    static func apagar() -> Bool {
        let status = SecItemDelete(consultaBase as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static var temChave: Bool { ler() != nil }
}
