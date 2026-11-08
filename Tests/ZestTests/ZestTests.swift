import Testing
import Foundation
import AppKit
import Carbon
import SwiftUI
@testable import Zest

@Suite("Zest Data Transformation Tests")
struct DataTransformerTests {

    @Test("Prettify and Minify JSON")
    func testJSONTransformations() {
        let rawJSON = "{\"name\":\"Zest\",\"version\":1,\"tags\":[\"developer\",\"swift\"]}"
        
        let prettified = DataTransformer.prettifyJSON(rawJSON)
        #expect(prettified != nil)
        #expect(prettified!.contains("\n"))
        #expect(prettified!.contains("  \"name\" : \"Zest\""))

        let minified = DataTransformer.minifyJSON(prettified!)
        #expect(minified != nil)
        #expect(!minified!.contains("\n"))
        #expect(minified!.contains("\"version\":1"))
    }

    @Test("Case Conversions (camel, snake, kebab, pascal, constant)")
    func testCaseConversions() {
        let input = "user_account_identifier"

        #expect(DataTransformer.toCamelCase(input) == "userAccountIdentifier")
        #expect(DataTransformer.toPascalCase(input) == "UserAccountIdentifier")
        #expect(DataTransformer.toKebabCase(input) == "user-account-identifier")
        #expect(DataTransformer.toConstantCase(input) == "USER_ACCOUNT_IDENTIFIER")
        #expect(DataTransformer.toSnakeCase("userAccountIdentifier") == "user_account_identifier")
    }

    @Test("Base64 Encoding & Decoding")
    func testBase64() {
        let sample = "Zest: The 1-Tap Developer Clipboard"
        let encoded = DataTransformer.base64Encode(sample)
        #expect(DataTransformer.base64Decode(encoded) == sample)
    }

    @Test("Clean Text (Strip Markdown, Strip HTML, Whitespace, Dedupe)")
    func testCleanText() {
        let markdown = "# Title\nThis is **bold** and *italic* with a [link](https://zest.app)."
        let strippedMd = DataTransformer.stripMarkdown(markdown)
        #expect(!strippedMd.contains("**"))
        #expect(!strippedMd.contains("# "))
        #expect(strippedMd.contains("link"))

        let html = "<div class=\"code\"><code>const x = 10;</code></div>"
        let strippedHtml = DataTransformer.stripHTML(html)
        #expect(strippedHtml == "const x = 10;")

        let messyWhitespace = "  Hello   \n\n  world \t from   Zest!  "
        let collapsed = DataTransformer.collapseWhitespace(messyWhitespace)
        #expect(collapsed == "Hello world from Zest!")

        let multiline = "beta\nalpha\nbeta\ngamma\nalpha"
        let sortedDeduped = DataTransformer.sortAndDedupeLines(multiline)
        #expect(sortedDeduped == "alpha\nbeta\ngamma")
    }

    @Test("Acronym Case Conversions (getHTTPResponse, XMLParser)")
    func testAcronymCaseConversions() {
        #expect(DataTransformer.toCamelCase("getHTTPResponse") == "getHttpResponse")
        #expect(DataTransformer.toSnakeCase("getHTTPResponse") == "get_http_response")
        #expect(DataTransformer.toPascalCase("getHTTPResponse") == "GetHttpResponse")
        #expect(DataTransformer.toConstantCase("getHTTPResponse") == "GET_HTTP_RESPONSE")

        #expect(DataTransformer.toCamelCase("XMLParser") == "xmlParser")
        #expect(DataTransformer.toSnakeCase("XMLParser") == "xml_parser")
        #expect(DataTransformer.toKebabCase("XMLParser") == "xml-parser")
    }

