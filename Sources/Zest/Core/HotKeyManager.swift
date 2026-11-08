import Foundation
import Carbon
import AppKit

public final class HotKeyManager: @unchecked Sendable {
    private struct HotKeyEntry {
        let ownerID: ObjectIdentifier
        let action: @MainActor () -> Void
    }

    private static var isHandlerInstalled = false
    private static var globalEventHandler: EventHandlerRef?
    private static var registry: [UInt32: HotKeyEntry] = [:]
    private static let lock = NSLock()

    private var hotKeyRef: EventHotKeyRef?
    public let hotKeyID: UInt32

    public init(
        keyCode: UInt32 = 9, // 'v'
        modifiers: UInt32 = UInt32(cmdKey | shiftKey), // ⌘ + ⇧
        id: UInt32 = 1,
        onTrigger: @escaping @MainActor () -> Void
    ) {
        self.hotKeyID = id
        register(keyCode: keyCode, modifiers: modifiers, onTrigger: onTrigger)
    }

    deinit {
        unregister()
    }

    private static func ensureGlobalHandlerInstalled() {
        guard !isHandlerInstalled else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, inEvent, _ in
            guard let inEvent = inEvent else { return OSStatus(eventNotHandledErr) }

            var eventHotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                inEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &eventHotKeyID
            )

            if status == noErr {
                HotKeyManager.lock.lock()
                let entry = HotKeyManager.registry[eventHotKeyID.id]
                HotKeyManager.lock.unlock()

                if let entry = entry {
                    DispatchQueue.main.async {
                        entry.action()
                    }
                    return noErr
                }
            }

            return OSStatus(eventNotHandledErr)
        }

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            handler,
            1,
            &eventType,
            nil,
            &globalEventHandler
        )

        if status == noErr {
            isHandlerInstalled = true
        }
    }

    private func register(keyCode: UInt32, modifiers: UInt32, onTrigger: @escaping @MainActor () -> Void) {
        HotKeyManager.lock.lock()
        HotKeyManager.registry[hotKeyID] = HotKeyEntry(ownerID: ObjectIdentifier(self), action: onTrigger)
        HotKeyManager.ensureGlobalHandlerInstalled()
        HotKeyManager.lock.unlock()

        // HotKey signature "ZEST" (0x5A455354)
        let hotKeyIDStruct = EventHotKeyID(signature: OSType(0x5A455354), id: hotKeyID)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyIDStruct,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("⚠️ [HotKeyManager] Failed to register hotkey id \(hotKeyID) with code \(keyCode): OSStatus \(status)")
        }
    }

    public func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        HotKeyManager.lock.lock()
        if HotKeyManager.registry[hotKeyID]?.ownerID == ObjectIdentifier(self) {
            HotKeyManager.registry.removeValue(forKey: hotKeyID)
        }
        HotKeyManager.lock.unlock()
    }
}

public extension Notification.Name {
    static let shortcutsDidChange = Notification.Name("app.zest.shortcutsDidChange")
}

public struct KeyCombo: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var displayString: String

    public init(keyCode: UInt32, modifiers: UInt32, displayString: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayString = displayString
    }

    public static let defaultActivation = KeyCombo(
        keyCode: 9, // 'v'
        modifiers: UInt32(cmdKey | shiftKey),
        displayString: "⌘ + ⇧ + V"
    )

    public static let defaultOCR = KeyCombo(
        keyCode: 19, // '2'
        modifiers: UInt32(cmdKey | shiftKey),
        displayString: "⌘ + ⇧ + 2"
    )

    public static let activationKey = "zest_customActivationShortcut"
    public static let ocrKey = "zest_customOCRShortcut"

    public static func load(forKey key: String, default defaultCombo: KeyCombo) -> KeyCombo {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            return decoded
        }
        return defaultCombo
    }

    public func save(forKey key: String) {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

public enum KeyCodeHelper {
    public static func string(for keyCode: UInt16, characters: String?) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            if let chars = characters?.uppercased(), !chars.isEmpty, chars.unicodeScalars.first?.isASCII == true {
                return chars
            }
            return fallback(for: keyCode)
        }
    }

    private static func fallback(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 50: return "`"
        default: return "Key \(keyCode)"
        }
    }
}

public enum ShortcutConflictLevel: Equatable, Sendable {
    case blocked(reason: String)
    case warning(reason: String)
}

