import SwiftUI
import AppKit

@MainActor
public struct ShortcutsGuideView: View {
    @ObservedObject var l10n = L10n.shared
    @State private var activationCombo = KeyCombo.load(forKey: KeyCombo.activationKey, default: .defaultActivation)
    @State private var ocrCombo = KeyCombo.load(forKey: KeyCombo.ocrKey, default: .defaultOCR)

    private var activationKeys: [String] {
        activationCombo.displayString.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private var ocrKeys: [String] {
        ocrCombo.displayString.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.tr(.guideTitle))
                            .font(.system(size: 16, weight: .bold))
                        Text("Master every keystroke and power feature in Zest")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 4)

                // Section 1: Fast Pasting
                guideSection(title: "1-Tap Fast Pasting", icon: "bolt.fill", color: .yellow) {
                    guideRow(keys: activationKeys, desc: "Summon Zest HUD near cursor or center")
                    guideRow(keys: ocrKeys, desc: "Block screen area & copy recognized text to clipboard (OCR)")
                    guideRow(keys: ["1", "–", "9"], desc: "Instant 1-tap paste item #1 through #9 into active editor")
                    guideRow(keys: ["0"], desc: "Instant 1-tap paste item #10")
                    guideRow(keys: ["⌥1", "–", "⌥9"], desc: "Instant 1-tap paste pinned snippet #1 through #9")
                    guideRow(keys: ["↵"], desc: "Paste currently highlighted or topmost clip")
                }

                // Section 2: Quick Look & Navigation
                guideSection(title: "Quick Look & Navigation", icon: "eye.fill", color: .blue) {
                    guideRow(keys: ["Space"], desc: "Toggle Quick Look expanded preview (lines, chars, full text)")
                    guideRow(keys: ["↓", "↑"], desc: "Navigate clips up and down with live highlight")
                    guideRow(keys: ["Tab"], desc: "Open in-flight Transform Deck (JSON, Case, JWT, Encodings)")
                    guideRow(keys: ["Esc"], desc: "Dismiss Quick Look, exit Transform Deck, or close HUD")
                }

                // Section 3: Modifier Actions
                guideSection(title: "Modifier Actions", icon: "command", color: .purple) {
                    guideRow(keys: ["⇧", "+", "1–9"], desc: "Copy-only mode: copy to clipboard without typing ⌘V")
                    guideRow(keys: ["⇧", "+", "↵"], desc: "Copy highlighted clip without typing ⌘V")
                    guideRow(keys: ["⌥", "+", "↵"], desc: "Plain-text paste: strip fonts, HTML, and rich formatting")
                }

                // Section 4: Subsequence Fuzzy Search
                guideSection(title: "Subsequence Fuzzy Search", icon: "magnifyingglass", color: .teal) {
                    guideRow(keys: ["dburl"], desc: "Matches 'export DATABASE_URL=\"postgres://...\"'")
                    guideRow(keys: ["zst"], desc: "Matches 'Zest'")
                    guideRow(keys: ["img"], desc: "Filter and display copied image clips only")
                }

                // Section 5: Real-Time Content Badges
                guideSection(title: "Content Syntax Classification", icon: "tag.fill", color: .green) {
                    HStack(spacing: 6) {
                        badgeTag("JSON", color: .orange)
                        badgeTag("SQL", color: .teal)
                        badgeTag("PY", color: .cyan)
                        badgeTag("TS", color: .blue)
                        badgeTag("GO", color: .teal)
                        badgeTag("RS", color: .orange)
                        badgeTag("HTML", color: .red)
                        badgeTag("YAML", color: .purple)
                        badgeTag("JWT", color: .purple)
                        badgeTag("HEX", color: .pink)
                    }
                    .padding(.top, 4)

                    Text("Clips are analyzed in sub-microseconds without regex bottlenecks.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 460)
        .onReceive(NotificationCenter.default.publisher(for: .shortcutsDidChange)) { _ in
            activationCombo = KeyCombo.load(forKey: KeyCombo.activationKey, default: .defaultActivation)
            ocrCombo = KeyCombo.load(forKey: KeyCombo.ocrKey, default: .defaultOCR)
        }
    }

    private func guideSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 2)

            VStack(spacing: 5) {
                content()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        }
    }

    private func guideRow(keys: [String], desc: String) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { k in
                    if k == "+" || k == "–" {
                        Text(k)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text(k)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20)))
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                    }
                }
            }
            .frame(width: 90, alignment: .leading)

            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    private func badgeTag(_ name: String, color: Color) -> some View {
        Text(name)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .cornerRadius(4)
    }
}

@MainActor
public final class GuideWindowController: NSObject, NSWindowDelegate {
    public static let shared = GuideWindowController()

    private var window: NSWindow?

    public var isWindowVisible: Bool {
        window?.isVisible ?? false
    }

    private override init() {
        super.init()
    }

    public func showWindow() {
        NSApp.setActivationPolicy(.regular)

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let guideView = ShortcutsGuideView()
        let hosting = NSHostingView(rootView: guideView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Zest Shortcuts & User Guide"
        win.minSize = NSSize(width: 460, height: 440)
        win.center()
        win.contentView = hosting
        win.isReleasedWhenClosed = false
        win.delegate = self

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        if !SettingsWindowController.shared.isWindowVisible && !AboutWindowController.shared.isWindowVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
