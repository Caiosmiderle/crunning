import AuthenticationServices
import CrunningCore
import Foundation
import Network
import SwiftData
import SwiftUI

/// Envio das corridas ao Strava pela API oficial, com o app que você criou na sua conta
/// (strava.com/settings/api; exige assinatura do Strava). Client ID, Client Secret e tokens
/// ficam só no Keychain do iPhone, nunca no repositório, no .ipa, no CI ou em log.
///
/// Só envia: o CRUNNING não lê nada do Strava. A política da API do Strava (seção 5.3) proíbe
/// usar dados do Strava em aplicação de IA, inclusive no contexto do modelo, e assim nenhum
/// dado do Strava chega ao Coach de IA.
enum Strava {
    struct Credenciais: Codable, Sendable {
        var clientID: String
        var clientSecret: String
    }

    struct Tokens: Codable, Sendable {
        var acesso: String
        var renovacao: String
        var expiraEm: Date
    }

    enum Erro: LocalizedError {
        case semCredenciais
        case desconectado
        case semPermissaoDeEnvio
        case recusado(String)
        case http(Int)
        case demorou
        case processamento(String)

        var errorDescription: String? {
            switch self {
            case .semCredenciais: L("Falta o Client ID e o Client Secret do seu app do Strava (Ajustes > Strava).", "The Client ID and Client Secret of your Strava app are missing (Settings > Strava).")
            case .desconectado: L("O Strava não está conectado (ou a autorização foi revogada). Conecte de novo em Ajustes > Strava.", "Strava is not connected (or the authorization was revoked). Connect again in Settings > Strava.")
            case .semPermissaoDeEnvio: L("Para enviar corridas, deixe marcada a permissão de enviar atividades ao autorizar.", "To upload runs, keep the permission to upload activities checked when authorizing.")
            case let .recusado(motivo): motivo
            case let .http(codigo): L("O Strava respondeu com erro (\(codigo)). Tente de novo mais tarde.", "Strava returned an error (\(codigo)). Try again later.")
            case .demorou: L("O Strava ainda está processando a corrida. Ela deve aparecer lá em instantes; se não aparecer, tente de novo.", "Strava is still processing the run. It should show up there shortly; if it does not, try again.")
            case let .processamento(motivo): L("O Strava não aceitou o arquivo: \(motivo)", "Strava did not accept the file: \(motivo)")
            }
        }
    }

    static let esquemaRetorno = "crunning"
    /// Dentro do domínio de retorno "localhost", que o app do Strava precisa ter.
    static let enderecoRetorno = "crunning://localhost/strava"

    private static let cofreCredenciais = ItemChaveiro(servico: "io.github.caiosmiderle.crunning.strava", conta: "credenciais")
    private static let cofreTokens = ItemChaveiro(servico: "io.github.caiosmiderle.crunning.strava", conta: "tokens")

    static var credenciais: Credenciais? {
        cofreCredenciais.ler().flatMap { try? JSONDecoder().decode(Credenciais.self, from: $0) }
    }

    static func salvarCredenciais(_ c: Credenciais) {
        if let dados = try? JSONEncoder().encode(c) { cofreCredenciais.salvar(dados) }
    }

    static func apagarCredenciais() {
        cofreCredenciais.apagar()
        cofreTokens.apagar()
    }

    private static var tokens: Tokens? {
        cofreTokens.ler().flatMap { try? JSONDecoder().decode(Tokens.self, from: $0) }
    }

    private static func salvar(_ t: Tokens) {
        if let dados = try? JSONEncoder().encode(t) { cofreTokens.salvar(dados) }
    }

    static var conectado: Bool { tokens != nil }

    static var envioAutomatico: Bool {
        conectado && (UserDefaults.standard.object(forKey: Preferencias.stravaAutomatico) as? Bool ?? true)
    }

    // MARK: Conectar

    /// Abre a autorização do Strava (com a sua conta, no navegador do sistema) e troca o código
    /// pelos tokens. Pede só a permissão de enviar atividades.
    @MainActor
    static func conectar(com sessao: WebAuthenticationSession) async throws {
        guard let c = credenciais else { throw Erro.semCredenciais }
        var endereco = URLComponents(string: "https://www.strava.com/oauth/authorize")!
        endereco.queryItems = [
            URLQueryItem(name: "client_id", value: c.clientID),
            URLQueryItem(name: "redirect_uri", value: enderecoRetorno),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: "activity:write"),
        ]
        guard let url = endereco.url else { throw Erro.semCredenciais }
        let retorno = try await sessao.authenticate(
            using: url, callback: .customScheme(esquemaRetorno), preferredBrowserSession: .shared, additionalHeaderFields: [:]
        )
        let itens = URLComponents(url: retorno, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func valor(_ nome: String) -> String? { itens.first { $0.name == nome }?.value }
        if let erro = valor("error") {
            throw Erro.recusado(erro == "access_denied" ? L("Você não autorizou o CRUNNING no Strava.", "You did not authorize CRUNNING on Strava.") : L("O Strava recusou: \(erro)", "Strava refused: \(erro)"))
        }
        guard let codigo = valor("code") else { throw Erro.recusado(L("O Strava não devolveu o código de autorização.", "Strava did not return the authorization code.")) }
        guard (valor("scope") ?? "").contains("activity:write") else { throw Erro.semPermissaoDeEnvio }
        let novos = try await pedirTokens([
            "client_id": c.clientID, "client_secret": c.clientSecret, "code": codigo, "grant_type": "authorization_code",
        ])
        salvar(novos)
    }

