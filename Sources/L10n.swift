// Copyright 2026 junyue
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import AppKit

/// 轻量双语支持：zh / en。
/// 偏好存在 SettingsStore.language（auto / zh / en），auto 时跟随系统首选语言。
/// 语言变化通过 L10n.didChange 通知广播，AppDelegate 收到后重建菜单。
enum L10n {
    static let didChange = Notification.Name("LC_L10nDidChange")

    private(set) static var pref = "auto"
    private(set) static var lang = "zh"

    /// 更新偏好并重算生效语言；语言发生变化时广播通知
    @discardableResult
    static func refresh(_ preference: String? = nil) -> String {
        if let p = preference, ["auto", "zh", "en"].contains(p) { pref = p }
        let resolved = L10n.resolve(pref)
        let changed = resolved != lang
        lang = resolved
        if changed {
            NotificationCenter.default.post(name: didChange, object: nil)
        }
        return lang
    }

    /// auto -> 跟随系统首选语言（zh 优先，其余回退 en）
    static func resolve(_ pref: String) -> String {
        switch pref {
        case "zh": return "zh"
        case "en": return "en"
        default:
            for l in Locale.preferredLanguages {
                if l.hasPrefix("zh") { return "zh" }
                if l.hasPrefix("en") { return "en" }
            }
            return "en"
        }
    }

    static func t(_ zh: String, _ en: String) -> String {
        lang == "en" ? en : zh
    }

    // MARK: - 菜单与状态栏

    static var about: String { t("关于 Local Clipboard", "About Local Clipboard") }
    static var hidePanel: String { t("隐藏面板", "Hide Panel") }
    static var quitApp: String { t("退出 Local Clipboard", "Quit Local Clipboard") }
    static var editMenu: String { t("编辑", "Edit") }
    static var undo: String { t("撤销", "Undo") }
    static var redo: String { t("重做", "Redo") }
    static var cut: String { t("剪切", "Cut") }
    static var copy: String { t("复制", "Copy") }
    static var paste: String { t("粘贴", "Paste") }
    static var selectAll: String { t("全选", "Select All") }
    static var openPanel: String { t("打开剪贴板面板", "Open Clipboard Panel") }
    static var openSettings: String { t("打开设置", "Open Settings") }
    static var clearKeepPinned: String { t("清空历史（保留置顶）", "Clear History (Keep Pinned)") }
    static var clearKeepToast: String { t("已清空历史，保留置顶项", "History cleared, pinned items kept") }

    // MARK: - 语言

    static var language: String { t("语言", "Language") }
    static var followSystem: String { t("跟随系统", "Auto") }
    static var chinese: String { t("中文", "中文") }
    static var english: String { t("English", "English") }

    // MARK: - 面板

    static func cleared(_ keep: Bool) -> String {
        keep ? clearKeepToast : t("已清空全部历史", "All history cleared")
    }
    static var launchLoginOn: String { t("已开启开机自启动", "Launch at login enabled") }
    static var launchLoginOff: String { t("已关闭开机自启动", "Launch at login disabled") }
    static var needAccessibility: String { t("自动粘贴需要在「辅助功能」中授权", "Auto-paste requires the Accessibility permission") }
    static var needModKey: String { t("请同时按下 ⌘ / ⌃ / ⌥ / ⇧ 中的一个", "Hold one of ⌘ / ⌃ / ⌥ / ⇧") }
    static var itemUnavailable: String { t("这条记录已失效", "This item is no longer available") }
    static func imageItem(_ w: Int, _ h: Int) -> String { t("图片 \(w) × \(h)", "Image \(w) × \(h)") }

    static var chooseStorageMessage: String {
        t("选择剪贴板历史的存储位置（会自动迁移现有数据）",
          "Choose where to keep clipboard history (existing data will be migrated)")
    }
    static var choosePrompt: String { t("选择", "Choose") }
    static var migrated: String { t("已迁移到新位置", "Moved to the new location") }
    static var alreadyDefault: String { t("当前已在使用默认位置", "Already using the default location") }
    static var restoredDefault: String { t("已恢复默认存储位置", "Restored the default storage location") }
    static var exportTitle: String { t("导出剪贴板备份", "Export Clipboard Backup") }
    static var exported: String { t("备份已导出", "Backup exported") }
    static var importMessage: String {
        t("选择之前导出的备份 zip（与当前历史合并，重复内容自动跳过）",
          "Choose a previously exported backup zip (merged into current history; duplicates are skipped)")
    }
    static var importPrompt: String { t("导入", "Import") }
    static func imported(_ n: Int) -> String { t("已导入 \(n) 条记录", "Imported \(n) items") }

    // MARK: - 数据层错误文案（DataTransfer / 迁移）

    static func dittoFailed(_ rc: Int32, _ what: String, _ whatEn: String) -> String {
        t("\(what)（ditto 退出码 \(rc)）", "\(whatEn) (ditto exit code \(rc))")
    }
    static func failed(_ detail: String, _ what: String, _ whatEn: String) -> String {
        t("\(what)：\(detail)", "\(whatEn): \(detail)")
    }
    static var noTempDir: String { t("无法创建临时目录", "Cannot create temporary directory") }
    static var noHistoryJSON: String { t("备份里没有找到 history.json", "history.json not found in backup") }
    static var badBackupFormat: String { t("备份文件格式无法识别", "Unrecognized backup file format") }
    static var backupIdentical: String { t("备份与当前历史一致，没有新增记录", "Backup matches current history — nothing new to import") }
    static func migrationFailed(_ detail: String) -> String {
        t("迁移失败：\(detail)", "Migration failed: \(detail)")
    }
}
