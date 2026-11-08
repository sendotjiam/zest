import Foundation
import SwiftUI

@MainActor
public final class ZestState: ObservableObject {
    public static let shared = ZestState()

    @Published public var searchText: String = "" {
        didSet {
            highlightedIndex = 0
        }
    }
    @Published public var highlightedIndex: Int = 0
    @Published public var selectedItem: ClipItem?
    @Published public var previewItem: ClipItem?
    @Published public var activeTransform: TransformAction?
    @Published public var transformedPreview: String?
    @Published public var selectedCategory: TransformCategory?
    @Published public var confirmingClearAll: Bool = false

    public var currentHighlightedItem: ClipItem? {
        let items = filteredItems
        guard !items.isEmpty else { return nil }
        let idx = max(0, min(highlightedIndex, items.count - 1))
        return items[idx]
    }

    public var filteredItems: [ClipItem] {
        let items = ClipboardEngine.shared.items
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return Array(items.prefix(10))
        }

        let scoredItems: [(item: ClipItem, score: Int)] = items.compactMap { item in
            // Check image keyword search
            if item.isImage {
                if query.localizedCaseInsensitiveCompare("image") == .orderedSame ||
                   query.localizedCaseInsensitiveCompare("img") == .orderedSame {
                    return (item, 100)
                }
            }

            // Check source app match
            var appScore = 0
            if let app = item.sourceApp {
                let match = FuzzyMatcher.match(query: query, in: app)
                if match.matched {
                    appScore = match.score + 10
                }
            }

            // Check type badge match (e.g. typing "json", "sql", "py")
            var typeScore = 0
            let typeMatch = FuzzyMatcher.match(query: query, in: item.detectedType.rawValue)
            if typeMatch.matched {
                typeScore = typeMatch.score + 15
            }

            // Check content match
            let contentMatch = FuzzyMatcher.match(query: query, in: item.rawContent)
            
            let maxScore = max(contentMatch.matched ? contentMatch.score : 0, appScore, typeScore)
            if maxScore > 0 {
                return (item, maxScore)
            }
            return nil
        }

        // Sort descending by match score, preserving recency for equal scores
        return scoredItems
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { $0.item }
    }

    public func resetTransform() {
        selectedItem = nil
        activeTransform = nil
        transformedPreview = nil
        selectedCategory = nil
    }

    public func resetAll() {
        searchText = ""
        highlightedIndex = 0
        confirmingClearAll = false
        previewItem = nil
        resetTransform()
    }
}
