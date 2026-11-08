import SwiftUI
import AppKit

@MainActor
public struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // App Icon (Clean, simple, no gradients)
            if let appIcon = NSImage(named: "AppIcon") ?? loadBundleIcon() {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 34))
                    .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))
                    .frame(width: 72, height: 72)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(red: 0.10, green: 0.10, blue: 0.12)))
            }

            VStack(spacing: 4) {
                Text("Zest")
                    .font(.system(size: 20, weight: .bold))

                Text("Version 1.2.0 (Build 5)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("The sub-millisecond, 1-tap clipboard HUD for macOS developers.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }

            // Specs Matrix
            HStack(spacing: 10) {
                specPill(title: "RAM", value: "< 20 MB", color: .green)
                specPill(title: "CPU", value: "0.001%", color: .green)
                specPill(title: "Privacy", value: "100% On-Device", color: .blue)
                specPill(title: "Swift", value: "6.0 Native", color: .orange)
            }

            // Open-Source MIT License status
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("100% Free & Open Source • MIT License")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.green.opacity(0.10)))

            Text("Eliminate the 3-step clipboard ceremony. Press ⌘⇧V, tap 1-9, and items are instantly pasted without stealing cursor focus.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            Divider()

            HStack {
                Button("GitHub") {
                    if let url = URL(string: "https://github.com/sendotjiam/zest") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 11))

                Text("•")
                    .foregroundColor(.secondary.opacity(0.4))
                    .font(.system(size: 9))

                Button("Releases") {
                    if let url = URL(string: "https://github.com/sendotjiam/zest/releases") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 11))

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .font(.system(size: 11))
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private func specPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.10)))
    }

    private func loadBundleIcon() -> NSImage? {
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns") {
            return NSImage(contentsOfFile: iconPath)
        }
        return nil
    }
}

@MainActor
public final class AboutWindowController: NSObject, NSWindowDelegate {
    public static let shared = AboutWindowController()

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

        let aboutView = AboutView()
        let hosting = NSHostingView(rootView: aboutView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "About Zest"
        win.center()
        win.contentView = hosting
        win.isReleasedWhenClosed = false
        win.delegate = self

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        if !SettingsWindowController.shared.isWindowVisible && !GuideWindowController.shared.isWindowVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
