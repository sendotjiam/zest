import SwiftUI
import AppKit
import ServiceManagement

public enum HUDPosition: String, CaseIterable, Sendable {
    case cursor = "cursor"
    case center = "center"
    case statusBar = "statusBar"

    public var title: String {
        switch self {
        case .cursor: return "Near Mouse Cursor"
        case .center: return "Screen Center"
        case .statusBar: return "Under Menu Bar Icon"
        }
    }
}

@MainActor
public struct PreferencesView: View {
    public enum Tab: Int, CaseIterable, Identifiable, Sendable {
        case general = 0
        case history = 1
        case privacy = 2
        case appearance = 3
        case guide = 4

        public var id: Int { rawValue }

        @MainActor
        public var title: String {
            switch self {
            case .general: return L10n.shared.tr(.generalTab)
            case .history: return L10n.shared.tr(.historyTab)
            case .privacy: return L10n.shared.tr(.privacyTab)
            case .appearance: return L10n.shared.tr(.appearanceTab)
            case .guide: return L10n.shared.tr(.guideTab)
            }
        }
    }

    @AppStorage("zest_popupPosition") private var popupPosition: String = HUDPosition.cursor.rawValue
    @AppStorage("zest_autoPasteKeystroke") private var autoPaste: Bool = true
    @AppStorage(HistoryStorageManager.persistenceKey) private var persistenceEnabled: Bool = true
    @AppStorage(HistoryStorageManager.maxHistoryKey) private var maxHistory: Int = 100
    @AppStorage("zest_theme") private var themeRawValue: String = AppTheme.system.rawValue
    @AppStorage("zest_showShortcuts") private var showShortcuts: Bool = true

    @State private var selectedTab: Tab
    @State private var ignoredApps: [String] = UserDefaults.standard.stringArray(forKey: "zest_ignoredAppBundleIDs") ?? []
    @State private var newAppBundleID: String = ""
    @State private var showingClearAlert: Bool = false
    @State private var hasAccessibility: Bool = PasteEngine.hasAccessibilityPermission
    @State private var hasScreenRecording: Bool = ScreenOCRService.hasScreenRecordingPermission
    @State private var launchAtLogin: Bool = {
        return SMAppService.mainApp.status == .enabled
    }()

