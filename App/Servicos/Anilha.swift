import CryptoKit
import CrunningCore
import Foundation
import SwiftData

/// Conexão com o Anilha (app de musculação do Caio), contrato v1: o CRUNNING manda as corridas
/// feitas e os treinos planejados dos próximos 14 dias. Só resumos (tipo, distância, tempo,
/// esforço, dia do plano); nunca rota, GPS, batimentos ou texto. O token pessoal, gerado no
/// Anilha, fica no Keychain. Sem token, nada sai do iPhone.
enum Anilha {
    private static let chaveiro = ItemChaveiro(servico: "io.github.caiosmiderle.crunning.anilha", conta: "token")
    /// Endereço da função no Supabase do Anilha (a referência do projeto é pública: vai no site).
    static let enderecoPadrao = "https://ssuuvzgqtobnfvobvjcu.supabase.co/functions/v1/troca-crunning"

    static var token: String? {
        chaveiro.ler().flatMap { String(data: $0, encoding: .utf8) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    static var conectado: Bool { token != nil }

    @discardableResult
    static func salvarToken(_ texto: String) -> Bool {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("anl_"), t.count >= 20 else { return false }
        return chaveiro.salvar(Data(t.utf8))
    }

    static func desconectar() {
        _ = chaveiro.apagar()
        UserDefaults.standard.removeObject(forKey: Chaves.apagadas)
        UserDefaults.standard.removeObject(forKey: Chaves.assinaturaPlanejados)
    }

    /// Endereço usado (o modo de desenvolvimento pode apontar para o servidor local do Anilha).
    static var endereco: URL {
        let personalizado = UserDefaults.standard.string(forKey: Chaves.endereco) ?? ""
        return URL(string: personalizado.isEmpty ? enderecoPadrao : personalizado) ?? URL(string: enderecoPadrao)!
    }

    enum Chaves {
        static let endereco = "anilhaEndereco"
        static let apagadas = "anilhaApagadas"
        static let assinaturaPlanejados = "anilhaAssinaturaPlanejados"
        static let ultimoEnvio = "anilhaUltimoEnvio"
        static let ultimoErro = "anilhaUltimoErro"
    }

    enum Erro: LocalizedError {
        case semToken, token, limite, versao, servidor(Int), resposta

        var errorDescription: String? {
            switch self {
            case .semToken: L("Cole o token do Anilha em Ajustes > Conexões > Anilha.", "Paste the Anilha token in Settings > Connections > Anilha.")
            case .token: L("O Anilha recusou o token (inválido ou revogado). Gere outro no Anilha e cole aqui.", "Anilha rejected the token (invalid or revoked). Generate a new one in Anilha and paste it here.")
            case .limite: L("Muitos envios seguidos. Tenta de novo sozinho mais tarde.", "Too many requests. It will retry on its own later.")
            case .versao: L("O Anilha não reconhece esta versão do CRUNNING.", "Anilha does not recognize this CRUNNING version.")
            case let .servidor(c): L("O Anilha respondeu com erro \(c). Tenta de novo sozinho.", "Anilha replied with error \(c). It will retry on its own.")
            case .resposta: L("Resposta do Anilha fora do formato.", "Unexpected reply from Anilha.")
            }
        }
    }

    /// Uma chamada à função. O token vai só no cabeçalho; nunca em log nem na URL.
    static func chamar(_ metodo: String, caminho: String, corpo: Data?, consulta: [URLQueryItem] = []) async throws -> Data {
        guard let token else { throw Erro.semToken }
        var componentes = URLComponents(url: endereco.appendingPathComponent(caminho), resolvingAgainstBaseURL: false)
        if !consulta.isEmpty { componentes?.queryItems = consulta }
        guard let url = componentes?.url else { throw Erro.resposta }
        var pedido = URLRequest(url: url)
        pedido.httpMethod = metodo
        pedido.timeoutInterval = 30
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = corpo
        let (dados, resposta) = try await URLSession.shared.data(for: pedido)
        let codigo = (resposta as? HTTPURLResponse)?.statusCode ?? 0
        switch codigo {
        case 200 ..< 300: return dados
        case 401: throw Erro.token
        case 429: throw Erro.limite
        case 400 where String(data: dados, encoding: .utf8)?.contains("versao") == true: throw Erro.versao
        default: throw Erro.servidor(codigo)
        }
    }
}

/// Fila de envio ao Anilha: corridas novas, apagadas (lápides) e os planejados. Anda ao salvar
/// uma corrida, ao mudar o plano e quando o app volta para a tela.
@MainActor
enum EnvioAnilha {
    private static var contexto: ModelContext?
    private static var processando = false

    static func configurar(_ contexto: ModelContext) {
        self.contexto = contexto
        preencherCodigos()
    }

    /// Corridas de antes da conexão ganham um código estável (uma vez).
    private static func preencherCodigos() {
        guard let contexto else { return }
        let sem = FetchDescriptor<Corrida>(predicate: #Predicate { $0.codigo == "" })
        guard let lista = try? contexto.fetch(sem), !lista.isEmpty else { return }
        for c in lista { c.codigo = UUID().uuidString }
        try? contexto.save()
    }

    static func garantirCodigo(_ c: Corrida) {
        if c.codigo.isEmpty { c.codigo = UUID().uuidString }
    }

    /// Põe a corrida na fila e tenta enviar (sem token, fica marcada para quando houver).
    static func enfileirar(_ corrida: Corrida) async {
        guard !corrida.simulada, !corrida.exemplo else { return }
        garantirCodigo(corrida)
        corrida.anilhaPendente = true
        corrida.anilhaErro = nil
        try? contexto?.save()
        await processar()
    }

    /// Ao conectar: as corridas dos últimos `dias` dias entram na fila, para o Anilha ter histórico.
    static func enfileirarRecentes(dias: Int = 90) async {
        guard let contexto else { return }
        let desde = Date.now.addingTimeInterval(-Double(dias) * 86_400)
        let descricao = FetchDescriptor<Corrida>(predicate: #Predicate { !$0.simulada && !$0.exemplo && $0.inicio >= desde })
        for c in (try? contexto.fetch(descricao)) ?? [] where c.anilhaEnviadaEm == nil {
            garantirCodigo(c)
            c.anilhaPendente = true
        }
        try? contexto.save()
        await processar()
    }

    /// Antes de apagar: se o Anilha já tem (ou ia ter) a corrida, vai uma lápide.
    static func registrarApagada(_ corrida: Corrida) {
        guard !corrida.codigo.isEmpty, corrida.anilhaEnviadaEm != nil || corrida.anilhaPendente else { return }
        var lista = UserDefaults.standard.stringArray(forKey: Anilha.Chaves.apagadas) ?? []
        if !lista.contains(corrida.codigo) { lista.append(corrida.codigo) }
        UserDefaults.standard.set(lista, forKey: Anilha.Chaves.apagadas)
        // A lápide vai logo depois de a corrida sair do banco local (sem esperar o app voltar à tela).
        Task {
            try? await Task.sleep(for: .seconds(1))
            await processar()
        }
    }

    static var pendentes: Int {
        guard let contexto else { return 0 }
        let d = FetchDescriptor<Corrida>(predicate: #Predicate { $0.anilhaPendente })
        let apagadas = UserDefaults.standard.stringArray(forKey: Anilha.Chaves.apagadas)?.count ?? 0
        return ((try? contexto.fetchCount(d)) ?? 0) + apagadas
    }

    /// Manda o que estiver na fila e os planejados (se mudaram).
    static func processar() async {
        guard !processando, Anilha.conectado, let contexto else { return }
        processando = true
        defer { processando = false }
        do {
            try await enviarCorridas(contexto)
            try await enviarPlanejados(contexto)
            UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Anilha.Chaves.ultimoEnvio)
            UserDefaults.standard.removeObject(forKey: Anilha.Chaves.ultimoErro)
        } catch {
            UserDefaults.standard.set((error as? LocalizedError)?.errorDescription ?? error.localizedDescription, forKey: Anilha.Chaves.ultimoErro)
        }
    }

    private static func enviarCorridas(_ contexto: ModelContext) async throws {
        let descricao = FetchDescriptor<Corrida>(predicate: #Predicate { $0.anilhaPendente }, sortBy: [SortDescriptor(\.inicio)])
        let fila = (try? contexto.fetch(descricao)) ?? []
        var porCodigo: [String: Corrida] = [:]
        var itens: [TrocaAnilha.ItemCorrida] = []
        for c in fila {
            garantirCodigo(c)
            guard let item = TrocaAnilha.corrida(
                codigo: c.codigo, inicio: c.inicio, atualizadaEm: c.inicio.addingTimeInterval(c.duracaoTotal),
                distancia: c.distanciaMetros, duracaoMovimento: c.duracaoEmMovimento,
                tipo: TrocaAnilha.tipoDominante(c.carregarResultados()), esforco: c.esforcoPercebido, esteira: c.esteira,
                planejado: c.planoSemana.flatMap { s in c.planoDia.map { (semana: s, dia: $0) } }, stravaID: c.stravaAtividade
            ) else {
                // Sem distância ou sem tempo: o Anilha não aceita; sai da fila.
                c.anilhaPendente = false
                continue
            }
            porCodigo[c.codigo] = c
            itens.append(item)
        }
        let apagadas = UserDefaults.standard.stringArray(forKey: Anilha.Chaves.apagadas) ?? []
        itens += apagadas.map { TrocaAnilha.apagada(codigo: $0, em: .now) }
        try? contexto.save()
        guard !itens.isEmpty else { return }

        for inicio in stride(from: 0, to: itens.count, by: 50) {
            let lote = Array(itens[inicio ..< min(itens.count, inicio + 50)])
            let corpo = try TrocaAnilha.codificar(TrocaAnilha.LoteCorridas(versao: TrocaAnilha.versao, itens: lote))
            let dados = try await Anilha.chamar("POST", caminho: "corridas", corpo: corpo)
            guard let resposta = try? JSONDecoder().decode(TrocaAnilha.RespostaCorridas.self, from: dados) else { throw Anilha.Erro.resposta }
            var recusados: [String: String] = [:]
            for r in resposta.rejeitados where recusados[r.origemID] == nil { recusados[r.origemID] = r.motivo }
            var restantes = UserDefaults.standard.stringArray(forKey: Anilha.Chaves.apagadas) ?? []
            for item in lote {
                if item.apagado {
                    restantes.removeAll { $0 == item.origemID }
                } else if let c = porCodigo[item.origemID], !c.isDeleted {
                    c.anilhaPendente = false
                    if let motivo = recusados[item.origemID] {
                        c.anilhaErro = motivo
                    } else {
                        c.anilhaEnviadaEm = .now
                        c.anilhaErro = nil
                    }
                }
            }
            UserDefaults.standard.set(restantes, forKey: Anilha.Chaves.apagadas)
            try? contexto.save()
        }
    }

    /// Os treinos dos próximos 14 dias. Só manda quando o conteúdo mudou ou a cada 6 h (a janela
    /// anda com os dias).
    private static func enviarPlanejados(_ contexto: ModelContext) async throws {
        guard let agenda = (try? contexto.fetch(FetchDescriptor<PlanoAtivo>()))?.first?.agenda else { return }
        let lote = TrocaAnilha.planejados(agenda, hoje: .now)
        let corpo = try TrocaAnilha.codificar(lote)
        let assinatura = SHA256.hash(data: corpo).map { String(format: "%02x", $0) }.joined()
        let ultima = UserDefaults.standard.string(forKey: Anilha.Chaves.assinaturaPlanejados)
        let ultimoEnvio = UserDefaults.standard.double(forKey: Anilha.Chaves.ultimoEnvio)
        guard assinatura != ultima || Date.now.timeIntervalSince1970 - ultimoEnvio > 6 * 3600 else { return }
        let dados = try await Anilha.chamar("PUT", caminho: "planejados/corrida", corpo: corpo)
        guard (try? JSONDecoder().decode(TrocaAnilha.RespostaPlanejados.self, from: dados)) != nil else { throw Anilha.Erro.resposta }
        UserDefaults.standard.set(assinatura, forKey: Anilha.Chaves.assinaturaPlanejados)
    }

    /// O plano mudou (marcar feito, mover, trocar): manda os planejados de novo.
    static func planoMudou() {
        UserDefaults.standard.removeObject(forKey: Anilha.Chaves.assinaturaPlanejados)
        Task { await processar() }
    }
}
