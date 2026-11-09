import Foundation

/// Erro do texto rápido, com uma mensagem que já explica o que corrigir.
public struct ErroTextoRapido: Error, Equatable, Sendable, CustomStringConvertible {
    public let mensagem: String

    public init(_ mensagem: String) {
        self.mensagem = mensagem
    }

    public var description: String { mensagem }
}

/// Texto rápido do construtor de treino: "10min fácil + 6x(400m forte / 90s trote) + 10min fácil".
///
/// - Trechos separados por `+`, vírgula, ponto e vírgula ou quebra de linha.
/// - Repetição: `6x(...)`, `6 x 400m forte / 90s trote` (sem parênteses, a barra separa os passos).
/// - Quanto: `10min`, `10 min`, `10'`, `90s`, `1h`, `1h30`, `2min30s`, `2:30`, `400m`, `1km`, `1,5 km`, `5k`.
/// - Intensidade: fácil, leve, trote, caminhada, maratona, limiar, tempo, forte, tiro, rápido, prova...
///   Também em inglês: easy, jog, walk, marathon, threshold, tempo, hard, interval, fast, reps, race...
/// - Sem intensidade: fácil (num tiro de repetição, intervalado).
/// - A função (aquecimento, trabalho, recuperação, desaquecimento) sai da posição, ou de palavras como
///   "aquecimento", "desaquecimento", "rec" e "descanso" (ou "warm-up", "cool-down", "recovery" e "rest").
public enum TextoRapido {
    // MARK: Interpretar

