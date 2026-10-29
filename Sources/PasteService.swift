import AppKit
import ApplicationServices

/// 写回剪贴板 + 模拟 ⌘V 自动粘贴
enum PasteService {

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    static func write(_ item: ClipItem, plainText: Bool) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.kind {
        case .image:
            guard let url = HistoryStore.shared.originalImageURL(item),
                  let data = try? Data(contentsOf: url),
                  let img = NSImage(data: data) else { return false }
            pb.setData(data, forType: .png)
            if let tiff = img.tiffRepresentation {
                pb.setData(tiff, forType: .tiff)
            }
            pb.setString(item.text, forType: .string)

        case .file:
            let urls = item.text.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
            let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
            if existing.isEmpty {
                pb.setString(item.text, forType: .string)
            } else {
                pb.writeObjects(existing as [NSURL])
            }

        case .text, .link:
            pb.setString(item.text, forType: .string)
            if !plainText, item.kind == .link {
                pb.setString(item.text, forType: .URL)
            }
        }

        ClipboardMonitor.selfWriteCount = pb.changeCount
        _ = plainText
        return true
    }

    /// 模拟按键 ⌘V（需要辅助功能权限）
    static func sendPaste() {
        guard isTrusted else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(9) // kVK_ANSI_V
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
