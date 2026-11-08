import Foundation

@MainActor
public final class HistoryStorageManager {
    public static let shared = HistoryStorageManager()

    public static let persistenceKey = "zest_persistenceEnabled"
    public static let maxHistoryKey = "zest_maxHistoryLimit"

    private let fileManager = FileManager.default
    private let directoryURL: URL
    private let fileURL: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let zestDir = appSupport.appendingPathComponent("Zest", isDirectory: true)

        self.directoryURL = zestDir
        self.fileURL = directoryURL.appendingPathComponent("history.json")

        // Register default preference values
        UserDefaults.standard.register(defaults: [
            "zest_autoPasteKeystroke": true,
            Self.persistenceKey: true,
            Self.maxHistoryKey: 100
        ])
    }

    public var isPersistenceEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.persistenceKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.persistenceKey)
            if !newValue {
                clearDiskCache()
            }
        }
    }

    public var maxHistoryLimit: Int {
        get {
            let limit = UserDefaults.standard.integer(forKey: Self.maxHistoryKey)
            return limit > 0 ? limit : 100
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.maxHistoryKey)
        }
    }

    public func save(items: [ClipItem]) {
        guard isPersistenceEnabled else {
            clearDiskCache()
            return
        }

        do {
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let limit = maxHistoryLimit
            let itemsToSave = Array(items.prefix(limit)).map { item -> ClipItem in
                var sanitized = item
                // Safeguard: Drop bulky raw image payloads > 2MB when writing to disk
                if let data = sanitized.imageData, data.count > 2 * 1024 * 1024 {
                    sanitized.imageData = nil
                }
                return sanitized
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(itemsToSave)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("⚠️ [HistoryStorageManager] Failed to save history to disk: \(error)")
        }
    }

    public func load() -> [ClipItem] {
        guard isPersistenceEnabled else {
            return []
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let items = try decoder.decode([ClipItem].self, from: data)
            return items
        } catch {
            print("⚠️ [HistoryStorageManager] Failed to load history: \(error). Resetting cache.")
            clearDiskCache()
            return []
        }
    }

    public func clearDiskCache() {
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
