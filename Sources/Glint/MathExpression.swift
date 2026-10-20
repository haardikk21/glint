import Foundation

enum MathExpression {
    static func result(for input: String) -> String? {
        let normalized = input.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "**", with: "^")
        var parser = Parser(bytes: Array(normalized.utf8))
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
            return power(depth: depth + 1)
        }

        /// Right-associative exponent; binds tighter than unary minus so -2^2 = -4.
        private mutating func power(depth: Int) -> Double? {
            guard depth < 64, let base = primary(depth: depth + 1) else { return nil }
            skipSpaces()
            guard current == 94 else { return base }
            position += 1
            guard let exponent = unary(depth: depth + 1) else { return nil }
            hasOperation = true
            let value = Foundation.pow(base, exponent)
            return value.isFinite ? value : nil
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
            if current == 48, position + 2 < bytes.count, let radix = Self.radix(bytes[position + 1]) {
                let start = position + 2
                var end = start
                while end < bytes.count, Self.isDigit(bytes[end], radix: radix) || bytes[end] == 95 { end += 1 }
                let literal = String(decoding: bytes[start..<end], as: UTF8.self).replacingOccurrences(of: "_", with: "")
                guard end > start, let value = UInt64(literal, radix: radix) else { return nil }
                position = end
                return Double(value)
            }
            var literal = ""
            var digits = 0
            func integerDigits(_ parser: inout Parser) {
                while let byte = parser.current, (48...57).contains(byte) {
                    literal.append(Character(UnicodeScalar(byte))); parser.position += 1; digits += 1
                }
            }
            integerDigits(&self)
            // Thousands separators: accept "1,000" / "12,345,678" (comma followed by exactly three digits).
            while digits > 0, current == 44, isThousandsGroup(at: position + 1) {
                position += 1
                integerDigits(&self)
            }
            if current == 46 {
                literal.append("."); position += 1
                integerDigits(&self)
            }
            guard digits > 0 else { return nil }
            if current == 69 || current == 101 {
                literal.append("e"); position += 1
                if let sign = current, sign == 43 || sign == 45 { literal.append(Character(UnicodeScalar(sign))); position += 1 }
                let exponentStart = position
                while let byte = current, (48...57).contains(byte) { literal.append(Character(UnicodeScalar(byte))); position += 1 }
                guard position > exponentStart else { return nil }
            }
            guard let value = Double(literal), value.isFinite else { return nil }
            return value
        }

        private func isThousandsGroup(at index: Int) -> Bool {
            guard index + 3 <= bytes.count,
                  bytes[index..<index + 3].allSatisfy({ (48...57).contains($0) }) else { return false }
            return index + 3 == bytes.count || !(48...57).contains(bytes[index + 3])
        }

        private static func radix(_ byte: UInt8) -> Int? {
            switch byte {
            case 120, 88: return 16 // x
            case 98, 66: return 2   // b
            case 111, 79: return 8  // o
            default: return nil
            }
        }

        private static func isDigit(_ byte: UInt8, radix: Int) -> Bool {
            switch radix {
            case 16: return (48...57).contains(byte) || (97...102).contains(byte) || (65...70).contains(byte)
            case 8: return (48...55).contains(byte)
            default: return byte == 48 || byte == 49
            }
        }

        private mutating func skipSpaces() {
            while let byte = current, byte == 32 || byte == 9 || byte == 10 || byte == 13 { position += 1 }
        }
    }
}
