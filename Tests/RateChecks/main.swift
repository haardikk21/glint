import Foundation

@main struct RateChecks {
    static func main() async throws {
        let pair = try await Conversion.rate(Conversion.parse("USD to CAD")!)
        let fiat = try await Conversion.rate(Conversion.parse("5 USD to CAD")!)
        let crypto = try await Conversion.rate(Conversion.parse("234 ETH to USD")!)
        guard pair.hasSuffix(" CAD"), fiat.hasSuffix(" CAD"), crypto.hasSuffix(" USD") else { exit(1) }
        print("Live rates: 1 USD = \(pair); 5 USD = \(fiat); 234 ETH = \(crypto)")
    }
}
