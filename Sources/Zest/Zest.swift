import Cocoa
import SwiftUI
import Carbon

@MainActor
final class ZestAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hud: FloatingHUD<ZestView>!
    private var hotKeyManager: HotKeyManager?
    private var ocrHotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Register default preferences so fresh installs have 1-tap pasting enabled immediately
        UserDefaults.standard.register(defaults: [
            "zest_autoPasteKeystroke": true,
            "zest_popupPosition": HUDPosition.cursor.rawValue,
            "zest_theme": AppTheme.system.rawValue,
            "zest_showShortcuts": true,
            "zest_activationShortcut": ActivationShortcutOption.cmdShiftV.rawValue,
            "zest_ocrShortcut": OCRShortcutOption.cmdShift2.rawValue,
            HistoryStorageManager.persistenceKey: true,
            HistoryStorageManager.maxHistoryKey: 100
        ])
        if UserDefaults.standard.object(forKey: "zest_autoPasteKeystroke") == nil {
            UserDefaults.standard.set(true, forKey: "zest_autoPasteKeystroke")
        }

        // 1. Initialize Floating HUD with ZestView
        hud = FloatingHUD { [weak self] in
            ZestView {
                self?.hud.close()
            }
        }

        // 2. Setup Status Bar Item with Dual Action (Left-Click = HUD, Right-Click = Context Menu)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = ""
            button.image = MenuBarIconProvider.makeIcon()
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarIcon),
            name: .menuBarIconDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setupHotKeys),
            name: .shortcutsDidChange,
            object: nil
        )

        // 3. Register Global Shortcuts
        setupHotKeys()

        // 4. Start Clipboard Ingestion Engine
        ClipboardEngine.shared.start(pollingInterval: 0.4)

        print("⚡ Zest running in Menu Bar.")
        fflush(stdout)
    }

    @objc private func setupHotKeys() {
        hotKeyManager?.unregister()
        hotKeyManager = nil
        ocrHotKeyManager?.unregister()
        ocrHotKeyManager = nil

        let actCombo = KeyCombo.load(forKey: KeyCombo.activationKey, default: .defaultActivation)

        hotKeyManager = HotKeyManager(keyCode: actCombo.keyCode, modifiers: actCombo.modifiers, id: 1) { [weak self] in
            guard let self = self else { return }
            if let front = NSWorkspace.shared.frontmostApplication,
               front.bundleIdentifier != Bundle.main.bundleIdentifier {
                PasteEngine.targetApplication = front
            }
            self.hud.toggleAccordingToPreferences(relativeTo: self.statusItem.button)
        }

        let ocrCombo = KeyCombo.load(forKey: KeyCombo.ocrKey, default: .defaultOCR)

        ocrHotKeyManager = HotKeyManager(keyCode: ocrCombo.keyCode, modifiers: ocrCombo.modifiers, id: 2) { [weak self] in
            Task {
                if let _ = await ScreenOCRService.shared.captureAndRecognize() {
                    await MainActor.run {
                        self?.hud.toggleNearCursor()
                    }
                }
            }
        }

        print("⌨️ Activation shortcut: \(actCombo.displayString)")
        print("🔍 Screen OCR shortcut: \(ocrCombo.displayString)")
        fflush(stdout)
    }

    @objc private func statusItemClicked() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            PasteEngine.targetApplication = front
        }

        guard let event = NSApp.currentEvent else {
            hud.toggleAccordingToPreferences(relativeTo: statusItem.button)
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            hud.toggle(relativeTo: statusItem.button)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let actCombo = KeyCombo.load(forKey: KeyCombo.activationKey, default: .defaultActivation)
        let ocrCombo = KeyCombo.load(forKey: KeyCombo.ocrKey, default: .defaultOCR)

        let toggleItem = NSMenuItem(title: "Toggle Zest (\(actCombo.displayString))", action: #selector(menuToggleHUD), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let ocrItem = NSMenuItem(title: "Capture Screen Text (\(ocrCombo.displayString))", action: #selector(menuCaptureScreenText), keyEquivalent: "")
        ocrItem.target = self
        menu.addItem(ocrItem)

        let isPaused = ClipboardEngine.shared.isPaused
        let pauseTitle = isPaused ? "▶ Resume Clipboard Monitoring" : "⏸ Pause Clipboard Monitoring"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(menuTogglePause), keyEquivalent: "")
        pauseItem.state = isPaused ? .on : .off
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(menuOpenPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let guideItem = NSMenuItem(title: "Shortcuts & Guide...", action: #selector(menuOpenGuide), keyEquivalent: "/")
        guideItem.target = self
        menu.addItem(guideItem)

        let aboutItem = NSMenuItem(title: "About Zest", action: #selector(menuOpenAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: "Clear All History", action: #selector(menuClearAll), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Zest", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuToggleHUD() {
        hud.toggleAccordingToPreferences(relativeTo: statusItem.button)
    }

    @objc private func menuCaptureScreenText() {
        Task {
            if let _ = await ScreenOCRService.shared.captureAndRecognize() {
                await MainActor.run {
                    self.hud.toggleNearCursor()
                }
            }
        }
    }

    @objc private func menuTogglePause() {
        ClipboardEngine.shared.isPaused.toggle()
    }

    @objc private func menuOpenPreferences() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func menuOpenGuide() {
        GuideWindowController.shared.showWindow()
    }

    @objc private func menuOpenAbout() {
        AboutWindowController.shared.showWindow()
    }

    @objc private func menuClearAll() {
        ClipboardEngine.shared.clearAll()
    }

    @objc private func updateMenuBarIcon() {
        statusItem.button?.image = MenuBarIconProvider.makeIcon()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardEngine.shared.stop()
        hotKeyManager?.unregister()
        ocrHotKeyManager?.unregister()
    }
}

@main
struct ZestMain {
    @MainActor static var retainedDelegate: ZestAppDelegate?

    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = ZestAppDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}
