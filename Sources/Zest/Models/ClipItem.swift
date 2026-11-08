import Foundation
import AppKit

public enum DetectedContentType: String, CaseIterable, Sendable, Codable {
    case json = "JSON"
    case sql = "SQL"
    case url = "URL"
    case color = "HEX"
    case jwt = "JWT"
    case python = "PY"
    case typescript = "TS"
    case golang = "GO"
    case rust = "RS"
    case html = "HTML"
    case yaml = "YAML"
    case code = "CODE"
    case text = "TXT"
    case image = "IMG"

    public var badgeColorHex: String {
        switch self {
        case .json: return "#EAB308"
        case .sql: return "#06B6D4"
        case .url: return "#3B82F6"
        case .color: return "#EC4899"
        case .jwt: return "#8B5CF6"
        case .python: return "#38BDF8"
        case .typescript: return "#3B82F6"
        case .golang: return "#00ADD8"
        case .rust: return "#F97316"
        case .html: return "#EF4444"
        case .yaml: return "#A855F7"
        case .code: return "#10B981"
        case .text: return "#6B7280"
        case .image: return "#6366F1"
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

public extension DetectedContentType {
    var systemColor: Color {
        switch self {
        case .json: return .orange
        case .sql: return .teal
        case .url: return .blue
        case .color: return .pink
        case .jwt: return .purple
        case .python: return .cyan
        case .typescript: return .blue
        case .golang: return .teal
        case .rust: return .orange
        case .html: return .red
        case .yaml: return .purple
        case .code: return .green
        case .text: return .secondary
        case .image: return .indigo
        }
    }
}
#endif


public struct ClipItem: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public var rawContent: String
    public var imageData: Data?
    public var imageWidth: Int?
    public var imageHeight: Int?
    public var sourceApp: String?
    public var firstCopiedAt: Date
    public var lastCopiedAt: Date
    public var copyCount: Int
    public var isPinned: Bool
    public var detectedType: DetectedContentType

    public init(
        id: UUID = UUID(),
        rawContent: String,
        imageData: Data? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        sourceApp: String? = nil,
        firstCopiedAt: Date = Date(),
        lastCopiedAt: Date = Date(),
        copyCount: Int = 1,
        isPinned: Bool = false,
        detectedType: DetectedContentType? = nil
    ) {
        self.id = id
        self.rawContent = rawContent
        self.imageData = imageData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.sourceApp = sourceApp
        self.firstCopiedAt = firstCopiedAt
        self.lastCopiedAt = lastCopiedAt
        self.copyCount = copyCount
        self.isPinned = isPinned
        self.detectedType = detectedType ?? (imageData != nil ? .image : Self.detectType(for: rawContent))
    }

    public var isImage: Bool {
        detectedType == .image && imageData != nil
    }

    public var displayTitle: String {
        if isImage {
            if let w = imageWidth, let h = imageHeight {
                return "Image (\(w) × \(h))"
            }
            return "Image"
        }
        let trimmed = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "«Empty»" }
        let singleLine = trimmed.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count > 75 {
            return String(singleLine.prefix(75)) + "…"
        }
        return singleLine
    }

    public var formattedFileSize: String? {
        guard let data = imageData else { return nil }
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useBytes, .useKB, .useMB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(data.count))
    }

    public var lineCount: Int {
        if isImage { return 0 }
        return rawContent.components(separatedBy: "\n").count
    }

    public var characterCount: Int {
        rawContent.count
    }