public enum ShortcutConflictChecker {
    public static func check(combo: KeyCombo, storageKey: String) -> ShortcutConflictLevel? {
        // 1. Check internal conflicts with the other Zest feature
        if storageKey == KeyCombo.activationKey {
            let ocr = KeyCombo.load(forKey: KeyCombo.ocrKey, default: .defaultOCR)
            if combo.keyCode == ocr.keyCode && combo.modifiers == ocr.modifiers {
                return .blocked(reason: "Already assigned to Screen OCR")
            }
        } else if storageKey == KeyCombo.ocrKey {
            let act = KeyCombo.load(forKey: KeyCombo.activationKey, default: .defaultActivation)
            if combo.keyCode == act.keyCode && combo.modifiers == act.modifiers {
                return .blocked(reason: "Already assigned to Activation Shortcut")
            }
        }

        let cmd = UInt32(cmdKey)
        let shift = UInt32(shiftKey)
        let opt = UInt32(optionKey)
        let ctrl = UInt32(controlKey)

        // 2. Block system-critical standard shortcuts
        if combo.modifiers == cmd {
            switch combo.keyCode {
            case 8: return .blocked(reason: "Reserved for Copy (⌘C)")
            case 9: return .blocked(reason: "Reserved for Paste (⌘V)")
            case 7: return .blocked(reason: "Reserved for Cut (⌘X)")
            case 6: return .blocked(reason: "Reserved for Undo (⌘Z)")
            case 0: return .blocked(reason: "Reserved for Select All (⌘A)")
            case 1: return .blocked(reason: "Reserved for Save (⌘S)")
            case 12: return .blocked(reason: "Reserved for Quit App (⌘Q)")
            case 13: return .blocked(reason: "Reserved for Close Window (⌘W)")
            case 48: return .blocked(reason: "Reserved for App Switcher (⌘Tab)")
            default: break
            }
        }

        if combo.modifiers == (opt | cmd) && combo.keyCode == 53 {
            return .blocked(reason: "Reserved for Force Quit (⌥⌘⎋)")
        }

        // 3. Known system & Finder hotkey warnings
        if combo.modifiers == cmd && combo.keyCode == 49 {
            return .warning(reason: "Conflicts with Spotlight Search (⌘Space)")
        }
        if combo.modifiers == (opt | cmd) && combo.keyCode == 49 {
            return .warning(reason: "Conflicts with Finder Spotlight (⌥⌘Space)")
        }
        if combo.modifiers == (cmd | shift) {
            switch combo.keyCode {
            case 20: return .warning(reason: "Conflicts with macOS Screenshot (⌘⇧3)")
            case 21: return .warning(reason: "Conflicts with macOS Area Capture (⌘⇧4)")
            case 23: return .warning(reason: "Conflicts with macOS Screen Recording (⌘⇧5)")
            default: break
            }
        }
        if combo.modifiers == (ctrl | cmd) && combo.keyCode == 12 {
            return .warning(reason: "Conflicts with macOS Lock Screen (⌃⌘Q)")
        }
        if combo.modifiers == (opt | cmd) && combo.keyCode == 9 {
            return .warning(reason: "Conflicts with Finder Move / Paste & Match Style (⌥⌘V)")
        }

        return nil
    }
}

public enum ActivationShortcutOption: String, CaseIterable, Sendable {
    case cmdShiftV = "cmdShiftV"
    case optV = "optV"
    case ctrlCmdV = "ctrlCmdV"
    case optSpace = "optSpace"

    public var displayTitle: String {
        switch self {
        case .cmdShiftV: return "⌘ + ⇧ + V (Default)"
        case .optV: return "⌥ + V"
        case .ctrlCmdV: return "⌃ + ⌘ + V"
        case .optSpace: return "⌥ + Space"
        }
    }

    public var shortDisplay: String {
        switch self {
        case .cmdShiftV: return "⌘ + ⇧ + V"
        case .optV: return "⌥ + V"
        case .ctrlCmdV: return "⌃ + ⌘ + V"
        case .optSpace: return "⌥ + Space"
        }
    }

    public var keyCode: UInt32 {
        switch self {
        case .cmdShiftV, .optV, .ctrlCmdV: return 9 // 'v'
        case .optSpace: return 49 // Space
        }
    }

    public var modifiers: UInt32 {
        switch self {
        case .cmdShiftV: return UInt32(cmdKey | shiftKey)
        case .optV: return UInt32(optionKey)
        case .ctrlCmdV: return UInt32(controlKey | cmdKey)
        case .optSpace: return UInt32(optionKey)
        }
    }
}

public enum OCRShortcutOption: String, CaseIterable, Sendable {
    case cmdShift2 = "cmdShift2"
    case cmdShiftO = "cmdShiftO"
    case cmdShiftC = "cmdShiftC"
    case optShift2 = "optShift2"
    case optShiftO = "optShiftO"

    public var displayTitle: String {
        switch self {
        case .cmdShift2: return "⌘ + ⇧ + 2 (Default)"
        case .cmdShiftO: return "⌘ + ⇧ + O (OCR)"
        case .cmdShiftC: return "⌘ + ⇧ + C (Capture)"
        case .optShift2: return "⌥ + ⇧ + 2"
        case .optShiftO: return "⌥ + ⇧ + O"
        }
    }

    public var shortDisplay: String {
        switch self {
        case .cmdShift2: return "⌘ + ⇧ + 2"
        case .cmdShiftO: return "⌘ + ⇧ + O"
        case .cmdShiftC: return "⌘ + ⇧ + C"
        case .optShift2: return "⌥ + ⇧ + 2"
        case .optShiftO: return "⌥ + ⇧ + O"
        }
    }

    public var keyCode: UInt32 {
        switch self {
        case .cmdShift2, .optShift2: return 19 // '2'
        case .cmdShiftO, .optShiftO: return 31 // 'o'
        case .cmdShiftC: return 8 // 'c'
        }
    }

    public var modifiers: UInt32 {
        switch self {
        case .cmdShift2, .cmdShiftO, .cmdShiftC:
            return UInt32(cmdKey | shiftKey)
        case .optShift2, .optShiftO:
            return UInt32(optionKey | shiftKey)
        }
    }
}
