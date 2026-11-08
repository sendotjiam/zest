import Foundation

public enum TransformCategory: String, CaseIterable, Sendable {
    case json = "JSON"
    case textCase = "Case"
    case encoding = "Encoding"
    case clean = "Clean"
}

public struct TransformAction: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: TransformCategory
    public let shortcutHint: String?
    public let execute: @Sendable (String) -> String?

    public init(
        id: String,
        name: String,
        category: TransformCategory,
        shortcutHint: String? = nil,
        execute: @escaping @Sendable (String) -> String?
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.shortcutHint = shortcutHint
        self.execute = execute
    }
}

public struct DataTransformer: Sendable {
    public static let availableActions: [TransformAction] = [
        // JSON
        TransformAction(id: "json.prettify", name: "Prettify JSON", category: .json, shortcutHint: "⌘J") { str in
            prettifyJSON(str)
        },
        TransformAction(id: "json.minify", name: "Minify JSON", category: .json, shortcutHint: "⇧⌘J") { str in
            minifyJSON(str)
        },
        TransformAction(id: "json.escape", name: "Escape for String", category: .json) { str in
            escapeForStringLiteral(str)
        },

        // Case
        TransformAction(id: "case.camel", name: "camelCase", category: .textCase, shortcutHint: "⌥C") { str in
            toCamelCase(str)
        },
        TransformAction(id: "case.snake", name: "snake_case", category: .textCase, shortcutHint: "⌥S") { str in
            toSnakeCase(str)
        },
        TransformAction(id: "case.kebab", name: "kebab-case", category: .textCase, shortcutHint: "⌥K") { str in
            toKebabCase(str)
        },
        TransformAction(id: "case.pascal", name: "PascalCase", category: .textCase) { str in
            toPascalCase(str)
        },
        TransformAction(id: "case.constant", name: "CONSTANT_CASE", category: .textCase) { str in
            toConstantCase(str)
        },

        // Encoding
        TransformAction(id: "enc.b64decode", name: "Base64 Decode", category: .encoding, shortcutHint: "⌘D") { str in
            base64Decode(str)
        },
        TransformAction(id: "enc.b64encode", name: "Base64 Encode", category: .encoding) { str in
            base64Encode(str)
        },
        TransformAction(id: "enc.urldecode", name: "URL Decode", category: .encoding) { str in
            urlDecode(str)
        },
        TransformAction(id: "enc.urlencode", name: "URL Encode", category: .encoding) { str in
            urlEncode(str)
        },
        TransformAction(id: "enc.jwt", name: "Decode JWT Payload", category: .encoding) { str in
            decodeJWTPayload(str)
        },

        // Clean
        TransformAction(id: "clean.stripMarkdown", name: "Strip Markdown", category: .clean, shortcutHint: "⌘M") { str in
            stripMarkdown(str)
        },
        TransformAction(id: "clean.stripHTML", name: "Strip HTML Tags", category: .clean) { str in
            stripHTML(str)
        },
        TransformAction(id: "clean.collapseWhitespace", name: "Single Line / Collapse", category: .clean) { str in
            collapseWhitespace(str)
        },
        TransformAction(id: "clean.sortUniqueLines", name: "Sort & Dedupe Lines", category: .clean) { str in
            sortAndDedupeLines(str)
        },
        TransformAction(id: "clean.shellEscape", name: "Shell Escape for Bash", category: .clean) { str in
            shellEscape(str)
        }
    ]

    // MARK: - JSON Transformations

    public static func prettifyJSON(_ input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return result
    }

    public static func minifyJSON(_ input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let minData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let result = String(data: minData, encoding: .utf8) else {
            return nil
        }
        return result
    }