    public static func detectType(for string: String) -> DetectedContentType {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. JSON Detection
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if let data = trimmed.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data, options: [])) != nil {
                return .json
            }
        }

        // 2. JWT Detection (3 base64 strings joined by '.')
        let jwtParts = trimmed.components(separatedBy: ".")
        if jwtParts.count == 3,
           jwtParts[0].count > 10,
           jwtParts[1].count > 10,
           Data(base64Encoded: paddedBase64(jwtParts[0])) != nil {
            return .jwt
        }

        // 3. Hex Color Detection (#RGB, #RRGGBB, #RRGGBBAA)
        if trimmed.hasPrefix("#") && (trimmed.count == 4 || trimmed.count == 7 || trimmed.count == 9) {
            let hexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            let stripped = trimmed.dropFirst()
            if CharacterSet(charactersIn: String(stripped)).isSubset(of: hexChars) {
                return .color
            }
        }

        // 4. URL Detection
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("ftp://") {
            if URL(string: trimmed) != nil {
                return .url
            }
        }

        // 5. SQL Detection
        let upper = trimmed.uppercased()
        let sqlKeywords = ["SELECT ", "INSERT INTO ", "UPDATE ", "DELETE FROM ", "CREATE TABLE ", "ALTER TABLE ", "DROP TABLE "]
        if sqlKeywords.contains(where: { upper.hasPrefix($0) }) {
            return .sql
        }

        // 6. HTML Detection
        if trimmed.hasPrefix("<!DOCTYPE html") ||
           trimmed.hasPrefix("<html") ||
           (trimmed.contains("<div") && trimmed.contains("</div>")) ||
           (trimmed.contains("<p>") && trimmed.contains("</p>")) {
            return .html
        }

        // 7. Rust Detection
        if (trimmed.contains("fn ") || trimmed.contains("pub fn ")) &&
           (trimmed.contains("let mut ") || trimmed.contains("impl ") || trimmed.contains("println!(") || trimmed.contains("Result<")) {
            return .rust
        }

        // 8. Go Detection
        if (trimmed.contains("package main") || trimmed.contains("func main()")) ||
           (trimmed.contains("func ") && (trimmed.contains("fmt.Print") || trimmed.contains(":= ") || trimmed.contains("chan "))) {
            return .golang
        }

        // 9. Python Detection
        if (trimmed.contains("def ") || trimmed.contains("elif ") || trimmed.contains("import os") || trimmed.contains("import sys") || trimmed.contains("if __name__ == '__main__':")) &&
           (trimmed.contains(":\n") || trimmed.hasSuffix(":") || trimmed.contains("print(")) {
            return .python
        }

        // 10. TypeScript / JavaScript Detection
        if trimmed.contains("interface ") ||
           trimmed.contains("export default ") ||
           trimmed.contains("export const ") ||
           (trimmed.contains(": string") || trimmed.contains(": number") || trimmed.contains(": boolean")) ||
           (trimmed.contains("console.log(") && (trimmed.contains("const ") || trimmed.contains("let ") || trimmed.contains("function "))) ||
           ((trimmed.contains("const ") || trimmed.contains("let ")) && (trimmed.contains("=>") || trimmed.contains("require("))) {
            return .typescript
        }

        // 11. YAML Detection
        if trimmed.hasPrefix("---\n") ||
           (trimmed.contains("version:") && trimmed.contains("services:")) ||
           (trimmed.contains("name:") && trimmed.contains("on:") && trimmed.contains("jobs:")) {
            return .yaml
        }

        // 12. Generic Code Detection (braces, semicolons, common programming constructs)
        if (trimmed.contains("func ") || trimmed.contains("def ") || trimmed.contains("function ") ||
            trimmed.contains("const ") || trimmed.contains("import ") || trimmed.contains("class ")) &&
           (trimmed.contains("{") || trimmed.contains(":") || trimmed.contains(";")) {
            return .code
        }

        return .text
    }

    private static func paddedBase64(_ base64: String) -> String {
        var str = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = str.count % 4
        if remainder > 0 {
            str.append(String(repeating: "=", count: 4 - remainder))
        }
        return str
    }
}

public extension NSPasteboard.PasteboardType {
    // Standard concealed & transient markers
    static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    static let autoGenerated = NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
    
    // Zest internal marker
    static let fromZest = NSPasteboard.PasteboardType("app.zest.clipboard.marker")
}