    public init(initialTab: Tab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()

            Group {
                switch selectedTab {
                case .general:
                    generalTab
                case .history:
                    historyTab
                case .privacy:
                    privacyTab
                case .appearance:
                    appearanceTab
                case .guide:
                    guideTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - Guide Tab
    private var guideTab: some View {
        ShortcutsGuideView()
    }

    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section {
                ShortcutRecorderView(
                    title: "Activation Shortcut:",
                    storageKey: KeyCombo.activationKey,
                    defaultCombo: .defaultActivation
                )

                ShortcutRecorderView(
                    title: "Screen OCR Shortcut:",
                    storageKey: KeyCombo.ocrKey,
                    defaultCombo: .defaultOCR
                )

                Picker("HUD Summon Position:", selection: $popupPosition) {
                    ForEach(HUDPosition.allCases, id: \.rawValue) { pos in
                        Text(pos.title).tag(pos.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Auto-paste on tap (Synthesize ⌘V into active window)", isOn: $autoPaste)
                    .help("When disabled, tapping 1-9 copies to clipboard without injecting keystrokes into foreground app.")

                Picker("Interface Language:", selection: Binding(
                    get: { L10n.shared.currentLanguage },
                    set: { L10n.shared.currentLanguage = $0 }
                )) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .help("Select interface language (English, 简体中文, 日本語)")
            } header: {
                Text("Summon & Interaction")
            }

            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        updateLaunchAtLogin(enabled: newValue)
                    }
                ))
                .help("Automatically start Zest in the background when logging in.")

                Text("Runs unobtrusively in your menu bar on system startup.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } header: {
                Text("System Startup")
            }
        }
        .formStyle(.grouped)
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } catch {
            print("Failed to update Launch at Login: \(error)")
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    // MARK: - History Tab
    private var historyTab: some View {
        Form {
            Section {
                Picker("Storage Mode:", selection: $persistenceEnabled) {
                    Text("Persistent Local Disk Cache").tag(true)
                    Text("Ephemeral RAM-Only Mode").tag(false)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: persistenceEnabled) { _, newValue in
                    HistoryStorageManager.shared.isPersistenceEnabled = newValue
                }

                Text(persistenceEnabled ? "Clips are safely saved to ~/Library/Application Support/Zest across restarts." : "🔒 Clipboard history is held strictly in RAM and completely wiped upon quitting.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Stepper("Max History Items: \(maxHistory)", value: $maxHistory, in: 25...500, step: 25)
                    .onChange(of: maxHistory) { _, newValue in
                        HistoryStorageManager.shared.maxHistoryLimit = newValue
                    }

                HStack {
                    Spacer()
                    Button(role: .destructive, action: { showingClearAlert = true }) {
                        Text("Clear All Clipboard History")
                    }
                    .alert("Clear All History?", isPresented: $showingClearAlert) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clear", role: .destructive) {
                            ClipboardEngine.shared.clearAll()
                        }
                    } message: {
                        Text("This will immediately erase all saved clips from RAM and disk.")
                    }
                }
            } header: {
                Text("History & Retention")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Privacy Tab
    private var privacyTab: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility Permission")
                            .font(.system(size: 12, weight: .medium))
                        Text(hasAccessibility ? "Granted: direct 1-tap pasting is fully enabled." : "Not Granted: required to simulate ⌘V keystroke.")
                            .font(.system(size: 11))
                            .foregroundColor(hasAccessibility ? .secondary : .orange)
                    }
                    Spacer()
                    Button(hasAccessibility ? "Check Status" : "Grant Access...") {
                        PasteEngine.requestAccessibilityPermission()
                        hasAccessibility = PasteEngine.hasAccessibilityPermission
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screen Recording Permission")
                            .font(.system(size: 12, weight: .medium))
                        Text(hasScreenRecording ? "Granted: screen text capture (OCR) is fully enabled." : "Not Granted: required for ⌘⇧2 screen text OCR.")
                            .font(.system(size: 11))
                            .foregroundColor(hasScreenRecording ? .secondary : .orange)
                    }
                    Spacer()
                    Button(hasScreenRecording ? "Check Status" : "Grant Access...") {
                        ScreenOCRService.requestScreenRecordingPermission()
                        hasScreenRecording = ScreenOCRService.hasScreenRecordingPermission
                    }
                }
            } header: {
                Text("System Permissions")
            }

            Section {
                Text("Excluded Applications (Blacklist):")
                    .font(.system(size: 12, weight: .medium))

                Text("Copies originating from these apps will be completely ignored and never stored.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                List {
                    ForEach(ignoredApps, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(size: 11, design: .monospaced))
                            Spacer()
                            Button(action: { removeIgnoredApp(bundleID) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 100)

                HStack {
                    TextField("com.example.app", text: $newAppBundleID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))

                    Button("Add App") {
                        addIgnoredApp(newAppBundleID)
                    }
                    .disabled(newAppBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                HStack(spacing: 8) {
                    Text("Quick Add:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Button("1Password") { addIgnoredApp("com.agilebits.onepassword") }
                        .buttonStyle(.link)
                        .font(.system(size: 10))

                    Button("Bitwarden") { addIgnoredApp("com.bitwarden.desktop") }
                        .buttonStyle(.link)
                        .font(.system(size: 10))

                    Button("Terminal") { addIgnoredApp("com.apple.Terminal") }
                        .buttonStyle(.link)
                        .font(.system(size: 10))
                }
            } header: {
                Text("Security & Privacy Guard")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance Tab
    private var appearanceTab: some View {
        Form {
            Section {
                Picker("Theme Appearance:", selection: $themeRawValue) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: themeRawValue) { _, newValue in
                    if let theme = AppTheme(rawValue: newValue) {
                        NotificationCenter.default.post(name: .themeDidChange, object: theme)
                    }
                }

                Toggle("Show 1–10 Quick-Paste Badges on Rows", isOn: $showShortcuts)
            } header: {
                Text("Look & Feel")
            }
        }
        .formStyle(.grouped)
    }

    private func addIgnoredApp(_ bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !ignoredApps.contains(trimmed) else { return }
        ignoredApps.append(trimmed)
        UserDefaults.standard.set(ignoredApps, forKey: "zest_ignoredAppBundleIDs")
        newAppBundleID = ""
    }

    private func removeIgnoredApp(_ bundleID: String) {
        ignoredApps.removeAll { $0 == bundleID }
        UserDefaults.standard.set(ignoredApps, forKey: "zest_ignoredAppBundleIDs")
    }
}

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    public var isWindowVisible: Bool {
        window?.isVisible ?? false
    }

    private override init() {
        super.init()
    }

    public func showWindow(tab: PreferencesView.Tab = .general) {
        NSApp.setActivationPolicy(.regular)

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let preferencesView = PreferencesView(initialTab: tab)
        let hosting = NSHostingView(rootView: preferencesView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Zest Preferences"
        win.center()
        win.contentView = hosting
        win.isReleasedWhenClosed = false
        win.delegate = self

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        if !GuideWindowController.shared.isWindowVisible && !AboutWindowController.shared.isWindowVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
