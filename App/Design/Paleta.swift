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
    /// Cor fixa de cada tipo, do frio (leve) ao quente (intenso), igual no app inteiro
    /// (e na Live Activity, que recebe o hex).
    var hex: UInt32 {
        switch self {
        case .caminhada: 0xB7C4D1
        case .recuperacao: 0x8FA3B8
        case .facil: 0x4DA3FF
        case .longao: 0x7B7CFF
        case .ritmoProva: 0x2EC4B6
        case .limiar: 0xFFC53D
        case .intervalado: 0xFF7A3D
        case .repeticoes: 0xFF3D6E
        case .prova: 0x8BE105
        }
    }

    var cor: Color { Color(hex: hex) }
}