    public static func escapeForStringLiteral(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    // MARK: - Case Conversions

    private static func tokenizeWords(_ input: String) -> [String] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        var words: [String] = []
        var current = ""
        let chars = Array(trimmed)

        for i in 0..<chars.count {
            let char = chars[i]
            if char == "_" || char == "-" || char == " " || char == "." || char == "/" || char == ":" {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
            } else if char.isUppercase {
                let nextIsLower = (i + 1 < chars.count) && chars[i + 1].isLowercase
                let hasLower = current.contains { $0.isLowercase }

                if !current.isEmpty && (hasLower || nextIsLower) {
                    words.append(current)
                    current = ""
                }
                current.append(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words.map { $0.lowercased() }
    }

    public static func toCamelCase(_ input: String) -> String {
        let words = tokenizeWords(input)
        guard let first = words.first else { return input }
        let rest = words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return ([first] + rest).joined()
    }

    public static func toPascalCase(_ input: String) -> String {
        let words = tokenizeWords(input)
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    public static func toSnakeCase(_ input: String) -> String {
        return tokenizeWords(input).joined(separator: "_")
    }

    public static func toKebabCase(_ input: String) -> String {
        return tokenizeWords(input).joined(separator: "-")
    }

    public static func toConstantCase(_ input: String) -> String {
        return tokenizeWords(input).map { $0.uppercased() }.joined(separator: "_")
    }

    // MARK: - Encodings

    public static func base64Encode(_ input: String) -> String {
        return Data(input.utf8).base64EncodedString()
    }

    public static func base64Decode(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var padded = trimmed.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let rem = padded.count % 4
        if rem > 0 { padded.append(String(repeating: "=", count: 4 - rem)) }
        guard let data = Data(base64Encoded: padded),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        return decoded
    }

    public static func urlEncode(_ input: String) -> String {
        return input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
    }

    public static func urlDecode(_ input: String) -> String? {
        return input.removingPercentEncoding
    }

    public static func decodeJWTPayload(_ input: String) -> String? {
        let parts = input.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ".")
        guard parts.count >= 2, let payload = base64Decode(parts[1]) else { return nil }
        return prettifyJSON(payload) ?? payload
    }

    // MARK: - Cleaning & Formatting

    public static func stripFormatting(_ input: String) -> String {
        let noHTML = stripHTML(input)
        return stripMarkdown(noHTML)
    }

    public static func stripMarkdown(_ input: String) -> String {
        var str = input
        // Remove bold / italics without breaking math like x * y * z
        str = str.replacingOccurrences(of: "\\*\\*(.*?)\\*\\*", with: "$1", options: .regularExpression)
        str = str.replacingOccurrences(of: "__(.*?)__", with: "$1", options: .regularExpression)
        str = str.replacingOccurrences(of: "(?<!\\w)\\*([^\\*\\s](?:.*?)[^\\*\\s]?)\\*(?!\\w)", with: "$1", options: .regularExpression)
        str = str.replacingOccurrences(of: "(?<!\\w)_([^\\_\\s](?:.*?)[^\\_\\s]?)_(?!\\w)", with: "$1", options: .regularExpression)
        // Remove code spans
        str = str.replacingOccurrences(of: "`+(.*?)`+", with: "$1", options: .regularExpression)
        // Remove links [text](url) -> text
        str = str.replacingOccurrences(of: "\\[(.*?)\\]\\(.*?\\)", with: "$1", options: .regularExpression)
        // Remove headers across all lines (multiline enabled)
        str = str.replacingOccurrences(of: "(?m)^#{1,6}\\s+", with: "", options: .regularExpression)
        return str
    }

    public static func stripHTML(_ input: String) -> String {
        return input.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    public static func collapseWhitespace(_ input: String) -> String {
        let singleLine = input.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return singleLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func sortAndDedupeLines(_ input: String) -> String {
        let lines = input.components(separatedBy: "\n")
        let nonBlank = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let deduped = Array(Set(nonBlank)).sorted()
        return deduped.joined(separator: "\n")
    }

    public static func shellEscape(_ input: String) -> String {
        // Enclose in single quotes and escape any single quotes: ' -> '\''
        let escaped = input.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    public static func imageBase64DataURI(pngData: Data) -> String {
        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }
}
