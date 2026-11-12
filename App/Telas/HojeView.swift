import CrunningCore
import SwiftData
import SwiftUI

struct HojeView: View {
    @Query(sort: \Corrida.inicio, order: .reverse) var corridas: [Corrida]
    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @Environment(EstadoApp.self) var estadoApp
    @Binding var aba: Aba
    @Query var ativos: [PlanoAtivo]

    var body: some View {
        NavigationStack {
            Tela(
                selo: Self.dataDeHoje(),
                iconeSelo: "sun.max.fill",
                titulo: Self.saudacao(),
                subtitulo: nil,
                mostrarMarca: true
            ) {
                Group {
                    if let ativo = ativos.first {
                        CartoesPlanoHoje(ativo: ativo, aba: $aba)
                    } else {
                        cartaoTreinoDoDia
                    }
                }
                .entradaCascata(2)
                NavigationLink {
                    VolumeSemanalView()
                } label: {
                    cartaoSemana
                }
                .buttonStyle(.plain)
                .accessibilityHint("Abre o volume por semana")
                .entradaCascata(3)
                Button {
                    estadoApp.abrirCorridaLivre()
                } label: {
                    Label("Correr agora", systemImage: "figure.run")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Paleta.verdeLogo, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Abre a tela de corrida livre com GPS")
                .padding(.top, 8)
                .entradaCascata(4)
                HStack(spacing: 12) {
                    Button {
                        aba = .treinos
                    } label: {
                        Label("Treinos", systemImage: "square.stack.3d.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.glass)
                    Button {
                        estadoApp.abrirCorridaLivre(esteira: true)
                    } label: {
                        Label("Na esteira", systemImage: "figure.run.treadmill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.glass)
                    .accessibilityHint("Corrida sem GPS; a distância você digita no fim")
                }
                .entradaCascata(4)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var cartaoTreinoDoDia: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Treino de hoje", systemImage: "figure.run")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Nada planejado")
                .font(.title2.weight(.semibold))
            Text("Sem plano em uso. Monte um na aba Plano > Prévia e toque em \"Usar este plano\", ou escolha um treino em Treinos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }

    private var cartaoSemana: some View {
        let semana = corridasDaSemana
        let distancia = semana.reduce(0.0) { $0 + $1.distanciaMetros }
        let tempo = semana.reduce(0.0) { $0 + $1.duracaoEmMovimento }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Esta semana")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Label("Volume por semana", systemImage: "chart.bar")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            HStack(alignment: .firstTextBaseline) {
                numero(Formatador.numero(Formatador.distanciaNaUnidade(distancia, unidade: unidade), casas: 1), legenda: unidade.sigla)
                Spacer()
                numero("\(semana.count)", legenda: semana.count == 1 ? L("corrida", "run") : L("corridas", "runs"))
                Spacer()
                numero(Formatador.duracao(tempo), legenda: L("em movimento", "moving"))
            }
            faixaDias(semana)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoVidro()
    }

    // MARK: Semana dia a dia

    /// Segunda a domingo: barra verde com o que foi corrido e, atrás, a do treino do plano na cor
    /// do tipo; embaixo, os km feitos (ou os planejados, apagados). Hoje fica destacado.
    private func faixaDias(_ semana: [Corrida]) -> some View {
        let calendario = CalendarioTreino.padrao()
        let inicio = CalendarioTreino.inicioDaSemana(.now, calendario: calendario)
        let feitos = VolumeSemanal.porDia(corridas: semana.map { (inicio: $0.inicio, distancia: $0.distanciaMetros) }, hoje: .now, calendario: calendario)
        let agenda = ativos.first?.agenda
        let planejados: [SessaoPlanejada?] = (0..<7).map { d in
            guard let agenda, let data = calendario.date(byAdding: .day, value: d, to: inicio),
                  let p = agenda.posicao(de: data, calendario: calendario) else { return nil }
            return agenda.sessao(semana: p.semana, dia: p.dia)
        }
        let maiores: [Double] = (0..<7).map { d in max(feitos[d], planejados[d]?.distancia ?? 0) }
        let maximo: Double = max(1, maiores.max() ?? 1)
        let hoje = (calendario.dateComponents([.day], from: inicio, to: calendario.startOfDay(for: .now)).day ?? 0)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<7, id: \.self) { d in
                colunaDia(d, feito: feitos[d], plano: planejados[d], ehHoje: d == hoje, maximo: maximo)
            }
        }
    }

    /// Uma coluna da faixa (separada para o compilador checar os tipos em partes).
    private func colunaDia(_ d: Int, feito: Double, plano: SessaoPlanejada?, ehHoje: Bool, maximo: Double) -> some View {
        let alturaMaxima: CGFloat = 40
        let alturaFeito = CGFloat(max(6, 40 * feito / maximo))
        let alturaPlano = CGFloat(max(6, 40 * (plano?.distancia ?? 0) / maximo))
        let corPlano: Color = plano.map { $0.tipo.cor.opacity(feito > 0 ? 0.25 : 0.4) } ?? .clear
        let texto: String = feito > 0 ? kmCurto(feito) : (plano.map { kmCurto($0.distancia) } ?? "–")
        let estiloTexto: AnyShapeStyle = feito > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
        let estiloLetra: AnyShapeStyle = ehHoje ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary)
        let fundo: Color = ehHoje ? Color.accentColor.opacity(0.1) : .clear
        var rotulo = PlanoAtivoView.nomesDias[d] + ": "
        rotulo += feito > 0 ? Formatador.distancia(feito, unidade: unidade) + L(" feitos", " done") : L("nada corrido", "no run")
        if let plano { rotulo += L(", plano ", ", plan ") + Formatador.distancia(plano.distancia, unidade: unidade) }
        return VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.primary.opacity(0.06))
                    .frame(width: 14, height: alturaMaxima)
                if plano != nil {
                    Capsule().fill(corPlano)
                        .frame(width: 14, height: alturaPlano)
                }
                if feito > 0 {
                    Capsule().fill(VolumeSemanalView.verde)
                        .frame(width: 14, height: alturaFeito)
                }
            }
            Text(texto)
                .font(.caption2.weight(feito > 0 ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(estiloTexto)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(PlanoAtivoView.letrasDias[d])
                .font(.caption2.weight(ehHoje ? .bold : .semibold))
                .foregroundStyle(estiloLetra)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(fundo, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rotulo)
    }

    private func kmCurto(_ metros: Double) -> String {
        let v = Formatador.distanciaNaUnidade(metros, unidade: unidade)
        return Formatador.numero(v, casas: v < 10 && v != v.rounded() ? 1 : 0)
    }

    private func numero(_ valor: String, legenda: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(valor)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(legenda)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var corridasDaSemana: [Corrida] {
        let inicio = CalendarioTreino.inicioDaSemana(.now)
        return corridas.filter { $0.inicio >= inicio }
    }

    static func dataDeHoje() -> String {
        let texto = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return texto.prefix(1).uppercased() + texto.dropFirst()
    }

    static func saudacao() -> String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: L("Bom dia", "Good morning")
        case 12..<18: L("Boa tarde", "Good afternoon")
        default: L("Boa noite", "Good evening")
        }
    }
}
