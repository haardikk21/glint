import Foundation

enum Blockchain {
    struct Destination: Equatable {
        let title: String
        let url: URL
    }

    static func destinations(for input: String) -> [Destination] {
        let hash = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hash.count == 66, hash.hasPrefix("0x"),
              hash.dropFirst(2).allSatisfy(\.isHexDigit) else { return [] }
        return [
            Destination(title: "Transaction on BaseScan", url: URL(string: "https://basescan.org/tx/\(hash)")!),
            Destination(title: "Transaction on Base Sepolia", url: URL(string: "https://sepolia.basescan.org/tx/\(hash)")!),
            Destination(title: "Block on BaseScan", url: URL(string: "https://basescan.org/block/\(hash)")!),
            Destination(title: "Block on Base Sepolia", url: URL(string: "https://sepolia.basescan.org/block/\(hash)")!)
        ]
    }
}