    @Test("Multiline Markdown Stripping and Math Expression Preservation")
    func testMultilineMarkdownAndMath() {
        let md = "# Header 1\nBody text\n## Header 2\nMore body\n### Header 3"
        let stripped = DataTransformer.stripMarkdown(md)
        #expect(!stripped.contains("# Header 1"))
        #expect(!stripped.contains("## Header 2"))
        #expect(!stripped.contains("### Header 3"))
        #expect(stripped.contains("Header 1"))
        #expect(stripped.contains("Header 2"))
        #expect(stripped.contains("Header 3"))

        // Math expressions should not have asterisks stripped
        let math = "x * y * z = 100"
        let strippedMath = DataTransformer.stripMarkdown(math)
        #expect(strippedMath == "x * y * z = 100")
    }
}

@Suite("Zest Content Type Detection Tests")
struct ContentDetectionTests {

    @Test("Detect JSON")
    func testDetectJSON() {
        let jsonSample = "{\n  \"status\": 200,\n  \"success\": true\n}"
        #expect(ClipItem.detectType(for: jsonSample) == .json)
    }

    @Test("Detect SQL")
    func testDetectSQL() {
        let sqlSample = "SELECT id, email, created_at FROM users WHERE active = true ORDER BY id DESC;"
        #expect(ClipItem.detectType(for: sqlSample) == .sql)
    }

    @Test("Detect Hex Color")
    func testDetectHexColor() {
        #expect(ClipItem.detectType(for: "#3B82F6") == .color)
        #expect(ClipItem.detectType(for: "#FFF") == .color)
        #expect(ClipItem.detectType(for: "#10B981FF") == .color)
    }

    @Test("Detect URL")
    func testDetectURL() {
        #expect(ClipItem.detectType(for: "https://zest.dev/docs") == .url)
        #expect(ClipItem.detectType(for: "http://localhost:3000/api") == .url)
    }

    @Test("Detect Plain Text")
    func testDetectPlainText() {
        #expect(ClipItem.detectType(for: "Just a regular note to remember tomorrow.") == .text)
    }

    @Test("Image Clip Item Properties and Formatting")
    func testImageClipItem() {
        let fakeImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG header bytes
        let item = ClipItem(
            rawContent: "Image (800 × 600)",
            imageData: fakeImageData,
            imageWidth: 800,
            imageHeight: 600,
            sourceApp: "Safari",
            detectedType: .image
        )

        #expect(item.isImage)
        #expect(item.detectedType == .image)
        #expect(item.displayTitle == "Image (800 × 600)")
        #expect(item.formattedFileSize != nil)
        #expect(item.lineCount == 0)
    }

    @Test("Image Base64 Data URI Transformation")
    func testImageBase64DataURI() {
        let fakeImageData = "test-image".data(using: .utf8)!
        let uri = DataTransformer.imageBase64DataURI(pngData: fakeImageData)
        #expect(uri.hasPrefix("data:image/png;base64,"))
        #expect(uri.contains(fakeImageData.base64EncodedString()))
    }
}

@Suite("Zest Clipboard Management Tests")
@MainActor
struct ClipboardManagementTests {

    @Test("Add, Delete, and Clear All Clips")
    func testDeleteAndClearClips() {
        let engine = ClipboardEngine.shared
        engine.clearAll()
        #expect(engine.items.isEmpty)

        engine.add(text: "Clip 1: First item")
        engine.add(text: "Clip 2: Second item")
        engine.add(text: "Clip 3: Third item")

        #expect(engine.items.count == 3)
        #expect(engine.items.first?.rawContent == "Clip 3: Third item")

        // Delete specific clip
        let secondItemId = engine.items[1].id
        engine.delete(itemID: secondItemId)

        #expect(engine.items.count == 2)
        #expect(!engine.items.contains(where: { $0.id == secondItemId }))

        // Clean / Clear All
        engine.clearAll()
        #expect(engine.items.isEmpty)
    }

