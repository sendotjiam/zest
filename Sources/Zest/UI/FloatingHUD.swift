import Foundation
import AppKit
import SwiftUI

@MainActor
public class FloatingHUD<Content: View>: NSPanel {
    private var onClose: (() -> Void)?
    nonisolated(unsafe) private var localKeyMonitor: Any?
    nonisolated(unsafe) private var globalClickMonitor: Any?
    public weak var statusButton: NSStatusBarButton?

    public init(
        contentRect: NSRect = NSRect(x: 0, y: 0, width: 390, height: 360),
        onClose: (() -> Void)? = nil,
        @ViewBuilder view: () -> Content
    ) {
        self.onClose = onClose

        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.isOpaque = false
        self.level = .statusBar
        self.collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.backgroundColor = .clear
        self.hasShadow = true

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        let savedTheme = UserDefaults.standard.string(forKey: "zest_theme")
        if let savedTheme = savedTheme, let theme = AppTheme(rawValue: savedTheme) {
            self.appearance = theme.nsAppearance
        }

        NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] notif in
            let theme = notif.object as? AppTheme
            MainActor.assumeIsolated {
                self?.appearance = theme?.nsAppearance
            }
        }

        let hosting = NSHostingView(rootView: view())
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hosting
    }

    /// CRITICAL: Must return true so panel can receive key status, keyboard events, and outside click dismissal
    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    deinit {
        removeMonitors()
    }

    nonisolated private func removeMonitors() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    private func setupMonitors() {
        removeMonitors()

        // 1. Local monitor for keyboard handling (1-9, 0, Esc, Return, Space)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return event }

            let state = ZestState.shared

            // Escape (53) -> close preview, go back from subdeck, or dismiss HUD
            if event.keyCode == 53 {
                if state.previewItem != nil {
                    state.previewItem = nil
                    return nil
                }
                if state.selectedItem != nil {
                    state.resetTransform()
                    return nil
                }
                self.close()
                return nil
            }

            // Down Arrow (125) -> Navigate to next clip
            if event.keyCode == 125 {
                if state.previewItem == nil && state.selectedItem == nil {
                    let maxIdx = max(0, state.filteredItems.count - 1)
                    state.highlightedIndex = min(state.highlightedIndex + 1, maxIdx)
                    return nil
                }
            }

            // Up Arrow (126) -> Navigate to previous clip
            if event.keyCode == 126 {
                if state.previewItem == nil && state.selectedItem == nil {
                    state.highlightedIndex = max(0, state.highlightedIndex - 1)
                    return nil
                }
            }

            // Space key (49) -> Quick Look Preview toggle
            if event.keyCode == 49 {
                if state.previewItem != nil {
                    state.previewItem = nil
                    return nil
                } else if state.selectedItem == nil {
                    if state.searchText.isEmpty {
                        if let item = state.currentHighlightedItem {
                            state.previewItem = item
                            return nil
                        }
                    } else if state.highlightedIndex > 0 {
                        if let item = state.currentHighlightedItem {
                            state.previewItem = item
                            return nil
                        }
                    }
                }
            }

            // Return key (36) -> paste preview (if open), transformed output, or currently highlighted item
            if event.keyCode == 36 {
                let isShift = event.modifierFlags.contains(.shift)
                let isOption = event.modifierFlags.contains(.option)

                if let preview = state.previewItem {
                    if isShift {
                        PasteEngine.copyOnly(item: preview) { self.close() }
                    } else if isOption {
                        PasteEngine.pastePlainText(item: preview) { self.close() }
                    } else {
                        PasteEngine.paste(item: preview) { self.close() }
                    }
                    return nil
                }

                if let selected = state.selectedItem {
                    if selected.isImage, let data = selected.imageData {
                        if let text = state.transformedPreview {
                            if isShift {
                                PasteEngine.copyOnly(text: text) { self.close() }
                            } else {
                                PasteEngine.paste(text: text) { self.close() }
                            }
                        } else {
                            if isShift {
                                PasteEngine.copyImageOnly(data: data) { self.close() }
                            } else {
                                PasteEngine.pasteImage(data: data) { self.close() }
                            }
                        }
                    } else {
                        let target = state.transformedPreview ?? selected.rawContent
                        if isShift {
                            PasteEngine.copyOnly(text: target) { self.close() }
                        } else if isOption {
                            let plain = DataTransformer.stripFormatting(target)
                            PasteEngine.paste(text: plain) { self.close() }
                        } else {
                            PasteEngine.paste(text: target) { self.close() }
                        }
                    }
                    return nil
                } else if let current = state.currentHighlightedItem {
                    if isShift {
                        PasteEngine.copyOnly(item: current) { self.close() }
                    } else if isOption {
                        PasteEngine.pastePlainText(item: current) { self.close() }
                    } else {
                        PasteEngine.paste(item: current) { self.close() }
                    }
                    return nil
                }
            }

            // Number keys 1..9, 0 (Top row & Keypad)
            let digitKeyMap: [UInt16: Int] = [
                18: 0, // '1'
                19: 1, // '2'
                20: 2, // '3'
                21: 3, // '4'
                23: 4, // '5'
                22: 5, // '6'
                26: 6, // '7'
                28: 7, // '8'
                25: 8, // '9'
                29: 9, // '0' -> 10th item
                83: 0, // Keypad 1
                84: 1, // Keypad 2
                85: 2, // Keypad 3
                86: 3, // Keypad 4
                87: 4, // Keypad 5
                88: 5, // Keypad 6
                89: 6, // Keypad 7
                91: 7, // Keypad 8
                92: 8, // Keypad 9
                82: 9  // Keypad 0
            ]

            // Resolve target index from keycode or character
            let targetIdx: Int? = {
                if let idx = digitKeyMap[event.keyCode] {
                    return idx
                }
                if let chars = event.charactersIgnoringModifiers, let first = chars.first, first.isNumber {
                    if let val = Int(String(first)) {
                        return val == 0 ? 9 : val - 1
                    }
                }
                return nil
            }()

            if let targetIdx = targetIdx {
                // Intersect strictly with modifier keys, stripping device-dependent flags like .numericPad and .function
                let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])

                // Case 1: Option + digit (⌥1..⌥9) -> Instant paste pinned snippets
                if modifiers.contains(.option) {
                    let pinnedItems = ClipboardEngine.shared.items.filter(\.isPinned)
                    if targetIdx < pinnedItems.count {
                        let pinned = pinnedItems[targetIdx]
                        if modifiers.contains(.shift) {
                            PasteEngine.copyOnly(item: pinned) { self.close() }
                        } else {
                            PasteEngine.paste(item: pinned) { self.close() }
                        }
                        return nil
                    }
                }

                // Case 2: Shift + digit (⇧1..⇧9, ⇧0) -> Copy-only mode
                if modifiers == [.shift] && state.selectedItem == nil {
                    if targetIdx < state.filteredItems.count {
                        PasteEngine.copyOnly(item: state.filteredItems[targetIdx]) {
                            self.close()
                        }
                        return nil
                    }
                }

                // Case 3: ⌘ + digit (Cmd + 1..9, Cmd + 0) -> Paste
                if modifiers.contains(.command) {
                    if targetIdx < state.filteredItems.count {
                        PasteEngine.paste(item: state.filteredItems[targetIdx]) {
                            self.close()
                        }
                        return nil
                    }
                }

                // Case 4: Raw digit without modifiers (Tap 1-9, 0 directly) -> Always Paste!
                if modifiers.isEmpty {
                    if state.selectedItem == nil {
                        if targetIdx < state.filteredItems.count {
                            PasteEngine.paste(item: state.filteredItems[targetIdx]) {
                                self.close()
                            }
                            return nil
                        }
                    }
                }
            }

            return event
        }

        // 2. Global monitor for outside clicks anywhere on macOS
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            let mouseLoc = NSEvent.mouseLocation

            // If click landed on the status button that toggles the HUD, let the status button's action toggle it cleanly
            if let button = self.statusButton, let buttonWindow = button.window {
                let buttonRect = button.convert(button.bounds, to: nil)
                let screenRect = buttonWindow.convertToScreen(buttonRect)
                if screenRect.contains(mouseLoc) {
                    return
                }
            }

            if !self.frame.contains(mouseLoc) {
                DispatchQueue.main.async {
                    self.close()
                }
            }
        }
    }

    public override func close() {
        super.close()
        removeMonitors()
        ZestState.shared.resetAll()
        onClose?()
    }

    public func toggle(relativeTo statusButton: NSStatusBarButton?) {
        if isVisible {
            close()
        } else {
            show(relativeTo: statusButton)
        }
    }

    public func toggleNearCursor() {
        if isVisible {
            close()
        } else {
            showNearCursor()
        }
    }

    private func recordTargetApp() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            PasteEngine.targetApplication = front
        }
    }

    public func showNearCursor() {
        recordTargetApp()
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSPointInRect(mouseLocation, $0.frame) } ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = targetScreen.visibleFrame

        var x = mouseLocation.x - (frame.width / 2)
        var y = mouseLocation.y - (frame.height / 2)

        x = max(screenFrame.minX + 10, min(x, screenFrame.maxX - frame.width - 10))
        y = max(screenFrame.minY + 10, min(y, screenFrame.maxY - frame.height - 10))

        setFrameOrigin(NSPoint(x: x, y: y))
        invalidateShadow()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        setupMonitors()
    }

    public func show(relativeTo statusButton: NSStatusBarButton?) {
        recordTargetApp()
        self.statusButton = statusButton

        if let button = statusButton, let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            
            var x = screenRect.midX - (frame.width / 2)
            var y = screenRect.minY - frame.height - 6

            if let screen = buttonWindow.screen ?? NSScreen.main {
                let screenFrame = screen.visibleFrame
                x = max(screenFrame.minX + 8, min(x, screenFrame.maxX - frame.width - 8))
                y = max(screenFrame.minY + 8, y)
            }

            setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            showNearCursor()
            return
        }

        invalidateShadow()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        setupMonitors()
    }

    public func toggleAtCenter() {
        if isVisible {
            close()
        } else {
            showAtCenter()
        }
    }

    public func showAtCenter() {
        recordTargetApp()
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSPointInRect(mouseLocation, $0.frame) } ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = targetScreen.visibleFrame

        let x = screenFrame.midX - (frame.width / 2)
        let y = screenFrame.midY - (frame.height / 2)

        setFrameOrigin(NSPoint(x: x, y: y))
        invalidateShadow()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        setupMonitors()
    }

    public func toggleAccordingToPreferences(relativeTo statusButton: NSStatusBarButton?) {
        self.statusButton = statusButton
        let pref = UserDefaults.standard.string(forKey: "zest_popupPosition") ?? HUDPosition.cursor.rawValue
        switch pref {
        case HUDPosition.center.rawValue:
            toggleAtCenter()
        case HUDPosition.statusBar.rawValue:
            toggle(relativeTo: statusButton)
        default:
            toggleNearCursor()
        }
    }
}
