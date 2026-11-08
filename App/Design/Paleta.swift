import CrunningCore
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Paleta {
    /// Verde do logo, medido do arquivo original (#8BE105). No tema claro o
    /// destaque global (AccentColor) usa um verde mais escuro para dar contraste.
    static let verdeLogo = Color(hex: 0x8BE105)

    // Medidor de ritmo: dentro da faixa usa o verde da marca.
    static let dentroDaFaixa = verdeLogo
    static let foraLeve = Color(hex: 0xFFC53D)
    static let foraForte = Color(hex: 0xFF4D4F)
}

extension TipoTreino {
    /// Cor fixa de cada tipo, do frio (leve) ao quente (intenso), igual no app inteiro.
    var cor: Color {
        switch self {
        case .caminhada: Color(hex: 0xB7C4D1)
        case .recuperacao: Color(hex: 0x8FA3B8)
        case .facil: Color(hex: 0x4DA3FF)
        case .longao: Color(hex: 0x7B7CFF)
        case .limiar: Color(hex: 0xFFC53D)
        case .intervalado: Color(hex: 0xFF7A3D)
        case .repeticoes: Color(hex: 0xFF3D6E)
        }
    }
}
