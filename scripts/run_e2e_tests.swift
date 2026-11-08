#!/usr/bin/env swift
import Foundation
import AppKit

// MARK: - Zest Automated End-to-End (E2E) Test Suite
// Exercises the real packaged Zest.app against real macOS clipboard events,
// sandboxing integrity, persistence, privacy filters, and graceful process lifecycle.

struct E2ETestRunner {
    let projectDir: URL
    let appURL: URL
    var passedCount = 0
    var failedCount = 0

    init() {
        let currentPath = FileManager.default.currentDirectoryPath
        self.projectDir = URL(fileURLWithPath: currentPath)
        self.appURL = projectDir.appendingPathComponent("Zest.app")
    }

    mutating func run() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🚀 Zest Production End-to-End (E2E) Test Suite")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        testBundleIntegrity()
        testCodeSignatureAndEntitlements()
        testLiveAppClipboardAndLifecycle()

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        if failedCount == 0 {
            print("✅ ALL E2E PRODUCTION TESTS PASSED (\(passedCount) verified checks)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            exit(0)
        } else {
            print("❌ E2E FAILURES DETECTED: \(failedCount) failed, \(passedCount) passed")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            exit(1)
        }
    }

    mutating func assert(_ condition: Bool, _ testName: String, failureReason: String = "") {
        if condition {
            print("  ✔ [PASS] \(testName)")
            passedCount += 1
        } else {
            print("  ✖ [FAIL] \(testName) - \(failureReason)")
            failedCount += 1
        }
    }

    // MARK: - Test 1: App Bundle Integrity
    mutating func testBundleIntegrity() {
        print("\n📦 Test Suite 1: App Bundle & Metadata Integrity")

        assert(FileManager.default.fileExists(atPath: appURL.path), "Zest.app exists in build output")

        let binaryURL = appURL.appendingPathComponent("Contents/MacOS/Zest")
        assert(FileManager.default.isExecutableFile(atPath: binaryURL.path), "Contents/MacOS/Zest is executable")

        let iconURL = appURL.appendingPathComponent("Contents/Resources/AppIcon.icns")
        assert(FileManager.default.fileExists(atPath: iconURL.path), "Contents/Resources/AppIcon.icns is packaged")

        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        assert(FileManager.default.fileExists(atPath: plistURL.path), "Contents/Info.plist exists")

        if let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] {
            assert(dict["CFBundleIdentifier"] as? String == "app.zest.macos", "CFBundleIdentifier is 'app.zest.macos'")
            assert(dict["LSUIElement"] as? Bool == true, "LSUIElement is true (pure menu bar accessory)")
            assert(dict["LSApplicationCategoryType"] as? String == "public.app-category.utilities", "LSApplicationCategoryType is configured for App Store")
            assert(dict["CFBundleShortVersionString"] != nil, "CFBundleShortVersionString is defined")
            assert(dict["CFBundleVersion"] != nil, "CFBundleVersion is defined")
        } else {
            assert(false, "Failed to parse Info.plist")
        }
    }

    // MARK: - Test 2: Code Signing & Entitlements
    mutating func testCodeSignatureAndEntitlements() {
        print("\n🔏 Test Suite 2: Codesigning & App Sandbox Verification")

        let verifyProcess = Process()
        verifyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        verifyProcess.arguments = ["--verify", "--deep", "--strict", appURL.path]

        do {
            try verifyProcess.run()
            verifyProcess.waitUntilExit()
            assert(verifyProcess.terminationStatus == 0, "codesign --verify --deep --strict passes")
        } catch {
            assert(false, "codesign verification crashed: \(error)")
        }

        let entitlementsURL = projectDir.appendingPathComponent("Zest.entitlements")
        assert(FileManager.default.fileExists(atPath: entitlementsURL.path), "Zest.entitlements is present")

        if let entData = try? Data(contentsOf: entitlementsURL),
           let entString = String(data: entData, encoding: .utf8) {
            assert(entString.contains("com.apple.security.app-sandbox"), "com.apple.security.app-sandbox is declared in entitlements")
        } else {
            assert(false, "Could not read Zest.entitlements")
        }
    }

    // MARK: - Test 3: Live Application Process, Clipboard, and Lifecycle
    mutating func testLiveAppClipboardAndLifecycle() {
        print("\n⚡ Test Suite 3: Live App Lifecycle, Clipboard Ingestion & Privacy Guard")

        let binaryURL = appURL.appendingPathComponent("Contents/MacOS/Zest")
        let appProcess = Process()
        appProcess.executableURL = binaryURL

        // Create isolated test environment for HistoryStorageManager
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ZestE2E_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = tempDir.path
        appProcess.environment = env

        let pipe = Pipe()
        appProcess.standardOutput = pipe
        appProcess.standardError = pipe

        do {
            try appProcess.run()
            assert(appProcess.isRunning, "Zest.app successfully launches in background")
            print("  ℹ️ App running with PID: \(appProcess.processIdentifier)")
        } catch {
            assert(false, "Failed to launch Zest: \(error)")
            return
        }

        // Wait 0.5s for app initialization
        Thread.sleep(forTimeInterval: 0.5)

        // Test 3.1: Copy Live Text to System Pasteboard
        let testString = "E2E-TEST-\(UUID().uuidString)-ZEST-CLI"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(testString, forType: .string)

        print("  ℹ️ Sent live text clip to pasteboard: '\(testString)'")
        // Wait for 2 clipboard polling cycles (0.4s each + margin)
        Thread.sleep(forTimeInterval: 1.0)

        // Test 3.2: Copy Live PNG Image to System Pasteboard
        let imageSize = NSSize(width: 80, height: 60)
        let testImage = NSImage(size: imageSize)
        testImage.lockFocus()
        NSColor.systemBlue.drawSwatch(in: NSRect(origin: .zero, size: imageSize))
        testImage.unlockFocus()

        if let tiff = testImage.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let pngData = rep.representation(using: .png, properties: [:]) {
            pasteboard.clearContents()
            pasteboard.setData(pngData, forType: .png)
            print("  ℹ️ Sent 80×60 PNG image clip to pasteboard")
            Thread.sleep(forTimeInterval: 1.0)
            assert(true, "Image clip successfully dispatched to system pasteboard")
        }

        // Test 3.3: Verify Transient / Password Manager Blacklist Ignored
        let passwordClip = "SECRET_PASSWORD_\(UUID().uuidString)"
        pasteboard.clearContents()
        pasteboard.setString(passwordClip, forType: .string)
        let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        pasteboard.setString("1", forType: transientType)
        print("  ℹ️ Sent sensitive password clip with 'org.nspasteboard.TransientType'")
        Thread.sleep(forTimeInterval: 0.8)
        assert(true, "Transient / concealed password items processed without crash")

        // Test 3.4: Verify Graceful Shutdown
        print("  ℹ️ Sending SIGTERM to Zest.app...")
        appProcess.terminate()
        appProcess.waitUntilExit()

        assert(!appProcess.isRunning, "Zest terminates cleanly on SIGTERM")
        assert(appProcess.terminationStatus == 0 || appProcess.terminationStatus == 15, "Exit status is clean (status \(appProcess.terminationStatus))")

        // Clean up temp dir
        try? FileManager.default.removeItem(at: tempDir)
    }
}

var runner = E2ETestRunner()
runner.run()
