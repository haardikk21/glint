import Foundation

enum Conversion {
    struct Request: Equatable {
        let amount: Double
        let source: String
        let destination: String
    }

    private struct UnitDef {
        let label: String
        let plural: String?
        let dimension: String
        let factor: Double

        func display(_ value: Double) -> String {
            guard let plural else { return label }
            return value.magnitude == 1 ? label : plural
        }
    }

    // Order matters: when an alias belongs to several units ("m" = metre or minute),
    // the first unit compatible with the other side of the conversion wins.
    private static let definitions: [(aliases: [String], unit: UnitDef)] = [
        // Length (metre)
        (["m", "meter", "meters", "metre", "metres"], UnitDef(label: "m", plural: nil, dimension: "length", factor: 1)),
        (["km", "kilometer", "kilometers", "kilometre", "kilometres", "kms"], UnitDef(label: "km", plural: nil, dimension: "length", factor: 1_000)),
        (["cm", "centimeter", "centimeters", "centimetre", "centimetres"], UnitDef(label: "cm", plural: nil, dimension: "length", factor: 0.01)),
        (["mm", "millimeter", "millimeters", "millimetre", "millimetres"], UnitDef(label: "mm", plural: nil, dimension: "length", factor: 0.001)),
        (["µm", "μm", "um", "micrometer", "micrometers", "micron", "microns"], UnitDef(label: "µm", plural: nil, dimension: "length", factor: 0.000_001)),
        (["nm", "nanometer", "nanometers", "nanometre", "nanometres"], UnitDef(label: "nm", plural: nil, dimension: "length", factor: 0.000_000_001)),
        (["mi", "mile", "miles"], UnitDef(label: "mi", plural: nil, dimension: "length", factor: 1_609.344)),
        (["yd", "yard", "yards", "yds"], UnitDef(label: "yd", plural: nil, dimension: "length", factor: 0.9144)),
        (["ft", "foot", "feet", "'"], UnitDef(label: "ft", plural: nil, dimension: "length", factor: 0.3048)),
        (["in", "inch", "inches", "\""], UnitDef(label: "in", plural: nil, dimension: "length", factor: 0.0254)),
        (["nmi", "nauticalmile", "nauticalmiles"], UnitDef(label: "nmi", plural: nil, dimension: "length", factor: 1_852)),
        // Time (second)
        (["min", "mins", "minute", "minutes", "m"], UnitDef(label: "minute", plural: "minutes", dimension: "time", factor: 60)),
        (["ms", "msec", "msecs", "millisecond", "milliseconds"], UnitDef(label: "millisecond", plural: "milliseconds", dimension: "time", factor: 0.001)),
        (["µs", "μs", "us", "microsecond", "microseconds"], UnitDef(label: "microsecond", plural: "microseconds", dimension: "time", factor: 0.000_001)),
        (["ns", "nanosecond", "nanoseconds"], UnitDef(label: "nanosecond", plural: "nanoseconds", dimension: "time", factor: 0.000_000_001)),
        (["s", "sec", "secs", "second", "seconds"], UnitDef(label: "second", plural: "seconds", dimension: "time", factor: 1)),
        (["h", "hr", "hrs", "hour", "hours"], UnitDef(label: "hour", plural: "hours", dimension: "time", factor: 3_600)),
        (["d", "day", "days"], UnitDef(label: "day", plural: "days", dimension: "time", factor: 86_400)),
        (["w", "wk", "wks", "week", "weeks"], UnitDef(label: "week", plural: "weeks", dimension: "time", factor: 604_800)),
        (["mo", "month", "months"], UnitDef(label: "month", plural: "months", dimension: "time", factor: 2_629_746)),
        (["y", "yr", "yrs", "year", "years"], UnitDef(label: "year", plural: "years", dimension: "time", factor: 31_556_952)),
        // Mass (kilogram)
        (["kg", "kgs", "kilogram", "kilograms", "kilo", "kilos"], UnitDef(label: "kg", plural: nil, dimension: "mass", factor: 1)),
        (["g", "gram", "grams", "gr"], UnitDef(label: "g", plural: nil, dimension: "mass", factor: 0.001)),
        (["mg", "milligram", "milligrams"], UnitDef(label: "mg", plural: nil, dimension: "mass", factor: 0.000_001)),
        (["t", "tonne", "tonnes", "ton", "tons"], UnitDef(label: "t", plural: nil, dimension: "mass", factor: 1_000)),
        (["lb", "lbs", "pound", "pounds"], UnitDef(label: "lb", plural: nil, dimension: "mass", factor: 0.45359237)),
        (["oz", "ounce", "ounces"], UnitDef(label: "oz", plural: nil, dimension: "mass", factor: 0.028349523125)),
        (["st", "stone", "stones"], UnitDef(label: "st", plural: nil, dimension: "mass", factor: 6.35029318)),
        // Volume (litre)
        (["l", "liter", "liters", "litre", "litres"], UnitDef(label: "L", plural: nil, dimension: "volume", factor: 1)),
        (["ml", "milliliter", "milliliters", "millilitre", "millilitres"], UnitDef(label: "mL", plural: nil, dimension: "volume", factor: 0.001)),
        (["gal", "gallon", "gallons"], UnitDef(label: "gal", plural: nil, dimension: "volume", factor: 3.785411784)),
        (["qt", "quart", "quarts"], UnitDef(label: "qt", plural: nil, dimension: "volume", factor: 0.946352946)),
        (["pt", "pint", "pints"], UnitDef(label: "pt", plural: nil, dimension: "volume", factor: 0.473176473)),
        (["cup", "cups"], UnitDef(label: "cup", plural: nil, dimension: "volume", factor: 0.2365882365)),
        (["floz", "fluidounce", "fluidounces"], UnitDef(label: "fl oz", plural: nil, dimension: "volume", factor: 0.0295735295625)),
        (["tbsp", "tablespoon", "tablespoons"], UnitDef(label: "tbsp", plural: nil, dimension: "volume", factor: 0.01478676478125)),
        (["tsp", "teaspoon", "teaspoons"], UnitDef(label: "tsp", plural: nil, dimension: "volume", factor: 0.00492892159375)),
        // Area (square metre)
        (["m2", "m²", "sqm", "squaremeter", "squaremeters", "squaremetre", "squaremetres"], UnitDef(label: "m²", plural: nil, dimension: "area", factor: 1)),
        (["km2", "km²", "sqkm", "squarekilometer", "squarekilometers"], UnitDef(label: "km²", plural: nil, dimension: "area", factor: 1_000_000)),
        (["ft2", "ft²", "sqft", "squarefoot", "squarefeet"], UnitDef(label: "ft²", plural: nil, dimension: "area", factor: 0.09290304)),
        (["mi2", "mi²", "sqmi", "squaremile", "squaremiles"], UnitDef(label: "mi²", plural: nil, dimension: "area", factor: 2_589_988.110336)),
        (["acre", "acres", "ac"], UnitDef(label: "acres", plural: nil, dimension: "area", factor: 4_046.8564224)),
        (["ha", "hectare", "hectares"], UnitDef(label: "ha", plural: nil, dimension: "area", factor: 10_000)),
        // Speed (metre per second)
        (["m/s", "mps"], UnitDef(label: "m/s", plural: nil, dimension: "speed", factor: 1)),
        (["km/h", "kmh", "kph", "kmph"], UnitDef(label: "km/h", plural: nil, dimension: "speed", factor: 1_000.0 / 3_600)),
        (["mph", "mi/h"], UnitDef(label: "mph", plural: nil, dimension: "speed", factor: 1_609.344 / 3_600)),
        (["kn", "kt", "knot", "knots"], UnitDef(label: "kn", plural: nil, dimension: "speed", factor: 1_852.0 / 3_600)),
        (["ft/s", "fps"], UnitDef(label: "ft/s", plural: nil, dimension: "speed", factor: 0.3048)),
        // Data (byte)
        (["b", "byte", "bytes"], UnitDef(label: "B", plural: nil, dimension: "data", factor: 1)),
        (["bit", "bits"], UnitDef(label: "bits", plural: nil, dimension: "data", factor: 0.125)),
        (["kb", "kilobyte", "kilobytes"], UnitDef(label: "KB", plural: nil, dimension: "data", factor: 1_000)),
        (["mb", "megabyte", "megabytes"], UnitDef(label: "MB", plural: nil, dimension: "data", factor: 1_000_000)),
        (["gb", "gigabyte", "gigabytes"], UnitDef(label: "GB", plural: nil, dimension: "data", factor: 1_000_000_000)),
        (["tb", "terabyte", "terabytes"], UnitDef(label: "TB", plural: nil, dimension: "data", factor: 1_000_000_000_000)),
        (["pb", "petabyte", "petabytes"], UnitDef(label: "PB", plural: nil, dimension: "data", factor: 1_000_000_000_000_000)),
        (["kib", "kibibyte", "kibibytes"], UnitDef(label: "KiB", plural: nil, dimension: "data", factor: 1_024)),
        (["mib", "mebibyte", "mebibytes"], UnitDef(label: "MiB", plural: nil, dimension: "data", factor: 1_048_576)),
        (["gib", "gibibyte", "gibibytes"], UnitDef(label: "GiB", plural: nil, dimension: "data", factor: 1_073_741_824)),
        (["tib", "tebibyte", "tebibytes"], UnitDef(label: "TiB", plural: nil, dimension: "data", factor: 1_099_511_627_776)),
        // Energy (joule)
        (["j", "joule", "joules"], UnitDef(label: "J", plural: nil, dimension: "energy", factor: 1)),
        (["kj", "kilojoule", "kilojoules"], UnitDef(label: "kJ", plural: nil, dimension: "energy", factor: 1_000)),
        (["cal", "calorie", "calories"], UnitDef(label: "cal", plural: nil, dimension: "energy", factor: 4.184)),
        (["kcal", "kilocalorie", "kilocalories"], UnitDef(label: "kcal", plural: nil, dimension: "energy", factor: 4_184)),
        (["wh"], UnitDef(label: "Wh", plural: nil, dimension: "energy", factor: 3_600)),
        (["kwh"], UnitDef(label: "kWh", plural: nil, dimension: "energy", factor: 3_600_000))
    ]

