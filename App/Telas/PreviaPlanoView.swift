import CrunningCore
import SwiftUI

/// Prévia do motor de treino: monta um plano com as regras da fase 4 e mostra as
/// travas conferidas. O plano de verdade, com calendário e Hoje, chega na fase 8.
struct PreviaPlanoView: View {
    enum OpcaoObjetivo: String, CaseIterable, Identifiable {
        case cincoK, dezK, meia, maratona, condicionamento, comecar
        var id: String { rawValue }

        var objetivo: Objetivo {
            switch self {
            case .cincoK: .cincoK
            case .dezK: .dezK
            case .meia: .meia
            case .maratona: .maratona
            case .condicionamento: .condicionamento
            case .comecar: .comecarACorrer
            }
        }

        var nome: String {
            switch self {
            case .cincoK: "5 km"
            case .dezK: "10 km"
            case .meia: "Meia maratona"
            case .maratona: "Maratona"
            case .condicionamento: "Condicionamento"
            case .comecar: "Começar a correr"
            }
        }
    }

    static let nomesDias = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]

    @AppStorage(Preferencias.unidade) var unidade: UnidadeDistancia = .quilometros
    @AppStorage(Preferencias.provaDistancia) var distanciaReferencia: Double = 5000
    @AppStorage(Preferencias.provaTempo) var tempoReferencia: Double = 0
    @State var opcao: OpcaoObjetivo = .dezK
    @State var semanas = 12
    @State var nivel: Nivel = .intermediario
    @State var dias: Set<Int> = [1, 3, 5, 6]
    @State var diaLongao = 6
    @State var volumeKm = 25
    @State var longaoKm = 8
    @State var plano: Plano?

    var body: some View {
        Form {
            Section("Objetivo") {
                Picker("Objetivo", selection: $opcao) {
                    ForEach(OpcaoObjetivo.allCases) { Text($0.nome).tag($0) }
                }
                Stepper("\(semanas) semanas", value: $semanas, in: 1...30)
                Picker("Nível", selection: $nivel) {
                    ForEach(Nivel.allCases) { Text($0.nome).tag($0) }
                }
            }

            Section {
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { dia in
                        let marcado = dias.contains(dia)
                        Button {
                            if marcado { dias.remove(dia) } else { dias.insert(dia) }
                            if !dias.contains(diaLongao), let ultimo = dias.max() { diaLongao = ultimo }
                        } label: {
                            Text(Self.nomesDias[dia])
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(marcado ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(marcado ? .isSelected : [])
                    }
                }
                Picker("Dia do longão", selection: $diaLongao) {
                    ForEach(dias.sorted(), id: \.self) { Text(Self.nomesDias[$0]).tag($0) }
                }
            } header: {
                Text("Dias disponíveis")
            }

            Section {
                Stepper("Volume atual: \(volumeKm) km por semana", value: $volumeKm, in: 0...160)
                Stepper("Maior corrida recente: \(longaoKm) km", value: $longaoKm, in: 0...45)
            } header: {
                Text("Hoje")
            } footer: {
                Text("A maior corrida das últimas 4 semanas limita as corridas do plano: nenhuma passa 10% dela, e ela cresce até 10% por semana. " + (tempoReferencia > 0 ? "Ritmos pela prova de referência de Meus ritmos." : "Sem prova em Meus ritmos: as distâncias são estimadas pelo nível."))
            }

            Section {
                switch GeradorPlano.viabilidade(entradaAtual) {
                case .viavel:
                    Button("Gerar prévia") { gerar() }
                        .font(.headline)
                        .disabled(dias.count < 2)
                case let .curto(minimas, motivo):
                    Label(motivo, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.foraLeve)
                    Button("Usar \(minimas) semanas") { semanas = minimas }
                        .font(.headline)
                case let .naoRecomendado(motivo):
                    Label(motivo, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.foraForte)
                }
            }

            if let plano {
                let erros = ValidadorPlano.validar(plano)
                let alertas = GeradorPlano.alertas(plano)
                if !alertas.isEmpty {
                    Section("Atenção") {
                        ForEach(alertas, id: \.self) {
                            Label($0, systemImage: "exclamationmark.circle").font(.subheadline)
                        }
                    }
                }
                Section("Por que este plano?") {
                    ForEach(plano.regras, id: \.self) { Text($0).font(.subheadline) }
                }
                Section("Travas") {
                    if erros.isEmpty {
                        Label("Todas as travas conferidas", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Paleta.verdeLogo)
                    } else {
                        ForEach(erros.map(\.description), id: \.self) { Text($0).foregroundStyle(Paleta.foraForte) }
                    }
                }
                Section("Semanas") {
                    ForEach(plano.semanas, id: \.numero) { semana in
                        DisclosureGroup {
                            ForEach(0..<7, id: \.self) { dia in
                                linhaDia(dia, semana.dias[dia])
                            }
                        } label: {
                            HStack {
                                Text("Semana \(semana.numero)").font(.body.weight(.medium))
                                Text(semana.fase.nome + (semana.alivio ? " · alívio" : ""))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(Formatador.distancia(semana.volumeTreino, unidade: unidade, casas: 0) + (semana.temProva ? " + prova" : ""))
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Prévia do motor")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var entradaAtual: EntradaPlano {
        let vdot = tempoReferencia > 0 ? Daniels.vdot(distanciaMetros: distanciaReferencia, tempoSegundos: tempoReferencia) : nil
        return EntradaPlano(
            objetivo: opcao.objetivo, semanas: semanas, nivel: nivel, diasDisponiveis: dias, diaLongao: diaLongao,
            volumeAtual: Double(volumeKm) * 1000, longaoAtual: Double(longaoKm) * 1000, vdot: vdot
        )
    }

    private func gerar() {
        withAnimation { plano = GeradorPlano.gerar(entradaAtual) }
    }

    @ViewBuilder
    private func linhaDia(_ dia: Int, _ sessao: SessaoPlanejada?) -> some View {
        HStack(spacing: 10) {
            Text(Self.nomesDias[dia])
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            if let sessao {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(sessao.tipo.cor)
                    .frame(width: 6, height: 22)
                Text(sessao.treino.nome)
                    .font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Formatador.distancia(sessao.distancia, unidade: unidade, casas: 1))
                        .font(.subheadline.monospacedDigit())
                    Text(Formatador.duracao(sessao.duracao))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Descanso")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
