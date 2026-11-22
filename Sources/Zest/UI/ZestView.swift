import SwiftUI
import AppKit

// MARK: - App Theme Option
public enum AppTheme: String, CaseIterable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    public var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    public var title: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var next: AppTheme {
        switch self {
        case .system: return .light
        case .light: return .dark
        case .dark: return .system
        }
    }
}

public extension Notification.Name {
    static let themeDidChange = Notification.Name("app.zest.themeDidChange")
}

// MARK: - Zest Brand Palette
public enum ZestPalette {
    /// Electric Tang (#FF6B00) — primary brand accent, active focus, and rail highlights
    public static let tang = Color(red: 1.0, green: 0.42, blue: 0.0)
    /// Warm Orange (#FF7A18) — top gradient stop for solid CTAs and active pills
    public static let warmOrange = Color(red: 1.0, green: 0.478, blue: 0.094)
    /// Burnt Orange (#EA580C) — bottom gradient stop for >= 4.5:1 white text legibility
    public static let burntOrange = Color(red: 0.918, green: 0.345, blue: 0.047)
    /// Citrus Glow (#FF8A00) — subtle HUD top rim and ambient bloom
    public static let citrusGlow = Color(red: 1.0, green: 0.541, blue: 0.0)
    /// Golden Amber (#F59E0B) — pinned section headers and warm secondary highlights
    public static let amber = Color(red: 0.961, green: 0.620, blue: 0.043)

    public static var ctaGradient: LinearGradient {
        LinearGradient(
            colors: [warmOrange, burntOrange],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public static var activeRowWash: LinearGradient {
        LinearGradient(
            colors: [tang.opacity(0.16), amber.opacity(0.06)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Visual Effect View
public struct VisualEffectView: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode
    public var appearance: NSAppearance?

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        appearance: NSAppearance? = nil
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.appearance = appearance
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.appearance = appearance
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.appearance = appearance
    }
}

// MARK: - Main Liquid Glass Zest View
public struct ZestView: View {
    @ObservedObject var engine = ClipboardEngine.shared
    @ObservedObject var state = ZestState.shared
    @ObservedObject var l10n = L10n.shared
    @AppStorage("zest_theme") private var themeRawValue: String = AppTheme.system.rawValue
    @AppStorage("zest_showShortcuts") private var showShortcuts: Bool = true
    @State private var hasAccessibility: Bool = PasteEngine.hasAccessibilityPermission
    @FocusState private var isSearchFocused: Bool

    public var onDismiss: () -> Void

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    private var currentTheme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }

    private func toggleTheme() {
        let next = currentTheme.next
        themeRawValue = next.rawValue
        NotificationCenter.default.post(name: .themeDidChange, object: next)
    }

    var filteredItems: [ClipItem] {
        state.filteredItems
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // Subtle top citrus ambient bloom matching Zest brand glow
            RadialGradient(
                colors: [ZestPalette.citrusGlow.opacity(0.16), ZestPalette.citrusGlow.opacity(0.03), .clear],
                center: .top,
                startRadius: 12,
                endRadius: 210
            )
            .frame(height: 120)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Liquid Glass Search Header
                searchHeader
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                if !hasAccessibility {
                    accessibilityBanner
                }

                // Glass Light Refraction Line
                glassDivider

                // Main Content Area
                if let item = state.selectedItem {
                    if item.isImage {
                        imageDetailDeck(for: item)
                    } else {
                        transformDeck(for: item)
                    }
                } else if let preview = state.previewItem {
                    quickLookDeck(for: preview)
                } else {
                    clipList
                }

                // Glass Light Refraction Line
                glassDivider

                // Liquid Glass Footer
                footerBar
            }
        }
        .frame(width: 390)
        .frame(minHeight: 160, maxHeight: 380)
        .preferredColorScheme(currentTheme.colorScheme)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, appearance: currentTheme.nsAppearance)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [ZestPalette.citrusGlow.opacity(0.36), Color.primary.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            hasAccessibility = PasteEngine.hasAccessibilityPermission
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = PasteEngine.hasAccessibilityPermission
        }
    }

