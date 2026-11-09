import SwiftUI

// MARK: - Marca

/// O logo do CRUNNING: símbolo verde + palavra, que acompanha o tema (branca no escuro).
struct MarcaCrunning: View {
    var altura: CGFloat = 22

    var body: some View {
        HStack(spacing: altura * 0.35) {
            Image("Simbolo")
                .resizable()
                .scaledToFit()
                .frame(height: altura * 1.25)
            Image("Marca")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: altura * 0.62)
                .foregroundStyle(Color.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("CRUNNING")
    }
}

// MARK: - Selo

/// Pílula de contexto no topo da tela (ex.: "Semana 6 · Construção").
struct Selo: View {
    let texto: String
    var icone: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icone {
                Image(systemName: icone)
                    .font(.caption2.weight(.semibold))
            }
            Text(texto)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(Color.primary.opacity(0.9))
        .padding(.vertical, 9)
        .padding(.horizontal, 13)
        .vidro(em: .capsule)
    }
}

// MARK: - Entrada em cascata

/// Aparece subindo 16 pt e ganhando opacidade, em sequência pela `ordem`.
/// Com "Reduzir Movimento", só um fade curto.
struct EntradaCascata: ViewModifier {
    let ordem: Int
    @Environment(\.accessibilityReduceMotion) var reduzirMovimento
    @State var visivel = false

    func body(content: Content) -> some View {
        content
            .opacity(visivel ? 1 : 0)
            .offset(y: (visivel || reduzirMovimento) ? 0 : 16)
            .onAppear {
                guard !visivel else { return }
                if reduzirMovimento {
                    withAnimation(.easeOut(duration: 0.2)) { visivel = true }
                } else {
                    let atraso = 0.1 + 0.08 * Double(ordem)
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.5).delay(atraso)) {
                        visivel = true
                    }
                }
            }
    }
}

extension View {
    func entradaCascata(_ ordem: Int) -> some View {
        modifier(EntradaCascata(ordem: ordem))
    }
}

// MARK: - Tela base

/// Estrutura comum das abas: fundo, selo, título grande e leve, conteúdo rolável.
struct Tela<Conteudo: View>: View {
    let selo: String
    var iconeSelo: String? = nil
    let titulo: String
    var subtitulo: String? = nil
    var mostrarMarca: Bool = false
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if mostrarMarca {
                    MarcaCrunning()
                        .padding(.bottom, 4)
                        .entradaCascata(0)
                }
                Selo(texto: selo, icone: iconeSelo)
                    .entradaCascata(0)
                VStack(alignment: .leading, spacing: 6) {
                    if let subtitulo {
                        Text(subtitulo)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(titulo)
                        .font(.system(.largeTitle, design: .default, weight: .light))
                        .tracking(-0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
                .entradaCascata(1)
                conteudo
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background { FundoView() }
        .overlay(alignment: .top) {
            // Vidro atrás da barra de status: o que rola não passa por cima do relógio.
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(LinearGradient(colors: [.black, .black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(height: 0)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Deslizar para confirmar

/// Controle de arrastar para iniciar ou finalizar (evita toque sem querer).
/// Confirma se passar de 85% do trilho; se soltar antes, volta.
struct DeslizarParaConfirmar: View {
    let rotulo: String
    var icone: String = "arrow.right"
    var aoConfirmar: () -> Void

    @State var deslocamento: CGFloat = 0
    @State var confirmacoes = 0

    let altura: CGFloat = 60
    let polegar: CGFloat = 48
    let margem: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let percurso = max(geo.size.width - polegar - margem * 2, 1)
            let progresso = deslocamento / percurso
            ZStack(alignment: .leading) {
                Text(rotulo)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - min(progresso * 1.6, 1))
                HStack(spacing: 1) {
                    Spacer()
                    ForEach(0..<3, id: \.self) { indice in
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.primary.opacity(0.35 + Double(indice) * 0.15))
                    }
                }
                .padding(.trailing, 20)
                .opacity(1 - min(progresso * 2, 1))
                Circle()
                    .fill(Color.white)
                    .frame(width: polegar, height: polegar)
                    .overlay {
                        Image(systemName: icone)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.85))
                    }
                    .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
                    .offset(x: margem + deslocamento)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { valor in
                                deslocamento = min(max(0, valor.translation.width), percurso)
                            }
                            .onEnded { _ in
                                if deslocamento / percurso >= 0.85 {
                                    withAnimation(.snappy(duration: 0.2)) { deslocamento = percurso }
                                    confirmar()
                                    Task {
                                        try? await Task.sleep(for: .milliseconds(700))
                                        withAnimation(.spring(duration: 0.4)) { deslocamento = 0 }
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        deslocamento = 0
                                    }
                                }
                            }
                    )
            }
            .frame(width: geo.size.width, height: altura)
        }
        .frame(height: altura)
        .vidro(em: .capsule)
        .sensoryFeedback(.success, trigger: confirmacoes)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rotulo)
        .accessibilityHint("Deslize para a direita, ou toque duas vezes, para confirmar.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirmar() }
    }

    private func confirmar() {
        confirmacoes += 1
        aoConfirmar()
    }
}