    @Test("Add, Deduplicate, and Manage Image Clips")
    func testImageClipsManagement() {
        let engine = ClipboardEngine.shared
        engine.clearAll()
        #expect(engine.items.isEmpty)

        let imgData1 = Data([0x89, 0x50, 0x4E, 0x47, 0x01])
        let imgData2 = Data([0x89, 0x50, 0x4E, 0x47, 0x02])

        engine.add(image: imgData1, width: 640, height: 480, sourceApp: "Preview")
        #expect(engine.items.count == 1)
        #expect(engine.items[0].isImage)
        #expect(engine.items[0].imageWidth == 640)
        #expect(engine.items[0].imageHeight == 480)
        #expect(engine.items[0].sourceApp == "Preview")

        // Add text clip
        engine.add(text: "Hello World")
        #expect(engine.items.count == 2)
        #expect(!engine.items[0].isImage)
        #expect(engine.items[1].isImage)

        // Add second image
        engine.add(image: imgData2, width: 1920, height: 1080, sourceApp: "Figma")
        #expect(engine.items.count == 3)
        #expect(engine.items[0].isImage)
        #expect(engine.items[0].imageWidth == 1920)

        // Re-add first image -> deduplicates and moves to top (LRU)
        engine.add(image: imgData1, width: 640, height: 480, sourceApp: "Preview")
        #expect(engine.items.count == 3)
        #expect(engine.items[0].imageData == imgData1)
        #expect(engine.items[0].copyCount == 2)

        // Delete image clip
        let imageId = engine.items[0].id
        engine.delete(itemID: imageId)
        #expect(engine.items.count == 2)
        #expect(!engine.items.contains(where: { $0.id == imageId }))

        engine.clearAll()
        #expect(engine.items.isEmpty)
    }
}

@Suite("Zest State & Synchronization Tests")
@MainActor
struct ZestStateTests {

    @Test("Search Filtering and Filtered Items Synchronization")
    func testSearchFilterAndStateSync() {
        let engine = ClipboardEngine.shared
        let state = ZestState.shared

        engine.clearAll()
        state.resetAll()

        engine.add(text: "SELECT * FROM users")
        engine.add(text: "export GITHUB_TOKEN=abc")
        engine.add(text: "SELECT email FROM accounts")
        engine.add(text: "#3B82F6")

        #expect(state.filteredItems.count == 4)

        // Filter for SQL
        state.searchText = "SELECT"
        #expect(state.filteredItems.count == 2)
        #expect(state.filteredItems[0].rawContent == "SELECT email FROM accounts")
        #expect(state.filteredItems[1].rawContent == "SELECT * FROM users")

        // Reset search
        state.resetAll()
        #expect(state.searchText.isEmpty)
        #expect(state.filteredItems.count == 4)

        // Selection & transform reset
        state.selectedItem = state.filteredItems[0]
        state.transformedPreview = "Preview Output"
        state.resetTransform()
        #expect(state.selectedItem == nil)
        #expect(state.transformedPreview == nil)

        engine.clearAll()
    }
}

@Suite("Zest History Storage & Persistence Tests")
@MainActor
struct HistoryStorageTests {

    @Test("HistoryStorageManager JSON Serialization and Loading")
    func testPersistenceSaveAndLoad() {
        let storage = HistoryStorageManager.shared
        storage.isPersistenceEnabled = true

        let item1 = ClipItem(rawContent: "Test snippet 1", sourceApp: "Xcode")
        let item2 = ClipItem(rawContent: "Test snippet 2", isPinned: true)

        storage.save(items: [item1, item2])
        let loaded = storage.load()

        #expect(loaded.count == 2)
        #expect(loaded[0].rawContent == "Test snippet 1")
        #expect(loaded[0].sourceApp == "Xcode")
        #expect(loaded[1].rawContent == "Test snippet 2")
        #expect(loaded[1].isPinned == true)

        // Clean up
        storage.clearDiskCache()
    }

    @Test("Ephemeral RAM-Only Mode Disables Disk Writes")
    func testEphemeralMode() {
        let storage = HistoryStorageManager.shared
        storage.isPersistenceEnabled = false

        let item = ClipItem(rawContent: "Secret Private Key")
        storage.save(items: [item])

        let loaded = storage.load()
        #expect(loaded.isEmpty)

        // Restore default
        storage.isPersistenceEnabled = true
    }
}

