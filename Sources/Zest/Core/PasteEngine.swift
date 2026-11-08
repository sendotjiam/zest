import Foundation
import AppKit
import CoreGraphics

@MainActor
public enum PasteEngine {
    private static var hasPromptedAccessibility: Bool = false
    public static var targetApplication: NSRunningApplication?

    public static var hasAccessibilityPermission: Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    public static var isAutoPasteEnabled: Bool {
        if let val = UserDefaults.standard.object(forKey: "zest_autoPasteKeystroke") as? Bool {
            return val
        }
        return true
    }

    public static func requestAccessibilityPermission() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public static func openAccessibilityPreferences() {
        requestAccessibilityPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public static func checkAccessibility(promptIfUntrusted: Bool = false) -> Bool {
        let trusted = AXIsProcessTrustedWithOptions(nil)
        if !trusted && promptIfUntrusted && !hasPromptedAccessibility {
            hasPromptedAccessibility = true
            requestAccessibilityPermission()
        }
        return trusted
    }

    /// Injects clip item (text or image) into target active application
    @MainActor
    public static func paste(item: ClipItem, dismissHUD: () -> Void) {
        if item.isImage, let data = item.imageData {
            pasteImage(data: data, dismissHUD: dismissHUD)
        } else {
            paste(text: item.rawContent, dismissHUD: dismissHUD)
        }
    }

    /// Strips formatting (HTML, Markdown) and injects unformatted plain text into active application
    @MainActor
    public static func pastePlainText(item: ClipItem, dismissHUD: () -> Void) {
        if item.isImage, let data = item.imageData {
            pasteImage(data: data, dismissHUD: dismissHUD)
        } else {
            let plain = DataTransformer.stripFormatting(item.rawContent)
            paste(text: plain, dismissHUD: dismissHUD)
        }
    }

    /// Copies clip item to clipboard without injecting Cmd+V keystroke
    @MainActor
    public static func copyOnly(item: ClipItem, dismissHUD: () -> Void) {
        if item.isImage, let data = item.imageData {
            copyImageOnly(data: data, dismissHUD: dismissHUD)
        } else {
            copyOnly(text: item.rawContent, dismissHUD: dismissHUD)
        }
    }

    /// Injects text into target active application by updating pasteboard and triggering Cmd+V
    @MainActor
    public static func paste(text: String, dismissHUD: () -> Void) {
        dismissHUD()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Mark as Zest internal paste to prevent clipboard monitoring loop
        pasteboard.setString("1", forType: .fromZest)

        // Reactivate target application if known
        if let target = targetApplication, target.bundleIdentifier != Bundle.main.bundleIdentifier {
            target.activate()
        }

        guard isAutoPasteEnabled else { return }

        // Allow target window 120ms to regain key window focus after HUD closes and app activates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            simulatePasteKeystroke()
        }
    }

    /// Injects image into target active application by updating pasteboard with PNG & TIFF and triggering Cmd+V
    @MainActor
    public static func pasteImage(data: Data, dismissHUD: () -> Void) {
        dismissHUD()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
        if let tiffData = NSBitmapImageRep(data: data)?.representation(using: .tiff, properties: [:]) {
            pasteboard.setData(tiffData, forType: .tiff)
        }
        pasteboard.setString("1", forType: .fromZest)

        // Reactivate target application if known
        if let target = targetApplication, target.bundleIdentifier != Bundle.main.bundleIdentifier {
            target.activate()
        }

        guard isAutoPasteEnabled else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            simulatePasteKeystroke()
        }
    }

    /// Copies text to clipboard without pasting
    @MainActor
    public static func copyOnly(text: String, dismissHUD: () -> Void) {
        dismissHUD()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString("1", forType: .fromZest)
    }

    /// Copies image to clipboard without pasting
    @MainActor
    public static func copyImageOnly(data: Data, dismissHUD: () -> Void) {
        dismissHUD()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
        if let tiffData = NSBitmapImageRep(data: data)?.representation(using: .tiff, properties: [:]) {
            pasteboard.setData(tiffData, forType: .tiff)
        }
        pasteboard.setString("1", forType: .fromZest)
    }

    public static func simulatePasteKeystroke() {
        // If accessibility is not yet granted, prompt at most once, but still attempt event delivery
        if !hasAccessibilityPermission && !hasPromptedAccessibility {
            hasPromptedAccessibility = true
            requestAccessibilityPermission()
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        // Keycode 9 is 'v' on standard keyboards (kVK_ANSI_V)
        let vKeyCode: CGKeyCode = 9
        // Add device-dependent left command key flag (0x000008 / NX_DEVICELCMDKEYMASK)
        // so that Chrome, Electron, Terminal, and modern text inputs process the Command modifier correctly
        let cmdFlag = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x000008)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = cmdFlag
        keyUp.flags = cmdFlag

        // Post to hardware HID event tap for direct system-wide keystroke injection
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
