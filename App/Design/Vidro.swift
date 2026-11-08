import SwiftUI

/// Vidro líquido nativo do iOS 26. Vira painel opaco quando "Reduzir Transparência"
/// está ligado ou quando a legibilidade manda (tela de corrida, sol forte).
struct Vidro<Forma: Shape>: ViewModifier {
    let forma: Forma
    var opaco: Bool = false
    var tom: Color? = nil
    @Environment(\.accessibilityReduceTransparency) var reduzirTransparencia

    @ViewBuilder
    func body(content: Content) -> some View {
        if opaco || reduzirTransparencia {
            content
                .background(Color(uiColor: .secondarySystemBackground), in: forma)
                .overlay(forma.stroke(Color.primary.opacity(0.08), lineWidth: 1))
        } else {
            content.glassEffect(vidroNativo, in: forma)
        }
    }

    private var vidroNativo: Glass {
        if let tom { Glass.regular.tint(tom) } else { Glass.regular }
    }
}

extension View {
    func vidro<Forma: Shape>(em forma: Forma, opaco: Bool = false, tom: Color? = nil) -> some View {
        modifier(Vidro(forma: forma, opaco: opaco, tom: tom))
    }

    func cartaoVidro(raio: CGFloat = 28, opaco: Bool = false) -> some View {
        vidro(em: RoundedRectangle(cornerRadius: raio, style: .continuous), opaco: opaco)
    }
}