@Suite("Zest Pinning & Formatting Tests")
@MainActor
struct PinningAndFormattingTests {

    @Test("Toggle Pin on Clipboard Items")
    func testPinningClips() {
        let engine = ClipboardEngine.shared
        engine.clearAll()

        engine.add(text: "Persistent Boilerplate")
        engine.add(text: "Ephemeral Temp Text")

        let targetID = engine.items[1].id
        #expect(!engine.items[1].isPinned)

        engine.togglePin(for: targetID)
        #expect(engine.items[1].isPinned)

        engine.togglePin(for: targetID)
        #expect(!engine.items[1].isPinned)

        engine.clearAll()
    }

    @Test("Strip Formatting for Plain-Text Paste")
    func testStripFormatting() {
        let richText = "# Title\nHere is <b>bold</b> and [link](https://example.com) with `code`."
        let stripped = DataTransformer.stripFormatting(richText)

        #expect(!stripped.contains("# "))
        #expect(!stripped.contains("<b>"))
        #expect(!stripped.contains("</b>"))
        #expect(!stripped.contains("[link]"))
        #expect(!stripped.contains("`code`"))
        #expect(stripped.contains("Title"))
        #expect(stripped.contains("bold"))
        #expect(stripped.contains("link"))
        #expect(stripped.contains("code"))
    }

    @Test("HUDPosition Enum Coverage")
    func testHUDPositions() {
        #expect(HUDPosition.cursor.title == "Near Mouse Cursor")
        #expect(HUDPosition.center.title == "Screen Center")
        #expect(HUDPosition.statusBar.title == "Under Menu Bar Icon")
    }
}

@Suite("Zest Menu Bar Icon Tests")
struct MenuBarIconTests {
    @Test("Menu Bar Icon Styles Coverage and Generation")
    @MainActor
    func testMenuBarIconStyles() {
        for style in MenuBarIconStyle.allCases {
            let icon = MenuBarIconProvider.makeIcon(style: style)
            #expect(icon.size.width > 0)
            #expect(icon.size.height > 0)
            #expect(icon.isTemplate == true)
            #expect(!style.title.isEmpty)
        }
    }
}

@Suite("Zest StoreKit & Monetization Tests")
@MainActor
struct StoreKitTests {
    @Test("StoreKitManager Singleton and Default Status")
    func testStoreKitManagerInit() async {
        let manager = StoreKitManager.shared
        #expect(StoreKitManager.defaultProProductID == "app.zest.pro.lifetime")
        await manager.refreshPurchaseStatus()
        // In DEBUG, isProUnlocked should be true for local developer testing
        #if DEBUG
        #expect(manager.isProUnlocked == true)
        #endif
    }
}

@Suite("Zest Paste Engine & Preferences Tests")
@MainActor
struct PasteEngineTests {
    @Test("Default Preferences Registration and Auto-Paste Default")
    func testAutoPasteDefault() {
        UserDefaults.standard.register(defaults: [
            "zest_autoPasteKeystroke": true,
            HistoryStorageManager.persistenceKey: true,
            HistoryStorageManager.maxHistoryKey: 100
        ])
        #expect(PasteEngine.isAutoPasteEnabled == true)

        UserDefaults.standard.set(false, forKey: "zest_autoPasteKeystroke")
        #expect(PasteEngine.isAutoPasteEnabled == false)

        UserDefaults.standard.set(true, forKey: "zest_autoPasteKeystroke")
        #expect(PasteEngine.isAutoPasteEnabled == true)
    }

    @Test("Ignored App Bundle IDs Synchronization (zest_ignoredAppBundleIDs)")
    func testIgnoredAppsSync() {
        UserDefaults.standard.set(["com.agilebits.onepassword"], forKey: "zest_ignoredAppBundleIDs")
        #expect(ClipboardEngine.shared.isAppIgnored(bundleID: "com.agilebits.onepassword") == true)
        #expect(ClipboardEngine.shared.isAppIgnored(bundleID: "com.apple.Safari") == false)
        UserDefaults.standard.removeObject(forKey: "zest_ignoredAppBundleIDs")
    }

