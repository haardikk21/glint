import Foundation

@main struct RateChecks {
    static func main() async throws {
        let fiat = try await Conversion.rate(Conversion.parse("5 USD to CAD")!)
        let crypto = try await Conversion.rate(Conversion.parse("234 ETH to USD")!)
        guard fiat.hasSuffix(" CAD"), crypto.hasSuffix(" USD") else { exit(1) }
        print("Live rates: \(fiat); \(crypto)")
    }
}