    public static func interpretar(_ texto: String) throws -> [Bloco] {
        let limpo = normalizar(texto)
        guard !limpo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ErroTextoRapido(L("Escreva o treino, por exemplo: 10min fácil + 6x(400m forte / 90s trote) + 10min fácil.",
                                    "Write the workout, for example: 10min easy + 6x(400m hard / 90s jog) + 10min easy."))
        }
        var brutos: [BlocoBruto] = []
        for item in try dividir(limpo, em: ["+", ",", ";", "\n"]) {
            brutos.append(contentsOf: try interpretarItem(item))
        }
        guard !brutos.isEmpty else { throw ErroTextoRapido(L("Não achei nenhum trecho no texto.", "I couldn't find any segment in the text.")) }
        return inferirFuncoes(brutos)
    }

    /// Versão que não lança erro, para a pré-visualização ao vivo.
    public static func resultado(_ texto: String) -> Result<[Bloco], ErroTextoRapido> {
        do {
            return .success(try interpretar(texto))
        } catch let erro as ErroTextoRapido {
            return .failure(erro)
        } catch {
            return .failure(ErroTextoRapido(L("Não entendi o texto.", "I didn't understand the text.")))
        }
    }

    // MARK: Escrever

    /// O texto de um treino, no formato que `interpretar` aceita.
    public static func texto(_ blocos: [Bloco]) -> String {
        blocos.map { bloco -> String in
            switch bloco {
            case let .passo(p): textoPasso(p)
            case let .repetir(vezes, passos): "\(vezes)x(" + passos.map(textoPasso).joined(separator: " / ") + ")"
            }
        }
        .joined(separator: " + ")
    }

    public static func textoPasso(_ p: Passo) -> String {
        textoMedida(p.medida) + " " + palavra(p)
    }

    public static func textoMedida(_ medida: Medida) -> String {
        switch medida {
        case let .tempo(t):
            let total = Int(t.rounded())
            let h = total / 3600, m = (total % 3600) / 60, s = total % 60
            var partes: [String] = []
            if h > 0 { partes.append("\(h)h") }
            if m > 0 { partes.append("\(m)min") }
            if s > 0 || partes.isEmpty { partes.append("\(s)s") }
            return partes.joined()
        case let .distancia(d):
            if d < 1000 { return "\(Int(d.rounded()))m" }
            let km = d / 1000
            if km == km.rounded() { return "\(Int(km))km" }
            var texto = Formatador.numero(km, casas: 4)
            while texto.hasSuffix("0") { texto.removeLast() }
            // O separador decimal é "," em português e pode ser "." em inglês.
            if texto.hasSuffix(",") || texto.hasSuffix(".") { texto.removeLast() }
            return texto + "km"
        }
    }

    /// Palavras escritas no idioma do app; todas são aceitas de volta por `interpretar`.
    static func palavra(_ p: Passo) -> String {
        switch (p.funcao, p.intensidade) {
        case (.aquecimento, .facil): L("aquecimento", "warmup")
        case (.desaquecimento, .facil): L("desaquecimento", "cooldown")
        case (.recuperacao, .facil): L("trote", "jog")
        default: nomeCurto(p.intensidade)
        }
    }

    public static func nomeCurto(_ i: Intensidade) -> String {
        switch i {
        case .caminhada: L("caminhada", "walk")
        case .facil: L("fácil", "easy")
        case .maratona: L("maratona", "marathon")
        case .limiar: L("limiar", "threshold")
        case .intervalado: L("forte", "hard")
        case .repeticoes: L("rápido", "fast")
        case .prova: L("prova", "race")
        }
    }

    // MARK: Internos

    struct PassoBruto: Equatable {
        var medida: Medida
        var intensidade: Intensidade?
        var funcao: FuncaoPasso?
    }

    enum BlocoBruto: Equatable {
        case passo(PassoBruto)
        case repetir(Int, [PassoBruto])
    }

    static let maximoRepeticoes = 50
    static let tempoMaximo: TimeInterval = 6 * 3600
    static let distanciaMaxima = 100_000.0

    static func normalizar(_ texto: String) -> String {
        var s = texto.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR")).lowercased()
        let trocas: [(String, String)] = [
            ("×", "x"), ("’", "'"), ("′", "'"), ("‘", "'"), ("″", "\""), ("“", "\""), ("”", "\""), ("\r", "\n"),
            // Inglês: "warm-up" e "cool-down" viram uma palavra só (o hífen e o espaço separariam).
            ("warm-up", "warmup"), ("warm up", "warmup"), ("cool-down", "cooldown"), ("cool down", "cooldown"),
        ]
        for (de, para) in trocas { s = s.replacingOccurrences(of: de, with: para) }
        return s
    }

    /// Divide pelos separadores fora de parênteses. Pedaços vazios somem.
    static func dividir(_ texto: String, em separadores: Set<Character>) throws -> [String] {
        var partes: [String] = []
        var atual = ""
        var profundidade = 0
        let letras = Array(texto)
        for (i, c) in letras.enumerated() {
            // Vírgula entre dois algarismos é decimal ("1,5km"), não separador.
            if c == ",", i > 0, i + 1 < letras.count, letras[i - 1].isNumber, letras[i + 1].isNumber {
                atual.append(c)
                continue
            }
            if c == "(" { profundidade += 1 }
            if c == ")" {
                profundidade -= 1
                if profundidade < 0 { throw ErroTextoRapido(L("Tem um \")\" sem o \"(\" correspondente.", "There is a \")\" without a matching \"(\".")) }
            }
            if profundidade == 0, separadores.contains(c) {
                partes.append(atual)
                atual = ""
            } else {
                atual.append(c)
            }
        }
        if profundidade != 0 { throw ErroTextoRapido(L("Faltou fechar um parêntese.", "A parenthesis was not closed.")) }
        partes.append(atual)
        return partes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Se o item começa com "6x", devolve as vezes e o resto.
    static func prefixoRepeticao(_ item: String) -> (vezes: Int, resto: String)? {
        let c = Array(item)
        var i = 0
        while i < c.count, c[i].isASCII, c[i].isNumber { i += 1 }
        guard i > 0, let vezes = Int(String(c[0..<i])) else { return nil }
        var j = i
        while j < c.count, c[j] == " " { j += 1 }
        guard j < c.count else { return nil }
        if c[j] == "x" || c[j] == "*" {
            // "6x" seguido de letra que não é número nem "(" ainda pode ser "6 xícaras"... aceita só se não vier outra letra colada.
            let depois = j + 1 < c.count ? c[j + 1] : " "
            if depois.isLetter { return nil }
            return (vezes, String(c[(j + 1)...]).trimmingCharacters(in: .whitespaces))
        }
        let resto = String(c[j...])
        // "6 vezes (...)" ou, em inglês, "6 times (...)".
        for palavra in ["vezes", "times"] where resto.hasPrefix(palavra) {
            return (vezes, String(resto.dropFirst(palavra.count)).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    static func interpretarItem(_ item: String) throws -> [BlocoBruto] {
        if let repeticao = prefixoRepeticao(item) {
            let vezes = repeticao.vezes
            let resto = repeticao.resto
            guard (1...maximoRepeticoes).contains(vezes) else {
                throw ErroTextoRapido(L("Use de 1 a \(maximoRepeticoes) repetições (\"\(item)\").",
                                        "Use 1 to \(maximoRepeticoes) repetitions (\"\(item)\")."))
            }
            guard !resto.isEmpty else {
                throw ErroTextoRapido(L("Faltou o que repetir depois de \"\(vezes)x\".", "Missing what to repeat after \"\(vezes)x\"."))
            }
            let partes: [String]
            if resto.hasPrefix("(") {
                guard resto.hasSuffix(")"), fechaNoFim(resto) else {
                    throw ErroTextoRapido(L("Depois do parêntese da repetição use + para continuar (\"\(item)\").",
                                            "After the repetition's parenthesis, use + to continue (\"\(item)\")."))
                }
                let dentro = String(resto.dropFirst().dropLast())
                if dentro.contains("(") {
                    throw ErroTextoRapido(L("Repetição dentro de repetição ainda não é aceita.", "Repetitions inside repetitions are not supported yet."))
                }
                partes = try dividir(dentro, em: ["/", "+", ",", ";", "\n"])
            } else {
                partes = try dividir(resto, em: ["/"])
            }
            guard !partes.isEmpty else { throw ErroTextoRapido(L("Faltou o que repetir em \"\(item)\".", "Missing what to repeat in \"\(item)\".")) }
            var passos: [PassoBruto] = []
            for parte in partes {
                if prefixoRepeticao(parte) != nil {
                    throw ErroTextoRapido(L("Repetição dentro de repetição ainda não é aceita.", "Repetitions inside repetitions are not supported yet."))
                }
                passos.append(try interpretarPasso(parte))
            }
            return [.repetir(vezes, passos)]
        }
        var texto = item
        if texto.hasPrefix("("), texto.hasSuffix(")"), fechaNoFim(texto) { texto = String(texto.dropFirst().dropLast()) }
        if texto.contains("(") || texto.contains(")") {
            throw ErroTextoRapido(L("Parênteses só servem para repetições, como 6x(400m forte / 90s trote).",
                                    "Parentheses are only for repetitions, like 6x(400m hard / 90s jog)."))
        }
        return try dividir(texto, em: ["/"]).map { .passo(try interpretarPasso($0)) }
    }

    /// O "(" do começo fecha só no último caractere.
    static func fechaNoFim(_ texto: String) -> Bool {
        var profundidade = 0
        for (i, c) in texto.enumerated() {
            if c == "(" { profundidade += 1 }
            if c == ")" {
                profundidade -= 1
                if profundidade == 0 { return i == texto.count - 1 }
            }
        }
        return false
    }

    static func interpretarPasso(_ texto: String) throws -> PassoBruto {
        let c = Array(texto)
        // O primeiro número que começa uma palavra (o "2" de "vo2" não conta).
        guard let inicio = c.indices.first(where: { c[$0].isASCII && c[$0].isNumber && ($0 == 0 || !c[$0 - 1].isLetter) }) else {
            throw ErroTextoRapido(L("Faltou quanto em \"\(texto)\": tempo (10min) ou distância (400m).",
                                    "Missing how much in \"\(texto)\": time (10min) or distance (400m)."))
        }
        let (medida, fim) = try lerMedida(c, inicio: inicio, trecho: texto)
        let resto = String(c[0..<inicio]) + " " + String(c[fim...])
        let r = Array(resto)
        let temOutroNumero = r.indices.contains { k in r[k].isASCII && r[k].isNumber && (k == 0 || !r[k - 1].isLetter) }
        if temOutroNumero {
            throw ErroTextoRapido(L("Um trecho por vez em \"\(texto)\": separe com + (ou com / dentro da repetição).",
                                    "One segment at a time in \"\(texto)\": separate them with + (or with / inside a repetition)."))
        }
        let (intensidade, funcao) = try lerIntensidade(resto, trecho: texto)
        return PassoBruto(medida: medida, intensidade: intensidade, funcao: funcao)
    }

    // MARK: Medida

    enum Unidade {
        case tempo(Double)
        case distancia(Double)
    }

    /// Da mais longa para a mais curta dentro de cada família: com a unidade colada na palavra
    /// seguinte ("400mforte"), vale a primeira que for começo das letras.
    static let unidades: [(String, Unidade)] = [
        // Inglês (nenhuma é começo de uma unidade em português).
        ("kilometers", .distancia(1000)), ("kilometres", .distancia(1000)), ("kilometer", .distancia(1000)),
        ("kilometre", .distancia(1000)), ("minutes", .tempo(60)), ("seconds", .tempo(1)), ("minute", .tempo(60)),
        ("second", .tempo(1)), ("meters", .distancia(1)), ("metres", .distancia(1)), ("meter", .distancia(1)),
        ("metre", .distancia(1)), ("hours", .tempo(3600)), ("hour", .tempo(3600)), ("secs", .tempo(1)),
        ("sec", .tempo(1)),
        // Português.
        ("quilometros", .distancia(1000)), ("quilometro", .distancia(1000)), ("minutos", .tempo(60)),
        ("segundos", .tempo(1)), ("segundo", .tempo(1)), ("minuto", .tempo(60)), ("metros", .distancia(1)),
        ("horas", .tempo(3600)), ("metro", .distancia(1)), ("hora", .tempo(3600)), ("mins", .tempo(60)),
        ("segs", .tempo(1)), ("min", .tempo(60)), ("seg", .tempo(1)), ("mts", .distancia(1)), ("km", .distancia(1000)),
        ("hr", .tempo(3600)), ("mt", .distancia(1)), ("h", .tempo(3600)), ("m", .distancia(1)), ("k", .distancia(1000)),
        ("s", .tempo(1)),
        // "hrs" no fim: colado ("1hrsolto"), o "hr" do português vem antes.
        ("hrs", .tempo(3600)),
    ]

    static func lerNumero(_ c: [Character], _ i0: Int) -> (Double, Int)? {
        var i = i0
        var texto = ""
        while i < c.count, c[i].isASCII, c[i].isNumber { texto.append(c[i]); i += 1 }
        guard !texto.isEmpty else { return nil }
        if i + 1 < c.count, c[i] == "," || c[i] == ".", c[i + 1].isASCII, c[i + 1].isNumber {
            texto.append(".")
            i += 1
            while i < c.count, c[i].isASCII, c[i].isNumber { texto.append(c[i]); i += 1 }
        }
        guard let valor = Double(texto) else { return nil }
        return (valor, i)
    }

    static func pularEspacos(_ c: [Character], _ i0: Int) -> Int {
        var i = i0
        while i < c.count, c[i] == " " || c[i] == "\t" { i += 1 }
        return i
    }

    /// Lê a unidade a partir de `i0`: aspas, ou letras cujo começo é uma unidade conhecida.
    static func lerUnidade(_ c: [Character], _ i0: Int) -> (Unidade, Int)? {
        guard i0 < c.count else { return nil }
        if c[i0] == "\"" { return (.tempo(1), i0 + 1) }
        if c[i0] == "'" {
            if i0 + 1 < c.count, c[i0 + 1] == "'" { return (.tempo(1), i0 + 2) }
            return (.tempo(60), i0 + 1)
        }
        var letras = ""
        var j = i0
        while j < c.count, c[j].isLetter { letras.append(c[j]); j += 1 }
        guard !letras.isEmpty else { return nil }
        if let exata = unidades.first(where: { $0.0 == letras }) { return (exata.1, j) }
        // Unidade colada na palavra seguinte ("400mforte"): a mais longa que caiba.
        for (nome, unidade) in unidades where letras.hasPrefix(nome) {
            return (unidade, i0 + nome.count)
        }
        return nil
    }

    static func lerMedida(_ c: [Character], inicio: Int, trecho: String) throws -> (Medida, Int) {
        var i = inicio
        var segundos = 0.0
        var metros = 0.0
        var temTempo = false
        var temDistancia = false
        var implicita: Double?   // unidade de um número solto depois de "1h" (minutos) ou "2min" (segundos)

        while i < c.count, c[i].isASCII, c[i].isNumber {
            guard let lido = lerNumero(c, i) else { break }
            let valor = lido.0
            i = lido.1
            if i < c.count, c[i] == ":" {
                var partes = [valor]
                while i < c.count, c[i] == ":" {
                    guard let parte = lerNumero(c, i + 1) else {
                        throw ErroTextoRapido(L("Tempo incompleto em \"\(trecho)\" (use 2:30 ou 1:05:00).",
                                                "Incomplete time in \"\(trecho)\" (use 2:30 or 1:05:00)."))
                    }
                    partes.append(parte.0)
                    i = parte.1
                }
                guard partes.count <= 3 else { throw ErroTextoRapido(L("Tempo estranho em \"\(trecho)\".", "Odd time in \"\(trecho)\".")) }
                segundos += partes.count == 2 ? partes[0] * 60 + partes[1] : partes[0] * 3600 + partes[1] * 60 + partes[2]
                temTempo = true
                let k = pularEspacos(c, i)
                if let lida = lerUnidade(c, k), case .tempo = lida.0 { i = lida.1 }
                break
            }
            let k = pularEspacos(c, i)
            if let lida = lerUnidade(c, k) {
                switch lida.0 {
                case let .tempo(f):
                    segundos += valor * f
                    temTempo = true
                    if f == 3600 {
                        implicita = 60
                    } else if f == 60 {
                        implicita = 1
                    } else {
                        implicita = nil
                    }
                case let .distancia(f):
                    metros += valor * f
                    temDistancia = true
                    implicita = nil
                }
                i = lida.1
            } else if let f = implicita {
                segundos += valor * f
                implicita = nil
                break
            } else {
                let numero = String(c[inicio..<i]).trimmingCharacters(in: .whitespaces)
                throw ErroTextoRapido(L("Faltou a unidade depois de \"\(numero)\" em \"\(trecho)\": use min, s, m ou km.",
                                        "Missing unit after \"\(numero)\" in \"\(trecho)\": use min, s, m or km."))
            }
            let proximo = pularEspacos(c, i)
            guard proximo < c.count, c[proximo].isASCII, c[proximo].isNumber else { break }
            i = proximo
        }

        if temTempo && temDistancia {
            throw ErroTextoRapido(L("Use tempo ou distância, não os dois, em \"\(trecho)\".",
                                    "Use time or distance, not both, in \"\(trecho)\"."))
        }
        if temDistancia {
            let d = (metros * 10).rounded() / 10
            guard d > 0, d <= distanciaMaxima else {
                throw ErroTextoRapido(L("Distância fora do normal em \"\(trecho)\".", "Unusual distance in \"\(trecho)\"."))
            }
            return (.distancia(d), i)
        }
        let t = segundos.rounded()
        guard t > 0, t <= tempoMaximo else { throw ErroTextoRapido(L("Tempo fora do normal em \"\(trecho)\".", "Unusual time in \"\(trecho)\".")) }
        return (.tempo(t), i)
    }

    // MARK: Intensidade

    static let enchimento: Set<String> = [
        "de", "do", "da", "em", "no", "na", "a", "o", "ao", "com", "ritmo", "pace", "zona", "bem", "um", "uma", "pouco",
        // Inglês.
        "at", "the", "of", "in", "on", "with", "an", "zone", "run",
    ]

    static let dicionario: [String: (Intensidade?, FuncaoPasso?)] = {
        var d: [String: (Intensidade?, FuncaoPasso?)] = [:]
        func por(_ palavras: [String], _ i: Intensidade?, _ f: FuncaoPasso? = nil) {
            for p in palavras { d[p] = (i, f) }
        }
        por(["caminhada", "caminhar", "caminhando", "andar", "andando", "walk", "walking"], .caminhada)
        por(["facil", "leve", "solto", "suave", "regenerativo", "easy", "trote", "trotando", "jog", "jogging", "z2"], .facil)
        por(["aquecimento", "aquecer", "aquece", "aq", "warmup"], .facil, .aquecimento)
        por(["desaquecimento", "desaquecer", "desaq", "volta calma", "calma", "cooldown"], .facil, .desaquecimento)
        por(["rec", "recuperacao", "recuperar", "recupera", "intervalo", "recovery", "recover"], .facil, .recuperacao)
        por(["descanso", "pausa", "parado", "parada", "repouso", "rest", "resting"], .caminhada, .recuperacao)
        por(["maratona", "rm", "mp", "marathon"], .maratona)
        por(["limiar", "tempo", "threshold", "lim", "t"], .limiar)
        por(["forte", "tiro", "tiros", "intervalado", "intervalados", "vo2", "vo2max", "i", "int",
             "hard", "interval", "intervals"], .intervalado)
        por(["rapido", "rapida", "muito forte", "repeticao", "repeticoes", "r", "rep", "sprint", "sprints", "velocidade", "tiro curto", "aceleracao", "aceleracoes",
             "fast", "very hard", "repetition", "repetitions", "reps", "stride", "strides", "speed"], .repeticoes)
        por(["prova", "race", "competicao", "teste", "test"], .prova)
        return d
    }()

    static func lerIntensidade(_ texto: String, trecho: String) throws -> (Intensidade?, FuncaoPasso?) {
        let palavras = texto
            .split(whereSeparator: { !$0.isLetter && !($0.isASCII && $0.isNumber) })
            .map(String.init)
            .filter { !enchimento.contains($0) }
        guard !palavras.isEmpty else { return (nil, nil) }
        if let frase = dicionario[palavras.joined(separator: " ")] { return frase }
        var intensidade: Intensidade?
        var funcao: FuncaoPasso?
        for palavra in palavras {
            guard let par = dicionario[palavra] else {
                throw ErroTextoRapido(L("Não entendi \"\(palavra)\" em \"\(trecho)\". Use fácil, trote, limiar, forte, rápido, maratona, prova ou caminhada.",
                                        "I didn't understand \"\(palavra)\" in \"\(trecho)\". Use easy, jog, threshold, hard, fast, marathon, race or walk."))
            }
            let (i, f) = par
            if let f, funcao == nil { funcao = f }
            if let i {
                // Palavra de função ("aquecimento") não troca uma intensidade já dita ("aquecimento caminhando").
                if intensidade == nil || f == nil { intensidade = i }
            }
        }
        return (intensidade, funcao)
    }

    // MARK: Funções

    /// Ordem de esforço para decidir aquecimento, trabalho e recuperação.
    static func ordem(_ i: Intensidade) -> Int {
        switch i {
        case .caminhada: 0
        case .facil: 1
        case .maratona: 2
        case .limiar, .prova: 3
        case .intervalado: 4
        case .repeticoes: 5
        }
    }

    /// Aquecimento e desaquecimento são trechos curtos (escolha do app): um trecho fácil
    /// longo no começo é parte do treino, como no progressivo.
    static func cabeEmAquecimento(_ medida: Medida) -> Bool {
        switch medida {
        case let .tempo(t): t <= 25 * 60
        case let .distancia(d): d <= 4000
        }
    }

    static func inferirFuncoes(_ brutos: [BlocoBruto]) -> [Bloco] {
        // Intensidade padrão: fácil; o primeiro passo de uma repetição, intervalado.
        let preenchidos: [BlocoBruto] = brutos.map { bloco in
            switch bloco {
            case var .passo(p):
                if p.intensidade == nil { p.intensidade = .facil }
                return .passo(p)
            case let .repetir(vezes, passos):
                let novos = passos.enumerated().map { k, passo -> PassoBruto in
                    var p = passo
                    if p.intensidade == nil { p.intensidade = k == 0 ? .intervalado : .facil }
                    return p
                }
                return .repetir(vezes, novos)
            }
        }

        func ordemMaxima(_ bloco: BlocoBruto) -> Int {
            switch bloco {
            case let .passo(p): ordem(p.intensidade ?? .facil)
            case let .repetir(_, passos): passos.map { ordem($0.intensidade ?? .facil) }.max() ?? 0
            }
        }
        let ordens = preenchidos.map(ordemMaxima)
        var funcoes: [FuncaoPasso?] = preenchidos.map { bloco in
            if case let .passo(p) = bloco { return p.funcao }
            return nil
        }

        // Começo: passos leves e curtos antes de algo mais forte viram aquecimento.
        var inicioTrabalho = 0
        for i in preenchidos.indices {
            guard case let .passo(p) = preenchidos[i], p.funcao == nil || p.funcao == .aquecimento else { break }
            let depois = ordens[(i + 1)...].max() ?? -1
            guard p.funcao == .aquecimento || (ordens[i] < depois && cabeEmAquecimento(p.medida)) else { break }
            funcoes[i] = .aquecimento
            inicioTrabalho = i + 1
        }
        // Fim: passos leves e curtos depois de algo mais forte viram desaquecimento.
        var fimTrabalho = preenchidos.count
        for i in preenchidos.indices.reversed() where i >= inicioTrabalho {
            guard case let .passo(p) = preenchidos[i], p.funcao == nil || p.funcao == .desaquecimento else { break }
            let antes = ordens[..<i].max() ?? -1
            guard p.funcao == .desaquecimento || (ordens[i] < antes && cabeEmAquecimento(p.medida)) else { break }
            funcoes[i] = .desaquecimento
            fimTrabalho = i
        }
        // Meio: passo leve entre dois trechos de qualidade é recuperação; o resto, trabalho.
        for i in preenchidos.indices where funcoes[i] == nil {
            guard case .passo = preenchidos[i] else { continue }
            let antes = ordens[inicioTrabalho..<i].max() ?? -1
            let depois = i + 1 < fimTrabalho ? (ordens[(i + 1)..<fimTrabalho].max() ?? -1) : -1
            funcoes[i] = (ordens[i] <= 1 && antes >= 2 && depois >= 2) ? .recuperacao : .trabalho
        }

        return preenchidos.enumerated().map { i, bloco -> Bloco in
            switch bloco {
            case let .passo(p):
                return .passo(Passo(funcoes[i] ?? .trabalho, p.medida, p.intensidade ?? .facil))
            case let .repetir(vezes, passos):
                let maior = passos.map { ordem($0.intensidade ?? .facil) }.max() ?? 0
                return .repetir(vezes: vezes, passos: passos.map { p in
                    let i = p.intensidade ?? .facil
                    let funcao = p.funcao ?? (ordem(i) < maior ? .recuperacao : .trabalho)
                    return Passo(funcao, p.medida, i)
                })
            }
        }
    }
}

extension Treino {
    /// Tipo de um treino montado à mão: o trecho de trabalho mais intenso decide.
    public static func tipoInferido(_ blocos: [Bloco]) -> TipoTreino {
        let passos = Treino(nome: "", tipo: .facil, blocos: blocos).passosExpandidos
        let trabalho = passos.filter { $0.funcao == .trabalho }
        let referencia = trabalho.isEmpty ? passos : trabalho
        let maisForte = referencia.map(\.intensidade).max { TextoRapido.ordem($0) < TextoRapido.ordem($1) }
        switch maisForte {
        case .repeticoes: return .repeticoes
        case .intervalado: return .intervalado
        case .limiar: return .limiar
        case .prova: return .prova
        case .maratona: return .ritmoProva
        case .caminhada: return .caminhada
        case .facil, nil: return .facil
        }
    }
}