    @Test("PasteEngine Target Application Tracking")
    func testTargetApplicationTracking() {
        let currentApp = NSRunningApplication.current
        PasteEngine.targetApplication = currentApp
        #expect(PasteEngine.targetApplication?.bundleIdentifier == currentApp.bundleIdentifier)
    }

    @Test("PreferencesView Tab Enum and Initialization")
    @MainActor
    func testPreferencesTabs() {
        #expect(PreferencesView.Tab.allCases.count == 5)
        #expect(PreferencesView.Tab.general.title == "General")
        #expect(PreferencesView.Tab.history.title == "History")
        #expect(PreferencesView.Tab.privacy.title == "Privacy")
        #expect(PreferencesView.Tab.appearance.title == "Appearance")
        #expect(PreferencesView.Tab.guide.title == "Guide")

        let prefGeneral = PreferencesView(initialTab: .general)
        _ = prefGeneral.body
        let prefGuide = PreferencesView(initialTab: .guide)
        _ = prefGuide.body
    }
}

@Suite("Zest Fuzzy Matching Tests")
struct FuzzyMatchingTests {
    @Test("Subsequence Fuzzy Matching")
    func testFuzzyMatching() {
        // Exact and prefix matching
        let match1 = FuzzyMatcher.match(query: "zst", in: "Zest")
        #expect(match1.matched == true)
        #expect(match1.score > 0)

        // Subsequence matching across word boundaries
        let match2 = FuzzyMatcher.match(query: "dburl", in: "export DATABASE_URL=postgres://localhost")
        #expect(match2.matched == true)
        #expect(match2.score > 20)

        // Non-matching subsequence
        let match3 = FuzzyMatcher.match(query: "xyz", in: "export DATABASE_URL")
        #expect(match3.matched == false)
        #expect(match3.score == 0)

        // Empty query matches everything
        let match4 = FuzzyMatcher.match(query: "", in: "anything")
        #expect(match4.matched == true)
    }
}

@Suite("Zest Expanded Language Detection Tests")
struct ExpandedLanguageDetectionTests {
    @Test("Detect Python Code")
    func testPythonDetection() {
        let pythonSnippet = "def calculate_total(items):\n    print(items)\n    return sum(items)"
        #expect(ClipItem.detectType(for: pythonSnippet) == .python)
    }

    @Test("Detect TypeScript Code")
    func testTypeScriptDetection() {
        let tsSnippet = "interface UserProfile {\n  id: string;\n  name: string;\n}\nexport default UserProfile;"
        #expect(ClipItem.detectType(for: tsSnippet) == .typescript)
    }

    @Test("Detect Go Code")
    func testGoDetection() {
        let goSnippet = "package main\n\nfunc main() {\n    fmt.Println(\"Zest\")\n}"
        #expect(ClipItem.detectType(for: goSnippet) == .golang)
    }

    @Test("Detect Rust Code")
    func testRustDetection() {
        let rustSnippet = "pub fn execute_stream() -> Result<(), Error> {\n    let mut buffer = Vec::new();\n    println!(\"ready\");\n}"
        #expect(ClipItem.detectType(for: rustSnippet) == .rust)
    }

    @Test("Detect HTML Markup")
    func testHTMLDetection() {
        let htmlSnippet = "<!DOCTYPE html>\n<html>\n<body>\n<div>Zest HUD</div>\n</body>\n</html>"
        #expect(ClipItem.detectType(for: htmlSnippet) == .html)
    }

    @Test("Detect YAML Configuration")
    func testYAMLDetection() {
        let yamlSnippet = "---\nversion: \"3.8\"\nservices:\n  app:\n    image: redis:alpine"
        #expect(ClipItem.detectType(for: yamlSnippet) == .yaml)
    }
}