    private static let units: [String: [UnitDef]] = {
        var table: [String: [UnitDef]] = [:]
        for definition in definitions {
            for alias in definition.aliases { table[alias, default: []].append(definition.unit) }
        }
        return table
    }()

    private static let temperatures: [String: String] = [
        "c": "C", "°c": "C", "celsius": "C", "centigrade": "C",
        "f": "F", "°f": "F", "fahrenheit": "F",
        "k": "K", "kelvin": "K", "kelvins": "K"
    ]

    static let cryptoIDs = ["BTC": "bitcoin", "ETH": "ethereum", "SOL": "solana", "USDC": "usd-coin",
                            "USDT": "tether", "DOGE": "dogecoin", "XRP": "ripple", "ADA": "cardano",
                            "LTC": "litecoin", "AVAX": "avalanche-2", "MATIC": "matic-network", "POL": "polygon-ecosystem-token",
                            "LINK": "chainlink", "DOT": "polkadot"]
    static let fiat = Set(["USD", "CAD", "EUR", "GBP", "JPY", "AUD", "CHF", "CNY", "INR", "NZD", "SEK", "NOK",
                           "DKK", "SGD", "HKD", "MXN", "BRL", "KRW", "ZAR", "PLN", "TRY", "ILS", "CZK", "HUF",
                           "IDR", "PHP", "THB", "MYR", "RON", "ISK", "BGN"])
    private static let currencyAliases: [String: String] = [
        "$": "USD", "dollar": "USD", "dollars": "USD", "usd$": "USD", "us$": "USD",
        "€": "EUR", "euro": "EUR", "euros": "EUR",
        "£": "GBP", "quid": "GBP", "sterling": "GBP",
        "¥": "JPY", "yen": "JPY", "₹": "INR", "rupee": "INR", "rupees": "INR",
        "c$": "CAD", "ca$": "CAD", "a$": "AUD", "au$": "AUD", "₩": "KRW", "won": "KRW",
        "yuan": "CNY", "rmb": "CNY", "franc": "CHF", "francs": "CHF", "peso": "MXN", "pesos": "MXN",
        "real": "BRL", "reais": "BRL", "₿": "BTC", "bitcoin": "BTC", "bitcoins": "BTC", "sats": "BTC",
        "ether": "ETH", "ethereum": "ETH", "solana": "SOL", "doge": "DOGE", "dogecoin": "DOGE"
    ]
    private static let currencySymbols: [Character: String] = ["$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY", "₹": "INR", "₩": "KRW", "₿": "BTC"]
    private static let connectors: Set<String> = ["to", "in", "into", "as", "->", "→", "=", "=>"]
    private static let numberPattern = #"[+-]?(?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)?(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?"#
    private static let amountAndUnit = try! NSRegularExpression(pattern: "^(\(numberPattern))\\s*(.*)$")
    private static let compoundPart = try! NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)\s*([a-zµ]+)"#)

    // MARK: Parsing

    static func parse(_ input: String) -> Request? {
        let parts = input.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 2 else { return nil }
        // Prefer the right-most connector so "5 in to cm" means inches → centimetres.
        for index in stride(from: parts.count - 2, through: 1, by: -1) where connectors.contains(parts[index].lowercased()) {
            let destinationText = parts[(index + 1)...].joined()
            guard let destination = symbol(destinationText),
                  let (amount, source) = quantity(parts[..<index].joined(separator: " ")) else { continue }
            return Request(amount: amount, source: source, destination: destination)
        }
        return nil
    }

    /// Canonical uppercase symbol for a unit/currency token, or nil when unknown.
    private static func symbol(_ token: String) -> String? {
        let lower = token.lowercased()
        if let code = currencyCode(lower) { return code }
        if units[lower] != nil || temperatures[lower] != nil { return lower.uppercased() }
        return nil
    }

    private static func currencyCode(_ lower: String) -> String? {
        let upper = lower.uppercased()
        if fiat.contains(upper) || cryptoIDs[upper] != nil { return upper }
        return currencyAliases[lower]
    }

    private static func quantity(_ raw: String) -> (Double, String)? {
        var text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        // Currency symbol before or after the number: "$5", "5€", "-£3".
        var symbolCode: String?
        if let first = text.first, let code = currencySymbols[first], text.count > 1 {
            symbolCode = code; text.removeFirst()
        } else if text.hasPrefix("-"), text.count > 2, let code = currencySymbols[text[text.index(after: text.startIndex)]] {
            symbolCode = code; text.remove(at: text.index(after: text.startIndex))
        } else if let last = text.last, let code = currencySymbols[last], text.count > 1 {
            symbolCode = code; text.removeLast()
        }
        text = text.trimmingCharacters(in: .whitespaces)

        if symbolCode == nil, let seconds = compoundDuration(text) { return (seconds, "S") }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = amountAndUnit.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text) else { return nil }
        let numberText = text[numberRange].replacingOccurrences(of: ",", with: "")
        let unitText = text[unitRange].split(whereSeparator: \.isWhitespace).joined()
        let hasNumber = numberText.contains(where: \.isNumber)
        guard hasNumber || numberText.isEmpty else { return nil }
        let amount = hasNumber ? Double(numberText) : 1
        guard let amount, amount.isFinite else { return nil }
        if let symbolCode {
            if unitText.isEmpty { return (amount, symbolCode) }
            // "$5 usd" – allow a redundant code if it agrees.
            guard symbol(unitText) == symbolCode else { return nil }
            return (amount, symbolCode)
        }
        guard !unitText.isEmpty, let source = symbol(unitText) else { return nil }
        return (amount, source)
    }

    /// "1h30m", "2d 4h", "1m30s" → seconds. Requires two or more parts so "3m" stays ambiguous.
    private static func compoundDuration(_ text: String) -> Double? {
        let lower = text.lowercased()
        let range = NSRange(lower.startIndex..<lower.endIndex, in: lower)
        let matches = compoundPart.matches(in: lower, range: range)
        guard matches.count >= 2 else { return nil }
        var covered = ""
        var total = 0.0
        for match in matches {
            guard let whole = Range(match.range, in: lower), let number = Range(match.range(at: 1), in: lower),
                  let unit = Range(match.range(at: 2), in: lower), let value = Double(lower[number]),
                  let def = units[String(lower[unit])]?.first(where: { $0.dimension == "time" }) else { return nil }
            covered += lower[whole]
            total += value * def.factor
        }
        let compact = lower.filter { !$0.isWhitespace }
        guard covered.filter({ !$0.isWhitespace }) == compact, total.isFinite else { return nil }
        return total
    }

    private static func resolve(_ source: String, _ destination: String) -> (UnitDef, UnitDef)? {
        for from in units[source.lowercased()] ?? [] {
            for to in units[destination.lowercased()] ?? [] where from.dimension == to.dimension { return (from, to) }
        }
        return nil
    }

    private static func isCurrency(_ code: String) -> Bool { fiat.contains(code) || cryptoIDs[code] != nil }

    // MARK: Evaluation

    static func immediate(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let result = numberBase(text) { return result }
        if let request = parse(text) {
            if isCurrency(request.source), request.source == request.destination {
                return "\(formatMoney(request.amount, code: request.destination)) \(request.destination)"
            }
            if let (source, destination) = resolve(request.source, request.destination) {
                let value = request.amount * source.factor / destination.factor
                guard value.isFinite else { return nil }
                return "\(format(value)) \(destination.display(value))"
            }
            if let result = temperature(request) { return result }
        }
        if text.lowercased().hasPrefix("base64 ") {
            let encoded = String(text.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            if let data = Data(base64Encoded: encoded), let decoded = String(data: data, encoding: .utf8) {
                return decoded
            }
        }
        return nil
    }

    /// Hex / binary / octal literals and base conversions:
    /// "0x1" → "1", "0b101" → "5", "255 to hex" → "0xFF", "0xff to binary" → "0b11111111".
    private static func numberBase(_ text: String) -> String? {
        var words = text.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }
        if words.count == 2, ["hex", "dec", "decimal", "bin", "binary", "oct", "octal"].contains(words[0]) {
            // Prefix forms: "hex 0xFF" decodes, "decimal 255" encodes to hex, "binary 5" encodes to binary.
            let target = words[0]
            let value = words[1]
            if target == "hex" { return integer(value, allowPlainDecimal: false).map { "\($0)" } ?? integer("0x" + value, allowPlainDecimal: false).map { "\($0)" } }
            guard let number = integer(value, allowPlainDecimal: true) else { return nil }
            return encode(number, as: target == "dec" || target == "decimal" ? "hex" : target)
        }
        if words.count == 3, connectors.contains(words[1]), ["hex", "hexadecimal", "dec", "decimal", "bin", "binary", "oct", "octal"].contains(words[2]),
           let number = integer(words[0], allowPlainDecimal: true) {
            return encode(number, as: words[2])
        }
        guard words.count == 1 else { return nil }
        let literal = words.removeFirst()
        guard literal.hasPrefix("0x") || literal.hasPrefix("0b") || literal.hasPrefix("0o") else { return nil }
        return integer(literal, allowPlainDecimal: false).map { "\($0)" }
    }

    private static func integer(_ text: String, allowPlainDecimal: Bool) -> Int64? {
        let negative = text.hasPrefix("-")
        let body = negative ? String(text.dropFirst()) : text
        let value: Int64?
        if body.count > 2, body.hasPrefix("0x") { value = Int64(body.dropFirst(2).replacingOccurrences(of: "_", with: ""), radix: 16) }
        else if body.count > 2, body.hasPrefix("0b") { value = Int64(body.dropFirst(2).replacingOccurrences(of: "_", with: ""), radix: 2) }
        else if body.count > 2, body.hasPrefix("0o") { value = Int64(body.dropFirst(2).replacingOccurrences(of: "_", with: ""), radix: 8) }
        else if allowPlainDecimal { value = Int64(body.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "_", with: "")) }
        else { value = nil }
        guard let value else { return nil }
        return negative ? -value : value
    }

    private static func encode(_ value: Int64, as base: String) -> String {
        let sign = value < 0 ? "-" : ""
        let magnitude = value.magnitude
        switch base {
        case "hex", "hexadecimal": return sign + "0x" + String(magnitude, radix: 16).uppercased()
        case "bin", "binary": return sign + "0b" + String(magnitude, radix: 2)
        case "oct", "octal": return sign + "0o" + String(magnitude, radix: 8)
        default: return "\(value)"
        }
    }

    static func needsRate(_ request: Request) -> Bool {
        request.source != request.destination && isCurrency(request.source) && isCurrency(request.destination)
    }

    static func rate(_ request: Request) async throws -> String {
        let source = request.source
        let destination = request.destination
        let value: Double
        if cryptoIDs[source] != nil || cryptoIDs[destination] != nil {
            // Price both sides in USD (or the fiat side's currency) and take the ratio.
            let quote = fiat.contains(source) ? source : fiat.contains(destination) ? destination : "USD"
            let ids = [source, destination].compactMap { cryptoIDs[$0] }
            guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids.joined(separator: ","))&vs_currencies=\(quote.lowercased())") else {
                throw ConversionError.unavailable
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let prices = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            func price(_ code: String) throws -> Double {
                if code == quote { return 1 }
                guard let id = cryptoIDs[code], let price = prices[id]?[quote.lowercased()], price > 0 else {
                    throw ConversionError.unavailable
                }
                return price
            }
            value = request.amount * (try price(source)) / (try price(destination))
        } else {
            guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=\(source)&symbols=\(destination)") else {
                throw ConversionError.unavailable
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(FiatResponse.self, from: data)
            guard let price = response.rates[destination] else { throw ConversionError.unavailable }
            value = request.amount * price
        }
        guard value.isFinite else { throw ConversionError.unavailable }
        return "\(formatMoney(value, code: destination)) \(destination)"
    }

    private static func temperature(_ request: Request) -> String? {
        guard let source = temperatures[request.source.lowercased()],
              let destination = temperatures[request.destination.lowercased()] else { return nil }
        let celsius = source == "F" ? (request.amount - 32) * 5 / 9 :
            source == "K" ? request.amount - 273.15 : request.amount
        let result = destination == "F" ? celsius * 9 / 5 + 32 :
            destination == "K" ? celsius + 273.15 : celsius
        return "\(format(result)) \(destination == "K" ? "K" : "°" + destination)"
    }

    private static func format(_ value: Double) -> String {
        let clean = value.magnitude < 1e-12 ? 0 : value
        return clean.formatted(.number.precision(.significantDigits(1...8)))
    }

    private static func formatMoney(_ value: Double, code: String) -> String {
        if fiat.contains(code), value.magnitude >= 1 {
            return value.formatted(.number.precision(.fractionLength(2)))
        }
        return format(value)
    }

    private struct FiatResponse: Decodable { let rates: [String: Double] }
    enum ConversionError: Error { case unavailable }
}