    // MARK: - Molded Glass Search Bar
    private var searchHeader: some View {
        let isSearchActive = isSearchFocused || !state.searchText.isEmpty

        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ZestPalette.tang)
                .font(.system(size: 13, weight: .semibold))

            TextField(l10n.tr(.searchPlaceholder), text: $state.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.primary)
                .focused($isSearchFocused)

            if !state.searchText.isEmpty {
                Button(action: { state.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 2.5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("ZEST")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.4)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(ZestPalette.ctaGradient)
                )
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    ZestPalette.tang.opacity(isSearchActive ? 0.60 : 0.30),
                    lineWidth: isSearchActive ? 1.0 : 0.75
                )
        )
        .shadow(color: isSearchActive ? ZestPalette.tang.opacity(0.18) : .clear, radius: 5, y: 0)
    }

    // MARK: - Accessibility Warning Banner
    private var accessibilityBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 11))

            Text("Accessibility needed to paste directly")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            Button(action: {
                PasteEngine.openAccessibilityPreferences()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    hasAccessibility = PasteEngine.hasAccessibilityPermission
                }
            }) {
                Text("Enable")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.orange)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.16))
    }

    // MARK: - Refined Divider
    private var glassDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: 0.75)
    }

    // MARK: - Clips List
    private var clipList: some View {
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clipboard")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(state.searchText.isEmpty ? l10n.tr(.emptyClipboard) : l10n.tr(.noResults))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        if state.searchText.isEmpty && engine.items.contains(where: \.isPinned) {
                            let pinned = engine.items.filter(\.isPinned)
                            let recent = engine.items.filter { !$0.isPinned }

                            if !pinned.isEmpty {
                                sectionHeader(title: l10n.tr(.pinnedSection), isAccent: true)
                                ForEach(Array(pinned.enumerated()), id: \.element.id) { index, item in
                                    LiquidClipRow(
                                        item: item,
                                        shortcutBadge: showShortcuts ? "⌥\(index + 1)" : nil,
                                        isHighlighted: state.highlightedIndex == index,
                                        onPaste: {
                                            PasteEngine.paste(item: item, dismissHUD: onDismiss)
                                        },
                                        onPreview: {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                state.previewItem = item
                                            }
                                        },
                                        onOpenTransform: {
                                            state.selectedItem = item
                                        },
                                        onTogglePin: {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                engine.togglePin(for: item.id)
                                            }
                                        },
                                        onDelete: {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                engine.delete(itemID: item.id)
                                            }
                                        },
                                        onDismiss: onDismiss
                                    )
                                }
                            }

                            if !recent.isEmpty {
                                sectionHeader(title: l10n.tr(.recentSection))
                                ForEach(Array(recent.prefix(10).enumerated()), id: \.element.id) { index, item in
                                    LiquidClipRow(
                                        item: item,
                                        shortcutBadge: showShortcuts ? (index == 9 ? "0" : "\(index + 1)") : nil,
                                        isHighlighted: state.highlightedIndex == index,
                                        onPaste: {
                                            PasteEngine.paste(item: item, dismissHUD: onDismiss)
                                        },
                                        onPreview: {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                state.previewItem = item
                                            }
                                        },
                                        onOpenTransform: {
                                            state.selectedItem = item
                                        },
                                        onTogglePin: {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                engine.togglePin(for: item.id)
                                            }
                                        },
                                        onDelete: {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                engine.delete(itemID: item.id)
                                            }
                                        },
                                        onDismiss: onDismiss
                                    )
                                }
                            }
                        } else {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                LiquidClipRow(
                                    item: item,
                                    shortcutBadge: showShortcuts ? (index == 9 ? "0" : (index < 9 ? "\(index + 1)" : nil)) : nil,
                                    isHighlighted: state.highlightedIndex == index,
                                    onPaste: {
                                        PasteEngine.paste(item: item, dismissHUD: onDismiss)
                                    },
                                    onPreview: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            state.previewItem = item
                                        }
                                    },
                                    onOpenTransform: {
                                        state.selectedItem = item
                                    },
                                    onTogglePin: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            engine.togglePin(for: item.id)
                                        }
                                    },
                                    onDelete: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            engine.delete(itemID: item.id)
                                        }
                                    },
                                    onDismiss: onDismiss
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                }
            }
        }
    }

    private func sectionHeader(title: String, isAccent: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isAccent ? ZestPalette.amber : .secondary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.top, 4)
                .padding(.bottom, 2)
            Spacer()
        }
    }

    // MARK: - Liquid Glass Transform Deck
    private func transformDeck(for item: ClipItem) -> some View {
        VStack(spacing: 8) {
            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryPill(nil, title: "All")
                    ForEach(TransformCategory.allCases, id: \.self) { cat in
                        categoryPill(cat, title: cat.rawValue)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
            }

            // Transform Actions Carousel
            let actions = DataTransformer.availableActions.filter {
                state.selectedCategory == nil || $0.category == state.selectedCategory
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(actions) { action in
                        let isActive = state.activeTransform?.id == action.id
                        Button(action: { applyTransform(action, to: item) }) {
                            Text(action.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isActive ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isActive ? AnyShapeStyle(ZestPalette.ctaGradient) : AnyShapeStyle(Color.primary.opacity(0.08)))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(
                                            isActive ? Color.white.opacity(0.4) : Color.primary.opacity(0.12),
                                            lineWidth: 0.75
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Transform: \(action.name)")
                    }
                }
                .padding(.horizontal, 10)
            }

            // Inset Dark Glass Code Preview Box
            ScrollView {
                if let preview = state.transformedPreview {
                    Text(preview)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(8)
                        .textSelection(.enabled)
                } else if let action = state.activeTransform {
                    Text("⚠️ Unable to \(action.name) for this content")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(8)
                } else {
                    Text(item.rawContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(8)
                        .textSelection(.enabled)
                }
            }
            .frame(maxHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(ZestPalette.citrusGlow.opacity(0.24), lineWidth: 0.75)
            )
            .padding(.horizontal, 10)

            // Liquid Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        engine.delete(itemID: item.id)
                        state.resetTransform()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.9))
                        .frame(width: 32, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red.opacity(0.16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.4), lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)
                .help("Delete clip from history")

                Button(action: {
                    let target = state.transformedPreview ?? item.rawContent
                    PasteEngine.copyOnly(text: target, dismissHUD: onDismiss)
                }) {
                    Text("Copy")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)

                Button(action: {
                    let target = state.transformedPreview ?? item.rawContent
                    PasteEngine.paste(text: target, dismissHUD: onDismiss)
                }) {
                    HStack(spacing: 4) {
                        Text("Paste")
                        Text("↵")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ZestPalette.ctaGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    private func categoryPill(_ cat: TransformCategory?, title: String) -> some View {
        let isSelected = state.selectedCategory == cat
        return Button(action: { state.selectedCategory = cat }) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(ZestPalette.ctaGradient) : AnyShapeStyle(Color.primary.opacity(0.08)))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.white.opacity(0.4) : Color.primary.opacity(0.12), lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Category: \(title)")
    }

    private func applyTransform(_ action: TransformAction, to item: ClipItem) {
        state.activeTransform = action
        if let result = action.execute(item.rawContent) {
            state.transformedPreview = result
        } else {
            state.transformedPreview = nil
        }
    }

    // MARK: - Liquid Glass Image Detail Deck
    private func imageDetailDeck(for item: ClipItem) -> some View {
        VStack(spacing: 8) {
            // Quick Action Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if let data = item.imageData {
                        let hasTransformPreview = state.transformedPreview != nil
                        Button(action: {
                            state.transformedPreview = DataTransformer.imageBase64DataURI(pngData: data)
                        }) {
                            Text("Base64 Data URI")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(hasTransformPreview ? .white : .primary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(hasTransformPreview ? AnyShapeStyle(ZestPalette.ctaGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(hasTransformPreview ? Color.white.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 0.75)
                                )
                        }
                        .buttonStyle(.plain)

                        if let w = item.imageWidth, let h = item.imageHeight {
                            Button(action: {
                                state.transformedPreview = "width: \(w)px; height: \(h)px;"
                            }) {
                                Text("CSS Size")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75))
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                state.transformedPreview = "\(w) × \(h) px"
                            }) {
                                Text("\(w) × \(h)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
            }

            // Image Preview Box or Transformed Text Box
            if let text = state.transformedPreview {
                VStack(spacing: 4) {
                    HStack {
                        Text("Transformed Output")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Show Image") {
                            state.transformedPreview = nil
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ZestPalette.tang)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)

                    ScrollView {
                        Text(text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(8)
                            .textSelection(.enabled)
                    }
                    .frame(height: 125)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(ZestPalette.citrusGlow.opacity(0.24), lineWidth: 0.75)
                    )
                    .padding(.horizontal, 10)
                }
            } else if let data = item.imageData {
                if let nsImage = NSImage(data: data) {
                    VStack(spacing: 6) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 125)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.75)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 1.5)

                        HStack(spacing: 10) {
                            if let w = item.imageWidth, let h = item.imageHeight {
                                Label("\(w) × \(h)", systemImage: "aspectratio")
                            }
                            if let size = item.formattedFileSize {
                                Label(size, systemImage: "doc.text.image")
                            }
                            if let app = item.sourceApp {
                                Label(app, systemImage: "app")
                            }
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        Text("Unsupported or corrupted image format")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 90)
                    .padding(.vertical, 8)
                }
            }

            // Bottom Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        engine.delete(itemID: item.id)
                        state.resetTransform()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.9))
                        .frame(width: 32, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red.opacity(0.16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.4), lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)
                .help("Delete clip from history")

                Button(action: {
                    if let text = state.transformedPreview {
                        PasteEngine.copyOnly(text: text, dismissHUD: onDismiss)
                    } else if let data = item.imageData {
                        PasteEngine.copyImageOnly(data: data, dismissHUD: onDismiss)
                    }
                }) {
                    Text("Copy")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let text = state.transformedPreview {
                        PasteEngine.paste(text: text, dismissHUD: onDismiss)
                    } else if let data = item.imageData {
                        PasteEngine.pasteImage(data: data, dismissHUD: onDismiss)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Paste")
                        Text("↵")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ZestPalette.ctaGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Liquid Glass Quick Look Deck
    private func quickLookDeck(for item: ClipItem) -> some View {
        VStack(spacing: 8) {
            // Header bar
            HStack(spacing: 8) {
                Text(item.detectedType.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(item.detectedType.systemColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(item.detectedType.systemColor.opacity(0.18))
                    .cornerRadius(4)

                if let app = item.sourceApp, !app.isEmpty {
                    Text(app)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if item.isImage {
                    if let w = item.imageWidth, let h = item.imageHeight {
                        Text("\(w) × \(h) px")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("\(item.lineCount) lines • \(item.characterCount) chars")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)

            // Content body
            if item.isImage, let data = item.imageData {
                if let nsImage = NSImage(data: data) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 300, maxHeight: 180)
                            .cornerRadius(6)
                            .padding(4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 190)
                    .background(Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(ZestPalette.citrusGlow.opacity(0.22), lineWidth: 0.75)
                    )
                    .cornerRadius(6)
                    .padding(.horizontal, 10)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        Text("Unsupported or corrupted image format")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .padding(.horizontal, 10)
                }
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(item.rawContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 210)
                .background(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(ZestPalette.citrusGlow.opacity(0.22), lineWidth: 0.75)
                )
                .cornerRadius(6)
                .padding(.horizontal, 10)
            }

            // Quick actions
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        state.previewItem = nil
                    }
                }) {
                    Text("Close (Space)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    if item.isImage, let data = item.imageData {
                        PasteEngine.copyImageOnly(data: data, dismissHUD: onDismiss)
                    } else {
                        PasteEngine.copyOnly(text: item.rawContent, dismissHUD: onDismiss)
                    }
                }) {
                    Text("Copy")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.10)))
                }
                .buttonStyle(.plain)

                Button(action: {
                    PasteEngine.paste(item: item, dismissHUD: onDismiss)
                }) {
                    HStack(spacing: 4) {
                        Text("Paste")
                        Text("↵").font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ZestPalette.ctaGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Refined Footer Bar
    private var footerBar: some View {
        HStack(spacing: 8) {
            if state.selectedItem != nil || state.previewItem != nil {
                BackButton {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        state.resetTransform()
                        state.previewItem = nil
                    }
                }
            } else {
                Text(l10n.tr(.tapToPasteFooter))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize()

                if !engine.items.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.4))
                        .font(.system(size: 9))

                    if state.confirmingClearAll {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                engine.clearAll()
                                state.confirmingClearAll = false
                            }
                        }) {
                            Text(l10n.tr(.confirmClear))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            state.confirmingClearAll = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                state.confirmingClearAll = false
                            }
                        }) {
                            Text(l10n.tr(.clearAll))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .buttonStyle(.plain)
                        .help("Clear all clips from history")
                    }
                }
            }

            Spacer(minLength: 8)

            // Right Utility Group (Uniform 22x22 circle buttons)
            HStack(spacing: 6) {
                // Theme Toggle Button
                FooterCircleButton(
                    systemName: currentTheme.iconName,
                    isEmphasized: true,
                    helpText: "Theme: \(currentTheme.title) (Click to switch)",
                    accessibilityLabel: "Theme switcher, currently \(currentTheme.title)"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleTheme()
                    }
                }

                // Screen Text OCR Button
                FooterCircleButton(
                    systemName: "text.viewfinder",
                    helpText: l10n.tr(.captureScreenText),
                    accessibilityLabel: l10n.tr(.captureScreenText)
                ) {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        Task {
                            await ScreenOCRService.shared.captureAndRecognize()
                        }
                    }
                }

                // Shortcuts & Guide Button
                FooterCircleButton(
                    systemName: "questionmark.circle.fill",
                    helpText: "Keyboard Shortcuts & Guide",
                    accessibilityLabel: "Keyboard Shortcuts and Guide"
                ) {
                    onDismiss()
                    GuideWindowController.shared.showWindow()
                }

                // Preferences Button
                FooterCircleButton(
                    systemName: "gearshape.fill",
                    helpText: "Open Preferences (⌘,)",
                    accessibilityLabel: "Preferences"
                ) {
                    onDismiss()
                    SettingsWindowController.shared.showWindow()
                }

                // Quit Button
                FooterCircleButton(
                    systemName: "power",
                    iconSize: 10,
                    iconWeight: .bold,
                    helpText: l10n.tr(.quit),
                    accessibilityLabel: l10n.tr(.quit)
                ) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
    }
}