    /// Revoga a autorização no Strava (melhor esforço) e apaga os tokens do iPhone.
    static func desconectar() async {
        if let c = credenciais, let t = tokens, let url = URL(string: "https://www.strava.com/oauth/revoke") {
            var pedido = URLRequest(url: url)
            pedido.httpMethod = "POST"
            let basico = Data("\(c.clientID):\(c.clientSecret)".utf8).base64EncodedString()
            pedido.setValue("Basic \(basico)", forHTTPHeaderField: "Authorization")
            pedido.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            pedido.httpBody = formulario(["token": t.renovacao, "token_type_hint": "refresh_token"])
            _ = try? await URLSession.shared.data(for: pedido)
        }
        cofreTokens.apagar()
    }

    // MARK: Tokens

    private struct RespostaToken: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Int
    }

    private static func pedirTokens(_ campos: [String: String]) async throws -> Tokens {
        var pedido = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        pedido.httpMethod = "POST"
        pedido.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = formulario(campos)
        let (dados, resposta) = try await URLSession.shared.data(for: pedido)
        let codigo = (resposta as? HTTPURLResponse)?.statusCode ?? 0
        guard codigo == 200 else {
            if codigo == 400 || codigo == 401 {
                throw Erro.recusado(L("O Strava recusou as credenciais. Confira o Client ID e o Client Secret do seu app.", "Strava rejected the credentials. Check the Client ID and Client Secret of your app."))
            }
            throw Erro.http(codigo)
        }
        let decodificador = JSONDecoder()
        decodificador.keyDecodingStrategy = .convertFromSnakeCase
        let r = try decodificador.decode(RespostaToken.self, from: dados)
        return Tokens(acesso: r.accessToken, renovacao: r.refreshToken, expiraEm: Date(timeIntervalSince1970: TimeInterval(r.expiresAt)))
    }

    /// Token de acesso válido, renovado se estiver para vencer (ele dura 6 horas). O Strava pode
    /// trocar o token de renovação a cada renovação, então o novo sempre é guardado.
    private static func tokenValido() async throws -> String {
        guard let c = credenciais else { throw Erro.semCredenciais }
        guard let t = tokens else { throw Erro.desconectado }
        if t.expiraEm.timeIntervalSinceNow > 120 { return t.acesso }
        do {
            let novos = try await pedirTokens([
                "client_id": c.clientID, "client_secret": c.clientSecret, "grant_type": "refresh_token", "refresh_token": t.renovacao,
            ])
            salvar(novos)
            return novos.acesso
        } catch Erro.recusado {
            cofreTokens.apagar()
            throw Erro.desconectado
        }
    }

    // MARK: Envio

    private struct Envio: Decodable {
        let id: Int64?
        let idStr: String?
        let error: String?
        let status: String?
        let activityId: Int64?
    }

    /// Envia o TCX e espera o Strava processar. Devolve o id da atividade. Se o Strava disser
    /// que é repetida, devolve a atividade que já estava lá.
    static func enviar(tcx: Data, nome: String, esteira: Bool, idExterno: String) async throws -> Int64 {
        let token = try await tokenValido()
        let limite = "crunning-" + UUID().uuidString
        var corpo = Data()
        func campo(_ nome: String, _ valor: String) {
            corpo.append(Data("--\(limite)\r\nContent-Disposition: form-data; name=\"\(nome)\"\r\n\r\n\(valor)\r\n".utf8))
        }
        campo("data_type", "tcx")
        campo("name", nome)
        campo("sport_type", "Run")
        campo("trainer", esteira ? "1" : "0")
        campo("external_id", idExterno)
        corpo.append(Data("--\(limite)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(idExterno)\"\r\nContent-Type: application/xml\r\n\r\n".utf8))
        corpo.append(tcx)
        corpo.append(Data("\r\n--\(limite)--\r\n".utf8))

        var pedido = URLRequest(url: URL(string: "https://www.strava.com/api/v3/uploads")!)
        pedido.httpMethod = "POST"
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        pedido.setValue("multipart/form-data; boundary=\(limite)", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = corpo
        let (dados, resposta) = try await URLSession.shared.data(for: pedido)
        var envio = try ler(dados, resposta)

        // O Strava processa o arquivo em segundo plano; a consulta é no máximo 1 por segundo.
        for _ in 0..<30 {
            if let atividade = envio.activityId { return atividade }
            if let erro = envio.error, !erro.isEmpty {
                if let repetida = atividadeRepetida(erro) { return repetida }
                throw Erro.processamento(erro)
            }
            try await Task.sleep(for: .seconds(2))
            guard let id = envio.idStr ?? envio.id.map({ String($0) }),
                  let url = URL(string: "https://www.strava.com/api/v3/uploads/\(id)") else { throw Erro.demorou }
            var consulta = URLRequest(url: url)
            consulta.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (d, r) = try await URLSession.shared.data(for: consulta)
            envio = try ler(d, r)
        }
        throw Erro.demorou
    }

    private static func ler(_ dados: Data, _ resposta: URLResponse) throws -> Envio {
        let codigo = (resposta as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(codigo) else {
            if codigo == 401 { throw Erro.desconectado }
            throw Erro.http(codigo)
        }
        let decodificador = JSONDecoder()
        decodificador.keyDecodingStrategy = .convertFromSnakeCase
        return try decodificador.decode(Envio.self, from: dados)
    }

    /// "… duplicate of activity 21234316" (pode vir com HTML): o último número é a atividade.
    static func atividadeRepetida(_ erro: String) -> Int64? {
        guard erro.localizedCaseInsensitiveContains("duplicate") else { return nil }
        return erro.split(whereSeparator: { !$0.isNumber }).compactMap { Int64($0) }.last
    }

    private static func formulario(_ campos: [String: String]) -> Data {
        var permitidos = CharacterSet.alphanumerics
        permitidos.insert(charactersIn: "-._~")
        let texto = campos.map { chave, valor in
            "\(chave)=\(valor.addingPercentEncoding(withAllowedCharacters: permitidos) ?? valor)"
        }.joined(separator: "&")
        return Data(texto.utf8)
    }
}

/// Fila de envio ao Strava. A corrida salva entra na fila (`stravaPendente`) e sai dela quando o
/// Strava cria a atividade. A fila é processada ao salvar, quando o app volta para a tela e quando
/// a internet volta; ao sair do app logo depois de salvar, o iOS dá alguns segundos para terminar.
/// Só para de tentar sozinho quando o Strava recusa o arquivo (aí fica o botão no detalhe).
@MainActor
enum EnvioStrava {
    private static var contexto: ModelContext?
    private static var processando = false
    private static var vigia: NWPathMonitor?

    /// Chamado uma vez, com o contexto principal do app.
    static func configurar(_ contexto: ModelContext) {
        self.contexto = contexto
        guard vigia == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { caminho in
            guard caminho.status == .satisfied else { return }
            Task { @MainActor in await EnvioStrava.processarFila() }
        }
        monitor.start(queue: DispatchQueue(label: "io.github.caiosmiderle.crunning.rede", qos: .utility))
        vigia = monitor
    }

    /// Põe a corrida na fila e tenta enviar.
    static func enfileirar(_ corrida: Corrida) async {
        guard !corrida.simulada, !corrida.exemplo, corrida.stravaAtividade == nil else { return }
        corrida.stravaPendente = true
        corrida.stravaErro = nil
        try? contexto?.save()
        await processarFila()
    }

    /// Envia, uma por vez, as corridas da fila.
    static func processarFila() async {
        guard !processando, Strava.conectado, let contexto else { return }
        processando = true
        defer { processando = false }
        let descricao = FetchDescriptor<Corrida>(
            predicate: #Predicate { $0.stravaPendente && $0.stravaAtividade == nil },
            sortBy: [SortDescriptor(\.inicio)]
        )
        guard let fila = try? contexto.fetch(descricao), !fila.isEmpty else { return }
        let tarefa = TarefaSegundoPlano(nome: "Envio ao Strava")
        defer { tarefa.encerrar() }
        for corrida in fila {
            await enviar(corrida, contexto: contexto)
        }
    }

    private static func enviar(_ corrida: Corrida, contexto: ModelContext) async {
        let tcx = Data(Exportacao.textoTCX(de: corrida).utf8)
        let nome = corrida.titulo
        let esteira = corrida.esteira
        let idExterno = "crunning-\(Int(corrida.inicio.timeIntervalSince1970)).tcx"
        let resultado: Result<Int64, Error>
        do {
            resultado = .success(try await Strava.enviar(tcx: tcx, nome: nome, esteira: esteira, idExterno: idExterno))
        } catch {
            resultado = .failure(error)
        }
        guard !corrida.isDeleted else { return }
        switch resultado {
        case let .success(id):
            corrida.stravaAtividade = id
            corrida.stravaPendente = false
            corrida.stravaErro = nil
        case let .failure(erro):
            corrida.stravaErro = erro.localizedDescription
            // Arquivo recusado não melhora tentando de novo; sem internet, desconectado etc. continua na fila.
            if let e = erro as? Strava.Erro, case .processamento = e { corrida.stravaPendente = false }
        }
        try? contexto.save()
    }
}

/// Pede ao iOS alguns segundos para terminar um trabalho se o app for para o segundo plano.
@MainActor
final class TarefaSegundoPlano {
    private var id: UIBackgroundTaskIdentifier = .invalid

    init(nome: String) {
        id = UIApplication.shared.beginBackgroundTask(withName: nome) { [weak self] in
            // O iOS chama isto na fila principal quando o tempo acaba.
            MainActor.assumeIsolated { self?.encerrar() }
        }
    }

    func encerrar() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
