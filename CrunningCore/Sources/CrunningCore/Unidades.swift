import Foundation

/// Unidade de distância mostrada na tela. Por dentro, tudo é metro e segundo.
public enum UnidadeDistancia: String, CaseIterable, Codable, Sendable, Identifiable {
    case quilometros
    case milhas

    public var id: String { rawValue }

    /// Quantos metros tem uma unidade.
    public var metros: Double {
        switch self {
        case .quilometros: 1000
        case .milhas: 1609.344
        }
    }

    public var sigla: String {
        switch self {
        case .quilometros: "km"
        case .milhas: "mi"
        }
    }

    public var nome: String {
        switch self {
        case .quilometros: L("Quilômetros", "Kilometers")
        case .milhas: L("Milhas", "Miles")
        }
    }

    /// Sufixo do ritmo: "/km" ou "/mi".
    public var siglaRitmo: String { "/" + sigla }
}

/// Formatação em português do Brasil, sem depender do idioma do aparelho
/// (vírgula decimal sempre), para os números ficarem iguais em teste e na tela.
public enum Formatador {
    /// "5,23 km". Valores negativos ou inválidos viram zero.
    public static func distancia(_ metros: Double, unidade: UnidadeDistancia = .quilometros, casas: Int = 2) -> String {
        numero(distanciaNaUnidade(metros, unidade: unidade), casas: casas) + " " + unidade.sigla
    }

    /// Só o número da distância, sem a sigla: "5,23".
    public static func distanciaNaUnidade(_ metros: Double, unidade: UnidadeDistancia) -> Double {
        guard metros.isFinite, metros > 0 else { return 0 }
        return metros / unidade.metros
    }

    /// Ritmo "m:ss" a partir de segundos por quilômetro, convertido para a unidade.
    /// Ritmo impossível (zero, negativo, infinito ou acima de 59:59) vira "--:--".
    public static func ritmo(segundosPorKm: Double, unidade: UnidadeDistancia = .quilometros) -> String {
        guard segundosPorKm.isFinite, segundosPorKm > 0 else { return "--:--" }
        let total = Int((segundosPorKm * unidade.metros / 1000).rounded())
        guard total > 0, total < 3600 else { return "--:--" }
        return "\(total / 60):" + doisDigitos(total % 60)
    }

    /// Duração "m:ss" abaixo de uma hora e "h:mm:ss" a partir dela.
    public static func duracao(_ segundos: TimeInterval) -> String {
        guard segundos.isFinite, segundos > 0 else { return "0:00" }
        let total = Int(segundos.rounded(.down))
        let horas = total / 3600
        let minutos = (total % 3600) / 60
        let segs = total % 60
        if horas > 0 {
            return "\(horas):" + doisDigitos(minutos) + ":" + doisDigitos(segs)
        }
        return "\(minutos):" + doisDigitos(segs)
    }

    /// Separador decimal: vírgula por padrão; o app troca pelo do idioma do iPhone na abertura.
    nonisolated(unsafe) public static var separadorDecimal = ","

    /// Número com o separador decimal e quantidade fixa de casas: 5.234 -> "5,23" (ou "5.23").
    public static func numero(_ valor: Double, casas: Int) -> String {
        let casas = max(0, min(casas, 6))
        guard valor.isFinite else { return "0" }
        return String(format: "%.\(casas)f", valor).replacingOccurrences(of: ".", with: separadorDecimal)
    }

    private static func doisDigitos(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }
}