// MARK: - Liquid Glass Clip Row
struct LiquidClipRow: View {
    let item: ClipItem
    var shortcutBadge: String? = nil
    var isHighlighted: Bool = false
    let onPaste: () -> Void
    let onPreview: () -> Void
    let onOpenTransform: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false

    private var activeHighlight: Bool {
        isHovered || isHighlighted
    }

    var body: some View {
        HStack(spacing: 8) {
            // Shortcut Bead
            if let badge = shortcutBadge {
                Text(badge)
                    .font(.system(size: badge.hasPrefix("⌥") ? 9 : 11, weight: .bold, design: .rounded))
                    .foregroundColor(activeHighlight ? .white : (badge.hasPrefix("⌥") ? .orange : .secondary))
                    .frame(width: badge.hasPrefix("⌥") ? 22 : 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                activeHighlight
                                ? AnyShapeStyle(ZestPalette.ctaGradient)
                                : AnyShapeStyle(badge.hasPrefix("⌥") ? Color.orange.opacity(0.15) : Color.primary.opacity(0.08))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(activeHighlight ? Color.white.opacity(0.40) : (badge.hasPrefix("⌥") ? Color.orange.opacity(0.4) : Color.primary.opacity(0.14)), lineWidth: 0.6)
                    )
            }

            // Pinned Icon Badge
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
            }

            // Minimalist Monospace Content Type Tag
            Text(item.detectedType.rawValue)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(item.detectedType.systemColor)
                .padding(.horizontal, 4.5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(item.detectedType.systemColor.opacity(0.12))
                )

            // Miniature Thumbnail Preview for images
            if item.isImage, let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                    )
            }

            // Content text (San Francisco, clean and readable)
            Text(item.displayTitle)
                .font(.system(size: 12, weight: .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)

            Spacer(minLength: 4)

            // Hover Actions: Pin, Preview, Transform / Inspect, and Delete
            if activeHighlight {
                HStack(spacing: 4) {
                    Button(action: onTogglePin) {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(item.isPinned ? .orange : .secondary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "Unpin clip" : "Pin clip permanently")
                    .accessibilityLabel(item.isPinned ? "Unpin clip" : "Pin clip")

                    Button(action: onPreview) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Quick Look Preview (Space)")
                    .accessibilityLabel("Quick Look Preview")

                    Button(action: onOpenTransform) {
                        Image(systemName: item.isImage ? "eye" : "slider.horizontal.3")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ZestPalette.tang)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(item.isImage ? "View image details" : "Open Transform Deck (Tab)")
                    .accessibilityLabel(item.isImage ? "View image details" : "Open Transform Deck")

                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.red.opacity(0.85))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete clip from history")
                    .accessibilityLabel("Delete clip from history")
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            } else {
                HStack(spacing: 4) {
                    if let size = item.formattedFileSize {
                        Text(size)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    if item.copyCount > 1 {
                        Text("\(item.copyCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(activeHighlight ? AnyShapeStyle(ZestPalette.activeRowWash) : AnyShapeStyle(Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(activeHighlight ? ZestPalette.tang.opacity(0.42) : Color.clear, lineWidth: 0.75)
        )
        .overlay(alignment: .leading) {
            if activeHighlight {
                Capsule()
                    .fill(ZestPalette.ctaGradient)
                    .frame(width: 2.5, height: 20)
                    .padding(.leading, 2)
            }
        }
        .shadow(color: activeHighlight ? ZestPalette.tang.opacity(0.14) : Color.clear, radius: 5, y: 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPaste)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Quick Look Preview (Space)") {
                onPreview()
            }
            Divider()
            Button(item.isPinned ? "Unpin Clip" : "Pin Clip (⌥)") {
                onTogglePin()
            }
            Button("Paste (↵)") {
                onPaste()
            }
            Button("Paste Plain Text (⌥↵)") {
                PasteEngine.pastePlainText(item: item, dismissHUD: onDismiss)
            }
            Button("Copy Only (⇧↵)") {
                PasteEngine.copyOnly(item: item, dismissHUD: onDismiss)
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Footer Utility Circle Button
struct FooterCircleButton: View {
    let systemName: String
    var iconSize: CGFloat = 11
    var iconWeight: Font.Weight = .medium
    var isEmphasized: Bool = false
    let helpText: String
    let accessibilityLabel: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundColor((isHovered || isEmphasized) ? ZestPalette.tang : .secondary)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(
                            isHovered
                            ? ZestPalette.tang.opacity(0.16)
                            : (isEmphasized ? ZestPalette.tang.opacity(0.10) : Color.primary.opacity(0.07))
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isHovered
                            ? ZestPalette.tang.opacity(0.55)
                            : (isEmphasized ? ZestPalette.tang.opacity(0.32) : Color.primary.opacity(0.14)),
                            lineWidth: 0.6
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(helpText)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Prominent Frosted Glass Back Button
struct BackButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isHovered ? ZestPalette.tang : .primary)
                Text("Back")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isHovered ? ZestPalette.tang.opacity(0.14) : Color.primary.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isHovered ? ZestPalette.tang.opacity(0.45) : Color.primary.opacity(0.14), lineWidth: 0.75)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Return to clips list")
        .accessibilityLabel("Back to clips list")
    }
}
