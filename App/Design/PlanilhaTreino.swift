import CrunningCore
import SwiftUI

/// O treino escrito como uma planilha de treinador: aquecimento, parte principal e desaquecimento;
/// minutos com aspas (10', 1'30"); tiros como "6 × 400 m forte" com a recuperação sempre em tempo
/// ou distância ("com 1'30" de trote"), na notação de intervalos usada por treinadores (repetições ×
/// distância, pace, recuperação). Embaixo de cada linha, o pace (Daniels) e, onde o batimento firma,
/// a zona.
enum Planilha {
    struct Linha: Identifiable {
        let id: Int
        let titulo: String
        let detalhes: [String]
        let tipo: TipoTreino
        var recuo = false
    }

    struct Secao: Identifiable {
        let id: String
        let nome: String
        var linhas: [Linha]
    }

    /// 10', 1'30", 45", 1h20'.
    static func medida(_ m: Medida, unidade: UnidadeDistancia) -> String {
        switch m {
        case let .tempo(t):
            let total = Int(t.rounded())
            let h = total / 3600, min = (total % 3600) / 60, s = total % 60
            if h > 0 { return min == 0 ? "\(h)h" : "\(h)h\(String(format: "%02d", min))'" }
            if s == 0 { return "\(min)'" }
            if min == 0 { return "\(s)\"" }
            return "\(min)'\(String(format: "%02d", s))\""
        case .distancia:
            return TextoTreino.medida(m, unidade: unidade)
        }
    }

    static func descricao(_ p: Passo) -> String {
        switch p.intensidade {
        case .caminhada: "de caminhada"
        case .facil: p.funcao == .trabalho ? "leve" : "de trote"
        case .maratona: "no pace de maratona"
        case .limiar: "no limiar"
        case .intervalado: "forte"
        case .repeticoes: "rápido"
        case .prova: "no pace de prova"
        }
    }

    private static func detalhes(_ p: Passo, zonas: Zonas?, unidade: UnidadeDistancia) -> [String] {
        var lista = [TextoTreino.alvo(p, zonas: zonas, unidade: unidade)]
        if let c = TextoTreino.complemento(p, zonas: zonas, unidade: unidade) { lista.append(c) }
        return lista
    }

    static func secoes(_ treino: Treino, zonas: Zonas?, unidade: UnidadeDistancia) -> [Secao] {
        var aquecimento = Secao(id: "aquecimento", nome: "Aquecimento", linhas: [])
        var principal = Secao(id: "principal", nome: "Parte principal", linhas: [])
        var desaquecimento = Secao(id: "desaquecimento", nome: "Desaquecimento", linhas: [])
        var n = 0
        func proximo() -> Int { n += 1; return n }

        for bloco in treino.blocos {
            switch bloco {
            case let .passo(p):
                let linha = Linha(id: proximo(), titulo: medida(p.medida, unidade: unidade) + " " + descricao(p),
                                  detalhes: detalhes(p, zonas: zonas, unidade: unidade), tipo: p.tipoParaCor)
                switch p.funcao {
                case .aquecimento: aquecimento.linhas.append(linha)
                case .desaquecimento: desaquecimento.linhas.append(linha)
                case .trabalho, .recuperacao: principal.linhas.append(linha)
                }
            case let .repetir(vezes, passos):
                if passos.count == 2, passos[1].funcao == .recuperacao, passos[0].funcao != .recuperacao {
                    // O caso clássico: "6 × 400 m forte, com 1'30" de trote".
                    let w = passos[0], r = passos[1]
                    var d = detalhes(w, zonas: zonas, unidade: unidade)
                    d.append("com " + medida(r.medida, unidade: unidade) + " " + descricao(r) + " entre eles")
                    principal.linhas.append(Linha(
                        id: proximo(), titulo: "\(vezes) × " + medida(w.medida, unidade: unidade) + " " + descricao(w),
                        detalhes: d, tipo: w.tipoParaCor
                    ))
                } else {
                    let forte = passos.first { $0.funcao == .trabalho } ?? passos.first
                    principal.linhas.append(Linha(id: proximo(), titulo: "\(vezes) vezes:", detalhes: [],
                                                  tipo: forte?.tipoParaCor ?? .facil))
                    for p in passos {
                        principal.linhas.append(Linha(
                            id: proximo(), titulo: medida(p.medida, unidade: unidade) + " " + descricao(p),
                            detalhes: detalhes(p, zonas: zonas, unidade: unidade), tipo: p.tipoParaCor, recuo: true
                        ))
                    }
                }
            }
        }
        // Treino de um bloco só (rodagem, longão): sem as três partes, só "Treino".
        if aquecimento.linhas.isEmpty, desaquecimento.linhas.isEmpty {
            principal = Secao(id: "principal", nome: "Treino", linhas: principal.linhas)
        }
        return [aquecimento, principal, desaquecimento].filter { !$0.linhas.isEmpty }
    }

    /// A planilha em texto (notas do Calendário).
    static func texto(_ treino: Treino, zonas: Zonas?, unidade: UnidadeDistancia) -> String {
        secoes(treino, zonas: zonas, unidade: unidade).map { secao in
            let linhas = secao.linhas.map { l -> String in
                let recuo = l.recuo ? "   " : ""
                let detalhe = l.detalhes.isEmpty ? "" : " (" + l.detalhes.joined(separator: "; ") + ")"
                return recuo + "• " + l.titulo + detalhe
            }
            return secao.nome.uppercased() + "\n" + linhas.joined(separator: "\n")
        }.joined(separator: "\n\n")
        + "\n\nTotal " + TextoTreino.totais(treino, zonas: zonas, unidade: unidade)
    }
}

/// A planilha na tela (detalhe do treino e antes de começar).
struct PlanilhaTreino: View {
    let treino: Treino
    var zonas: Zonas?
    var unidade: UnidadeDistancia = .quilometros

    var body: some View {
        let secoes = Planilha.secoes(treino, zonas: zonas, unidade: unidade)
        VStack(alignment: .leading, spacing: 16) {
            ForEach(secoes) { secao in
                VStack(alignment: .leading, spacing: 10) {
                    Text(secao.nome.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    ForEach(secao.linhas) { linha in
                        HStack(alignment: .top, spacing: 10) {
                            Capsule(style: .continuous)
                                .fill(linha.tipo.cor)
                                .frame(width: 4)
                                .frame(maxHeight: .infinity)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(linha.titulo)
                                    .font(.body.weight(.semibold))
                                ForEach(Array(linha.detalhes.enumerated()), id: \.offset) { _, detalhe in
                                    Text(detalhe)
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, linha.recuo ? 14 : 0)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Divider()
            Text("Total " + TextoTreino.totais(treino, zonas: zonas, unidade: unidade))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}
