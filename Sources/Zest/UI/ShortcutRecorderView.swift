import SwiftUI
import AppKit
import Carbon

@MainActor
public struct ShortcutRecorderView: View {
    let title: String
    let storageKey: String
    let defaultCombo: KeyCombo

    @State private var combo: KeyCombo
    @State private var isRecording: Bool = false
    @State private var eventMonitor: Any?
    @State private var showMissingModifierWarning: Bool = false
    @State private var conflictReason: String? = nil
    @State private var isConflictBlocked: Bool = false

    public init(title: String, storageKey: String, defaultCombo: KeyCombo) {
        self.title = title
        self.storageKey = storageKey
        self.defaultCombo = defaultCombo
        let loaded = KeyCombo.load(forKey: storageKey, default: defaultCombo)
        _combo = State(initialValue: loaded)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isRecording {
                                Image(systemName: "record.circle.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.orange)
                            }

                            Text(isRecording ? "Press keys on keyboard..." : combo.displayString)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(isRecording ? .orange : .primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isRecording ? Color.orange.opacity(0.12) : Color.primary.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(
                                    isRecording ? Color.orange : Color.primary.opacity(0.14),
                                    lineWidth: isRecording ? 1.5 : 0.75
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help(isRecording ? "Press shortcut keys, or Esc to cancel" : "Click to record a custom shortcut")

                    if combo != defaultCombo {
                        Button(action: {
                            stopRecording()
                            combo = defaultCombo
                            defaultCombo.save(forKey: storageKey)
                            updateConflictState()
                            NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
                        }) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Reset to default (\(defaultCombo.displayString))")
                    }
                }
            }

            if showMissingModifierWarning {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 9))
                    Text("Must include ⌘, ⌥, or ⌃")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.red)
            } else if let reason = conflictReason {
                HStack(spacing: 4) {
                    Image(systemName: isConflictBlocked ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text(reason)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(isConflictBlocked ? .red : .orange)
            }
        }
        .onAppear {
            updateConflictState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutsDidChange)) { _ in
            combo = KeyCombo.load(forKey: storageKey, default: defaultCombo)
            updateConflictState()
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func updateConflictState() {
        if let conflict = ShortcutConflictChecker.check(combo: combo, storageKey: storageKey) {
            switch conflict {
            case .blocked(let reason):
                conflictReason = reason
                isConflictBlocked = true
            case .warning(let reason):
                conflictReason = reason
                isConflictBlocked = false
            }
        } else {
            conflictReason = nil
            isConflictBlocked = false
        }
    }

    private func startRecording() {
        showMissingModifierWarning = false
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Esc cancels recording
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasCmd = flags.contains(.command)
            let hasOpt = flags.contains(.option)
            let hasCtrl = flags.contains(.control)
            let hasShift = flags.contains(.shift)

            // Must include at least ⌘, ⌥, or ⌃ so user doesn't block regular typing
            guard hasCmd || hasOpt || hasCtrl else {
                NSSound.beep()
                showMissingModifierWarning = true
                return nil
            }

            var carbonMods: UInt32 = 0
            var parts: [String] = []

            if hasCtrl {
                carbonMods |= UInt32(controlKey)
                parts.append("⌃")
            }
            if hasOpt {
                carbonMods |= UInt32(optionKey)
                parts.append("⌥")
            }
            if hasShift {
                carbonMods |= UInt32(shiftKey)
                parts.append("⇧")
            }
            if hasCmd {
                carbonMods |= UInt32(cmdKey)
                parts.append("⌘")
            }

            let keyChar = KeyCodeHelper.string(for: event.keyCode, characters: event.charactersIgnoringModifiers)
            parts.append(keyChar)

            let newCombo = KeyCombo(
                keyCode: UInt32(event.keyCode),
                modifiers: carbonMods,
                displayString: parts.joined(separator: " + ")
            )

            // Evaluate conflict level
            if let conflict = ShortcutConflictChecker.check(combo: newCombo, storageKey: storageKey) {
                switch conflict {
                case .blocked(let reason):
                    NSSound.beep()
                    self.conflictReason = reason
                    self.isConflictBlocked = true
                    // Blocked shortcuts are not accepted
                    return nil
                case .warning(let reason):
                    self.conflictReason = reason
                    self.isConflictBlocked = false
                }
            } else {
                self.conflictReason = nil
                self.isConflictBlocked = false
            }

            self.combo = newCombo
            newCombo.save(forKey: storageKey)
            NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)

            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
        showMissingModifierWarning = false
    }
}