@Suite("Zest Localization Tests")
@MainActor
struct LocalizationTests {
    @Test("Language Translations for All Keys")
    func testTranslations() {
        let l10n = L10n.shared
        
        // English
        l10n.currentLanguage = AppLanguage.english.rawValue
        #expect(l10n.tr(.tapToPasteFooter) == "Tap 1–10 to paste")
        #expect(l10n.tr(.clearAll) == "Clear All")
        #expect(l10n.tr(.quit) == "Quit")
        #expect(l10n.tr(.appearanceTab) == "Appearance")
        #expect(l10n.tr(.guideTab) == "Guide")
        #expect(l10n.tr(.captureScreenText) == "Capture Screen Text (⌘⇧2)")

        // Chinese
        l10n.currentLanguage = AppLanguage.chinese.rawValue
        #expect(l10n.tr(.tapToPasteFooter) == "按 1–10 立即粘贴")
        #expect(l10n.tr(.clearAll) == "清空全部")
        #expect(l10n.tr(.quit) == "退出")
        #expect(l10n.tr(.appearanceTab) == "外观")
        #expect(l10n.tr(.guideTab) == "指南")
        #expect(l10n.tr(.captureScreenText) == "捕获屏幕文本 (⌘⇧2)")

        // Japanese
        l10n.currentLanguage = AppLanguage.japanese.rawValue
        #expect(l10n.tr(.tapToPasteFooter) == "1–10 キーで即座にペースト")
        #expect(l10n.tr(.clearAll) == "すべて消去")
        #expect(l10n.tr(.quit) == "終了")
        #expect(l10n.tr(.appearanceTab) == "外観")
        #expect(l10n.tr(.guideTab) == "ガイド")
        #expect(l10n.tr(.captureScreenText) == "画面のテキストをキャプチャ (⌘⇧2)")

        // Reset to system default
        l10n.currentLanguage = AppLanguage.system.rawValue
    }
}

