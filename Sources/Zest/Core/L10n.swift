import Foundation
import SwiftUI

public enum AppLanguage: String, CaseIterable, Sendable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    case japanese = "ja"

    public var displayName: String {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .chinese: return "简体中文"
        case .japanese: return "日本語"
        }
    }
}

@MainActor
public final class L10n: ObservableObject {
    public static let shared = L10n()

    @AppStorage("zest_language") public var currentLanguage: String = AppLanguage.system.rawValue

    private init() {}

    public var activeLanguage: AppLanguage {
        if let lang = AppLanguage(rawValue: currentLanguage) {
            if lang == .system {
                let preferred = Locale.preferredLanguages.first ?? "en"
                if preferred.hasPrefix("zh") { return .chinese }
                if preferred.hasPrefix("ja") { return .japanese }
                return .english
            }
            return lang
        }
        return .english
    }

    public func tr(_ key: Key) -> String {
        switch activeLanguage {
        case .chinese:
            return key.chinese
        case .japanese:
            return key.japanese
        case .english, .system:
            return key.english
        }
    }

    public enum Key {
        case searchPlaceholder
        case pinnedSection
        case recentSection
        case tapToPasteFooter
        case clearAll
        case cancel
        case confirmClear
        case preferences
        case pauseMonitoring
        case resumeMonitoring
        case quit
        case transformsHint
        case quickLookHint
        case emptyClipboard
        case noResults
        case generalTab
        case historyTab
        case privacyTab
        case proTab
        case languagePicker
        case guideTab
        case guideTitle
        case appearanceTab
        case captureScreenText

        var english: String {
            switch self {
            case .searchPlaceholder: return "Type to search or tap 1-9, 0..."
            case .pinnedSection: return "PINNED (⌥1–⌥9)"
            case .recentSection: return "RECENT"
            case .tapToPasteFooter: return "Tap 1–10 to paste"
            case .clearAll: return "Clear All"
            case .cancel: return "Cancel"
            case .confirmClear: return "Clear All Clips?"
            case .preferences: return "Preferences..."
            case .pauseMonitoring: return "Pause Monitoring"
            case .resumeMonitoring: return "Resume Monitoring"
            case .quit: return "Quit"
            case .transformsHint: return "Tab: Transforms"
            case .quickLookHint: return "Space: Quick Look"
            case .emptyClipboard: return "Clipboard History is Empty"
            case .noResults: return "No matching clips found"
            case .generalTab: return "General"
            case .historyTab: return "History"
            case .privacyTab: return "Privacy"
            case .proTab: return "Pro"
            case .languagePicker: return "Language"
            case .guideTab: return "Guide"
            case .guideTitle: return "Shortcuts & Feature Guide"
            case .appearanceTab: return "Appearance"
            case .captureScreenText: return "Capture Screen Text (⌘⇧2)"
            }
        }

        var chinese: String {
            switch self {
            case .searchPlaceholder: return "键入以搜索或按 1-9, 0 粘贴..."
            case .pinnedSection: return "已固定 (⌥1–⌥9)"
            case .recentSection: return "最近记录"
            case .tapToPasteFooter: return "按 1–10 立即粘贴"
            case .clearAll: return "清空全部"
            case .cancel: return "取消"
            case .confirmClear: return "确认清空所有剪贴板记录？"
            case .preferences: return "首选项..."
            case .pauseMonitoring: return "暂停监控"
            case .resumeMonitoring: return "恢复监控"
            case .quit: return "退出"
            case .transformsHint: return "Tab: 数据转换"
            case .quickLookHint: return "空格: 快速预览"
            case .emptyClipboard: return "剪贴板历史为空"
            case .noResults: return "未找到匹配的剪贴内容"
            case .generalTab: return "通用"
            case .historyTab: return "历史"
            case .privacyTab: return "隐私"
            case .proTab: return "专业版"
            case .languagePicker: return "语言设置"
            case .guideTab: return "指南"
            case .guideTitle: return "快捷键与功能指南"
            case .appearanceTab: return "外观"
            case .captureScreenText: return "捕获屏幕文本 (⌘⇧2)"
            }
        }

        var japanese: String {
            switch self {
            case .searchPlaceholder: return "検索するか、1-9, 0 を押してペースト..."
            case .pinnedSection: return "ピン留め (⌥1–⌥9)"
            case .recentSection: return "最近の履歴"
            case .tapToPasteFooter: return "1–10 キーで即座にペースト"
            case .clearAll: return "すべて消去"
            case .cancel: return "キャンセル"
            case .confirmClear: return "すべての履歴を消去しますか？"
            case .preferences: return "環境設定..."
            case .pauseMonitoring: return "監視を一時停止"
            case .resumeMonitoring: return "監視を再開"
            case .quit: return "終了"
            case .transformsHint: return "Tab: 変換"
            case .quickLookHint: return "Space: クイックルック"
            case .emptyClipboard: return "クリップボードの履歴がありません"
            case .noResults: return "一致するクリップがありません"
            case .generalTab: return "一般"
            case .historyTab: return "履歴"
            case .privacyTab: return "プライバシー"
            case .proTab: return "Pro"
            case .languagePicker: return "言語設定"
            case .guideTab: return "ガイド"
            case .guideTitle: return "ショートカット＆機能ガイド"
            case .appearanceTab: return "外観"
            case .captureScreenText: return "画面のテキストをキャプチャ (⌘⇧2)"
            }
        }
    }
}
