import Foundation

/// Exportar em TCX (Training Center XML, da Garmin), aceito por HealthFit, Strava, Garmin
/// Connect e outros. Diferente do GPX, leva distância, tempo e energia da corrida inteira e
/// funciona sem rota (corrida na esteira). Plano B do Apple Saúde com Apple ID gratuito.
public enum TCX {
    public struct Resumo: Sendable, Equatable {
        public var nome: String
        public var inicio: Date
        public var duracaoEmMovimento: TimeInterval
        public var distancia: Double
        /// Quilocalorias (0 se não houver peso em Ajustes).
        public var calorias: Double

        public init(nome: String, inicio: Date, duracaoEmMovimento: TimeInterval, distancia: Double, calorias: Double) {
            self.nome = nome
            self.inicio = inicio
            self.duracaoEmMovimento = duracaoEmMovimento
            self.distancia = distancia
            self.calorias = calorias
        }
    }

    /// Uma volta só com a corrida inteira; os pontos da rota (se houver) vão no `<Track>`.
    public static func gerar(_ r: Resumo, amostras: [AmostraTrilha]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Running">
              <Id>\(r.inicio.formatted(.iso8601))</Id>
              <Lap StartTime="\(r.inicio.formatted(.iso8601))">
                <TotalTimeSeconds>\(String(format: "%.1f", max(0, r.duracaoEmMovimento)))</TotalTimeSeconds>
                <DistanceMeters>\(String(format: "%.1f", max(0, r.distancia)))</DistanceMeters>
                <Calories>\(min(65_535, max(0, Int(r.calorias.rounded()))))</Calories>
                <Intensity>Active</Intensity>
                <TriggerMethod>Manual</TriggerMethod>

        """
        if !amostras.isEmpty {
            xml += "        <Track>\n"
            for a in amostras {
                xml += "          <Trackpoint><Time>\(r.inicio.addingTimeInterval(a.t).formatted(.iso8601))</Time>"
                xml += "<Position><LatitudeDegrees>\(String(format: "%.7f", a.lat))</LatitudeDegrees>"
                xml += "<LongitudeDegrees>\(String(format: "%.7f", a.lon))</LongitudeDegrees></Position>"
                if let alt = a.alt { xml += "<AltitudeMeters>\(String(format: "%.1f", alt))</AltitudeMeters>" }
                xml += "<DistanceMeters>\(String(format: "%.1f", a.d))</DistanceMeters></Trackpoint>\n"
            }
            xml += "        </Track>\n"
        }
        xml += """
              </Lap>
              <Notes>\(GPX.escapar(r.nome))</Notes>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>

        """
        return xml
    }

    /// Nome de arquivo sem caracteres problemáticos: "crunning-2026-11-09-0712.tcx".
    public static func nomeArquivo(inicio: Date, extensao: String) -> String {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = .current
        let c = calendario.dateComponents([.year, .month, .day, .hour, .minute], from: inicio)
        func dois(_ n: Int?) -> String { String(format: "%02d", n ?? 0) }
        return "crunning-\(c.year ?? 0)-\(dois(c.month))-\(dois(c.day))-\(dois(c.hour))\(dois(c.minute)).\(extensao)"
    }
}