@Suite("Zest Custom Shortcut & KeyCombo Tests")
struct CustomShortcutTests {
    @Test("KeyCombo Defaults and Serialization")
    func testKeyComboDefaults() throws {
        let defaultAct = KeyCombo.defaultActivation
        #expect(defaultAct.keyCode == 9)
        #expect(defaultAct.displayString == "⌘ + ⇧ + V")

        let defaultOCR = KeyCombo.defaultOCR
        #expect(defaultOCR.keyCode == 19)
        #expect(defaultOCR.displayString == "⌘ + ⇧ + 2")

        let encoded = try JSONEncoder().encode(defaultAct)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: encoded)
        #expect(decoded == defaultAct)
    }

    @Test("KeyCombo Load and Save Persistence")
    func testKeyComboPersistence() {
        let testKey = "zest_test_shortcut_persistence"
        let customCombo = KeyCombo(keyCode: 31, modifiers: 0x0900, displayString: "⌃ + ⌘ + O")
        customCombo.save(forKey: testKey)

        let loaded = KeyCombo.load(forKey: testKey, default: .defaultActivation)
        #expect(loaded == customCombo)
        #expect(loaded.displayString == "⌃ + ⌘ + O")

        UserDefaults.standard.removeObject(forKey: testKey)
        let fallback = KeyCombo.load(forKey: testKey, default: .defaultActivation)
        #expect(fallback == .defaultActivation)
    }

    @Test("KeyCodeHelper String Mappings")
    func testKeyCodeHelper() {
        #expect(KeyCodeHelper.string(for: 49, characters: " ") == "Space")
        #expect(KeyCodeHelper.string(for: 36, characters: "\r") == "↩")
        #expect(KeyCodeHelper.string(for: 53, characters: nil) == "⎋")
        #expect(KeyCodeHelper.string(for: 48, characters: "\t") == "⇥")
        #expect(KeyCodeHelper.string(for: 9, characters: "v") == "V")
        #expect(KeyCodeHelper.string(for: 19, characters: "2") == "2")
    }

    @Test("ShortcutConflictChecker Detection and Warnings")
    func testShortcutConflictChecker() {
        let cmd = UInt32(cmdKey)
        let shift = UInt32(shiftKey)
        let opt = UInt32(optionKey)

        // 1. Blocked: System copy (⌘C) and paste (⌘V)
        let copyCombo = KeyCombo(keyCode: 8, modifiers: cmd, displayString: "⌘ + C")
        #expect(ShortcutConflictChecker.check(combo: copyCombo, storageKey: KeyCombo.activationKey) == .blocked(reason: "Reserved for Copy (⌘C)"))

        let pasteCombo = KeyCombo(keyCode: 9, modifiers: cmd, displayString: "⌘ + V")
        #expect(ShortcutConflictChecker.check(combo: pasteCombo, storageKey: KeyCombo.activationKey) == .blocked(reason: "Reserved for Paste (⌘V)"))

        // 2. Blocked: Internal collision (assigning OCR default to activation)
        let ocrCollision = KeyCombo(keyCode: 19, modifiers: cmd | shift, displayString: "⌘ + ⇧ + 2")
        #expect(ShortcutConflictChecker.check(combo: ocrCollision, storageKey: KeyCombo.activationKey) == .blocked(reason: "Already assigned to Screen OCR"))

        // 3. Warnings: Spotlight (⌘Space), macOS screenshot (⌘⇧4), Finder move (⌥⌘V)
        let spotlight = KeyCombo(keyCode: 49, modifiers: cmd, displayString: "⌘ + Space")
        #expect(ShortcutConflictChecker.check(combo: spotlight, storageKey: KeyCombo.activationKey) == .warning(reason: "Conflicts with Spotlight Search (⌘Space)"))

        let screenshot = KeyCombo(keyCode: 21, modifiers: cmd | shift, displayString: "⌘ + ⇧ + 4")
        #expect(ShortcutConflictChecker.check(combo: screenshot, storageKey: KeyCombo.activationKey) == .warning(reason: "Conflicts with macOS Area Capture (⌘⇧4)"))

        let finderMove = KeyCombo(keyCode: 9, modifiers: opt | cmd, displayString: "⌥ + ⌘ + V")
        #expect(ShortcutConflictChecker.check(combo: finderMove, storageKey: KeyCombo.activationKey) == .warning(reason: "Conflicts with Finder Move / Paste & Match Style (⌥⌘V)"))

        // 4. Clean shortcut
        let cleanCombo = KeyCombo(keyCode: 31, modifiers: cmd | shift, displayString: "⌘ + ⇧ + O")
        #expect(ShortcutConflictChecker.check(combo: cleanCombo, storageKey: KeyCombo.activationKey) == nil)
    }
}

@MainActor
struct ScreenOCRTests {
    @MainActor
    private func createTextImage(text: String, size: CGSize = CGSize(width: 300, height: 100)) -> CGImage? {
        let nsImage = NSImage(size: size)
        nsImage.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 28),
            .foregroundColor: NSColor.black
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        attrString.draw(at: NSPoint(x: 20, y: 30))
        nsImage.unlockFocus()

        return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    @Test("Recognize Text from Synthetically Rendered Image")
    func testRecognizeText() throws {
        let sample = "ZEST OCR"
        guard let cgImage = createTextImage(text: sample) else {
            Issue.record("Failed to create test image")
            return
        }

        let result = try ScreenOCRService.shared.recognizeText(from: cgImage)
        #expect(result != nil)
        #expect(result?.contains("ZEST") == true)
    }

    @Test("Empty or Blank Image Returns Nil")
    func testBlankImageReturnsNil() throws {
        let nsImage = NSImage(size: CGSize(width: 50, height: 50))
        nsImage.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 50, height: 50).fill()
        nsImage.unlockFocus()
        let blankImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!

        let result = try ScreenOCRService.shared.recognizeText(from: blankImage)
        #expect(result == nil)
    }
}



