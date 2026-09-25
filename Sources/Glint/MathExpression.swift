import Foundation

enum MathExpression {
    static func result(for input: String) -> String? {
        var parser = Parser(bytes: Array(input.utf8))
        guard let value = parser.evaluate() else { return nil }
        return (value == 0 ? 0 : value).formatted(.number.precision(.significantDigits(1...12)))
    }

    private struct Parser {
        let bytes: [UInt8]
        var position = 0
        var hasOperation = false

        private var current: UInt8? { position < bytes.count ? bytes[position] : nil }

        mutating func evaluate() -> Double? {
            guard !bytes.isEmpty, bytes.count <= 512, let value = expression(depth: 0) else { return nil }
            skipSpaces()
            return position == bytes.count && hasOperation && value.isFinite ? value : nil
        }

        private mutating func expression(depth: Int) -> Double? {
            guard depth < 64, var value = term(depth: depth + 1) else { return nil }
            while true {
                skipSpaces()
                guard let operation = current, operation == 43 || operation == 45 else { break }
                position += 1
                guard let right = term(depth: depth + 1) else { return nil }
                value = operation == 43 ? value + right : value - right
                guard value.isFinite else { return nil }
                hasOperation = true
            }
            return value
        }

        private mutating func term(depth: Int) -> Double? {
            guard depth < 64, var value = unary(depth: depth + 1) else { return nil }
            while true {
                skipSpaces()
                guard let operation = current, operation == 42 || operation == 47 || operation == 37 else { break }
                position += 1
                guard let right = unary(depth: depth + 1), operation == 42 || right != 0 else { return nil }
                switch operation {
                case 42: value *= right
                case 47: value /= right
                default: value = value.truncatingRemainder(dividingBy: right)
                }
                guard value.isFinite else { return nil }
                hasOperation = true
            }
            return value
        }

        private mutating func unary(depth: Int) -> Double? {
            guard depth < 64 else { return nil }
            skipSpaces()
            if current == 43 || current == 45 {
                let negate = current == 45
                position += 1
                guard let value = unary(depth: depth + 1) else { return nil }
                return negate ? -value : value
            }
            return primary(depth: depth + 1)
        }

        private mutating func primary(depth: Int) -> Double? {
            guard depth < 64 else { return nil }
            skipSpaces()
            if current == 40 {
                position += 1
                guard let value = expression(depth: depth + 1) else { return nil }
                skipSpaces()
                guard current == 41 else { return nil }
                position += 1
                return value
            }
            let start = position
            var digits = 0
            while let byte = current, (48...57).contains(byte) { position += 1; digits += 1 }
            if current == 46 {
                position += 1
                while let byte = current, (48...57).contains(byte) { position += 1; digits += 1 }
            }
            guard digits > 0 else { return nil }
            if current == 69 || current == 101 {
                position += 1
                if current == 43 || current == 45 { position += 1 }
                let exponentStart = position
                while let byte = current, (48...57).contains(byte) { position += 1 }
                guard position > exponentStart else { return nil }
            }
            let literal = String(decoding: bytes[start..<position], as: UTF8.self)
            guard let value = Double(literal), value.isFinite else { return nil }
            return value
        }

        private mutating func skipSpaces() {
            while let byte = current, byte == 32 || byte == 9 || byte == 10 || byte == 13 { position += 1 }
        }
    }
}
