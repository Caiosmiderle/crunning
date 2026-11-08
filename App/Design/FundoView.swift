import SwiftUI

/// Fundo abstrato em tela cheia, gerado no aparelho (sem imagem de fora),
/// com tons do verde da marca e uma camada por cima para garantir contraste.
struct FundoView: View {
    @Environment(\.colorScheme) var esquema

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: Self.pontos,
            colors: esquema == .dark ? Self.coresEscuras : Self.coresClaras
        )
        .overlay(esquema == .dark ? Color.black.opacity(0.30) : Color.white.opacity(0.35))
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    static let pontos: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.5], [0.62, 0.42], [1, 0.55],
        [0, 1], [0.45, 1], [1, 1],
    ]

    static let coresEscuras: [Color] = [
        Color(hex: 0x0B0F14), Color(hex: 0x15202B), Color(hex: 0x0D1117),
        Color(hex: 0x16241A), Color(hex: 0x24401D), Color(hex: 0x101826),
        Color(hex: 0x0A0D12), Color(hex: 0x15231B), Color(hex: 0x07090D),
    ]

    static let coresClaras: [Color] = [
        Color(hex: 0xF4F7F2), Color(hex: 0xE6EEF6), Color(hex: 0xF7F8F5),
        Color(hex: 0xE4F2D6), Color(hex: 0xD3EDB8), Color(hex: 0xE8EEF7),
        Color(hex: 0xF5F7F4), Color(hex: 0xE2EFDD), Color(hex: 0xF1F3F6),
    ]
}
