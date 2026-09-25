import Foundation

enum Conversion {
    struct Request: Equatable {
        let amount: Double
        let source: String
        let destination: String
    }

    private static let units: [String: (dimension: String, factor: Double)] = [
        "B": ("data", 1), "KB": ("data", 1_000), "MB": ("data", 1_000_000),
        "GB": ("data", 1_000_000_000), "TB": ("data", 1_000_000_000_000),
        "KIB": ("data", 1_024), "MIB": ("data", 1_048_576),
        "GIB": ("data", 1_073_741_824), "TIB": ("data", 1_099_511_627_776),
        "M": ("length", 1), "KM": ("length", 1_000), "CM": ("length", 0.01),
        "MM": ("length", 0.001), "MI": ("length", 1609.344), "FT": ("length", 0.3048),
        "IN": ("length", 0.0254), "KG": ("mass", 1), "G": ("mass", 0.001),
        "LB": ("mass", 0.45359237), "OZ": ("mass", 0.028349523125)
    ]
    static let cryptoIDs = ["BTC": "bitcoin", "ETH": "ethereum", "SOL": "solana"]
    static let fiat = Set(["USD", "CAD", "EUR", "GBP", "JPY", "AUD", "CHF", "CNY", "INR", "NZD", "SEK", "NOK", "DKK", "SGD", "HKD"])

    static func parse(_ input: String) -> Request? {
        let parts = input.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: \.isWhitespace)
        if parts.count == 3, parts[1].lowercased() == "to" {
            let source = String(parts[0]).uppercased()
            let destination = String(parts[2]).uppercased()
            guard isKnown(source), isKnown(destination) else { return nil }
            return Request(amount: 1, source: source, destination: destination)
        }
        guard parts.count == 4, parts[2].lowercased() == "to",
              let amount = Double(parts[0].replacingOccurrences(of: ",", with: "")), amount.isFinite else { return nil }
        return Request(amount: amount, source: String(parts[1]).uppercased(), destination: String(parts[3]).uppercased())
    }

    private static func isKnown(_ symbol: String) -> Bool {
        units[symbol] != nil || fiat.contains(symbol) || cryptoIDs[symbol] != nil ||
            ["C", "F", "K"].contains(symbol)
    }

    static func immediate(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let request = parse(text) {
            if request.source == request.destination,
               (units[request.source] != nil || fiat.contains(request.source) || cryptoIDs[request.source] != nil) {
                return "\(format(request.amount)) \(request.destination)"
            }
            if let source = units[request.source], let destination = units[request.destination],
               source.dimension == destination.dimension {
                return "\(format(request.amount * source.factor / destination.factor)) \(request.destination)"
            }
            if let result = temperature(request) { return result }
        }
        let hex = text.lowercased().replacingOccurrences(of: "hex ", with: "")
        if hex.hasPrefix("0x"), hex.count > 2,
           let value = UInt64(hex.dropFirst(2), radix: 16) { return "\(value)" }
        if text.lowercased().hasPrefix("base64 ") {
            let encoded = String(text.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            if let data = Data(base64Encoded: encoded), let decoded = String(data: data, encoding: .utf8) {
                return decoded
            }
        }
        if text.lowercased().hasPrefix("decimal "),
           let value = UInt64(text.dropFirst(8).trimmingCharacters(in: .whitespaces)) {
            return "0x\(String(value, radix: 16).uppercased())"
        }
        return nil
    }

    static func needsRate(_ request: Request) -> Bool {
        request.source != request.destination &&
        ((fiat.contains(request.source) && fiat.contains(request.destination)) ||
         (fiat.contains(request.source) && cryptoIDs[request.destination] != nil) ||
         (cryptoIDs[request.source] != nil && fiat.contains(request.destination)))
    }

    static func rate(_ request: Request) async throws -> String {
        let source = request.source
        let destination = request.destination
        let value: Double
        if let coin = cryptoIDs[source] ?? cryptoIDs[destination] {
            let currency = cryptoIDs[source] == nil ? source : destination
            guard fiat.contains(currency),
                  let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(coin)&vs_currencies=\(currency.lowercased())") else {
                throw ConversionError.unavailable
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let prices = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            guard let price = prices[coin]?[currency.lowercased()], price > 0 else { throw ConversionError.unavailable }
            value = cryptoIDs[source] == nil ? request.amount / price : request.amount * price
        } else {
            guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=\(source)&symbols=\(destination)") else {
                throw ConversionError.unavailable
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(FiatResponse.self, from: data)
            guard let price = response.rates[destination] else { throw ConversionError.unavailable }
            value = request.amount * price
        }
        return "\(format(value)) \(destination)"
    }

    private static func temperature(_ request: Request) -> String? {
        let source = request.source, destination = request.destination
        guard ["C", "F", "K"].contains(source), ["C", "F", "K"].contains(destination) else { return nil }
        let celsius = source == "F" ? (request.amount - 32) * 5 / 9 :
            source == "K" ? request.amount - 273.15 : request.amount
        let result = destination == "F" ? celsius * 9 / 5 + 32 :
            destination == "K" ? celsius + 273.15 : celsius
        return "\(format(result)) \(destination == "K" ? "K" : "°" + destination)"
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.significantDigits(1...8)))
    }

    private struct FiatResponse: Decodable { let rates: [String: Double] }
    enum ConversionError: Error { case unavailable }
}
