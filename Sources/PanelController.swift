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
import WebKit
import Carbon

final class PanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class PanelController: NSObject, WKScriptMessageHandler, NSWindowDelegate {

    let store: HistoryStore
    let settings: SettingsStore
    let window: PanelWindow

    private var webView: WKWebView!
    private var blurView: NSVisualEffectView!
    private var jsReady = false
    private var pending: [(String, String)] = []
    private var recordMonitor: Any?
    private var suppressHide = false
    private var lastShownAt = Date.distantPast

    private(set) var previousApp: NSRunningApplication?

    var onVisibilityChange: ((Bool) -> Void)?

    private let panelSize = NSSize(width: 452, height: 704)
    private let inset: CGFloat = 22
    private var currentTheme = false

    /// 外观同步：跟系统改 NSAppearance / 材质，并推送主题给网页
    var themeSync: String { currentTheme ? "dark" : "light" }

    private func syncAppearance() {
        // 视图就绪前不同步（blurView 在 configureContent 中创建）
        guard blurView != nil else { return }
        let mode = settings.appearance
        let dark: Bool
        switch mode {
        case "dark": dark = true
        case "light": dark = false
        default:
            let best = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
            dark = (best == .darkAqua)
        }
        currentTheme = dark
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        blurView.material = dark ? .hudWindow : .sidebar
        call("theme", jsonString(["mode": settings.appearance, "dark": dark]))
    }

    private var appearanceObserver: NSObjectProtocol?

    private func installAppearanceObserver() {
        guard appearanceObserver == nil else { return }
        appearanceObserver = DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main) { [weak self] _ in
                guard let self, self.settings.appearance == "auto" else { return }
                // 系统切换瞬间 NSApp.effectiveAppearance 可能滞后，稍等一拍再同步
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.syncAppearance()
                }
            }
    }

    init(store: HistoryStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.window = PanelWindow(contentRect: NSRect(origin: .zero, size: panelSize),
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered,
                                  defer: false)
        super.init()
        configureContent()
        configureWindow()
    }

    // MARK: - 构建

    private func configureWindow() {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.animationBehavior = .none
        window.isMovableByWindowBackground = false
        window.delegate = self
        window.title = "Local Clipboard"
        installAppearanceObserver()
        syncAppearance()
    }

    private func configureContent() {
        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        container.wantsLayer = true

        // 真实毛玻璃：透出桌面背景
        blurView = NSVisualEffectView(frame: container.bounds.insetBy(dx: inset, dy: inset))
        blurView.autoresizingMask = [.width, .height]
        blurView.material = .hudWindow
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 22
        blurView.layer?.cornerCurve = .continuous
        blurView.layer?.masksToBounds = true
        container.addSubview(blurView)

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let ucc = WKUserContentController()
        ucc.add(self, name: "clip")
        config.userContentController = ucc

        webView = WKWebView(frame: container.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.underPageBackgroundColor = .clear
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        container.addSubview(webView)

        window.contentView = container

        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") else {
            NSLog("Local Clipboard: web resources missing")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    // MARK: - 显示 / 隐藏

    var isVisible: Bool { window.isVisible }

    func show() {
        lastShownAt = Date()
        previousApp = NSWorkspace.shared.frontmostApplication
        positionWindow()
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(webView)

        syncAppearance()
        pushItems()
        pushSettings()
        call("open")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
        onVisibilityChange?(true)

        // 诊断开关（LC_DEBUG=1 时把实际渲染结果写日志），日常使用不产生任何开销
        if ProcessInfo.processInfo.environment["LC_DEBUG"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.webView.evaluateJavaScript(
                    "document.querySelectorAll('#list .card').length + '|' + "
                    + "(document.querySelector('#empty').classList.contains('show') ? 'EMPTY' : 'ok') + '|' + "
                    + "document.querySelector('#subtitle').textContent"
                ) { result, error in
                    NSLog("Local Clipboard DEBUG cards/empty/subtitle = \(result ?? "nil") err=\(String(describing: error))")
                }
            }
        }
    }

    func hide(restoreFocus: Bool = true) {
        guard window.isVisible else { return }
        let app = previousApp
        window.orderOut(nil)
        window.alphaValue = 0
        call("close")
        onVisibilityChange?(false)
        if restoreFocus, let app, app.bundleIdentifier != Bundle.main.bundleIdentifier {
            app.activate(options: [])
        }
    }

    func toggle() {
        if window.isVisible { hide() } else { show() }
    }

    private func positionWindow() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        var x = mouse.x - panelSize.width / 2
        var y = mouse.y - panelSize.height * 0.62
        x = min(max(x, visible.minX + 6), visible.maxX - panelSize.width - 6)
        y = min(max(y, visible.minY + 6), visible.maxY - panelSize.height - 6)
        window.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    // MARK: - Swift -> JS

    private func jsonString(_ obj: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
              let s = String(data: data, encoding: .utf8) else { return "null" }
        return s
    }

    func call(_ fn: String, _ json: String = "null") {
        guard jsReady else {
            pending.append((fn, json))
            return
        }
        let code = "window.__native && window.__native.\(fn)(\(json))"
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(code, completionHandler: nil)
        }
    }

    func pushItems() {
        call("items", jsonString(store.payload()))
        call("stats", jsonString(store.stats))
    }

    func pushSettings() {
        call("settings", jsonString(settings.payload()))
    }

    func toast(_ text: String) {
        call("toast", jsonString(["text": text]))
    }

    // MARK: - JS -> Swift

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let cmd = body["cmd"] as? String else { return }

        switch cmd {
        case "ready":
            jsReady = true
            pushItems()
            pushSettings()
            let queued = pending
            pending = []
            for (fn, json) in queued { call(fn, json) }

        case "refresh":
            pushItems()

        case "copy":
            if let id = body["id"] as? String { copyItem(id) }

        case "pin":
            if let id = body["id"] as? String {
                store.togglePin(id)
                pushItems()
            }

        case "delete":
            if let id = body["id"] as? String {
                store.delete(id)
                pushItems()
            }

        case "clearAll":
            let keep = (body["keepPinned"] as? Bool) ?? false
            store.clear(keepPinned: keep)
            pushItems()
            toast(L10n.cleared(keep))

        case "preview":
            if let id = body["id"] as? String, let item = store.item(id) {
                call("preview", jsonString(["id": id, "src": store.previewDataURL(item) ?? ""]))
            }

        case "getSettings":
            pushSettings()
            pushItems()

        case "applySettings":
            if let payload = body["values"] as? [String: Any] {
                let oldLang = settings.language
                settings.apply(payload)
                if payload["language"] != nil {
                    L10n.refresh(settings.language)
                }
                if payload["appearance"] != nil {
                    syncAppearance()
                }
                store.prune()
                store.save()
                pushItems()
                pushSettings()
                if payload["launchAtLogin"] != nil {
                    toast(LaunchAtLogin.isEnabled ? L10n.launchLoginOn : L10n.launchLoginOff)
                }
                if payload["autoPaste"] as? Bool == true, !PasteService.isTrusted {
                    PasteService.requestTrust()
                    toast(L10n.needAccessibility)
                }
                if payload["language"] != nil, settings.language != oldLang {
                    // 语言变化：广播已由 L10n.refresh 发出，这里补推一次设置让网页词表立即生效
                    pushSettings()
                }
            }

        case "recordHotkey":
            startRecording()

        case "cancelRecord":
            stopRecording()

        case "revealData":
            NSWorkspace.shared.activateFileViewerSelecting([store.rootDir])

        case "chooseStorageDir":
            chooseStorageDir()

        case "resetStorageDir":
            resetStorageDir()

        case "exportData":
            exportBackup()

        case "importData":
            importBackup()

        case "openAX":
            PasteService.openAccessibilitySettings()

        case "checkTrust":
            pushSettings()

        case "hide":
            hide()

        case "quit":
            NSApp.terminate(nil)

        default:
            break
        }
    }

    // MARK: - 复制

    private func copyItem(_ id: String) {
        guard let item = store.item(id) else { return }
        guard PasteService.write(item, plainText: settings.pastePlainText) else {
            toast(L10n.itemUnavailable)
            return
        }
        if settings.playSound { NSSound(named: "Tink")?.play() }

        window.orderOut(nil)
        window.alphaValue = 0
        onVisibilityChange?(false)

        let target = previousApp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if let target, target.bundleIdentifier != Bundle.main.bundleIdentifier {
                target.activate(options: [])
            }
            if self.settings.autoPaste {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    PasteService.sendPaste()
                }
            }
        }
    }

    // MARK: - 快捷键录制

    private func startRecording() {
        stopRecording()
        suppressHide = true
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // esc 取消
                self.stopRecording()
                self.call("hotkeyRecording", self.jsonString(["ok": false, "cancelled": true]))
                return nil
            }
            var mods = 0
            if event.modifierFlags.contains(.command) { mods |= cmdKey }
            if event.modifierFlags.contains(.shift) { mods |= shiftKey }
            if event.modifierFlags.contains(.option) { mods |= optionKey }
            if event.modifierFlags.contains(.control) { mods |= controlKey }
            guard mods != 0 else {
                self.call("toast", self.jsonString(["text": L10n.needModKey]))
                return nil
            }
            let ok = HotKeyManager.shared.register(code: Int(event.keyCode), mods: mods)
            self.stopRecording()
            if ok {
                self.settings.hotKeyCode = Int(event.keyCode)
                self.settings.hotKeyMods = mods
                self.pushSettings()
                self.call("hotkeyRecording", self.jsonString(["ok": true, "display": self.settings.hotKeyDisplay]))
            } else {
                HotKeyManager.shared.register(code: self.settings.hotKeyCode, mods: self.settings.hotKeyMods)
                self.call("hotkeyRecording", self.jsonString(["ok": false, "conflict": true]))
            }
            return nil
        }
    }

    private func stopRecording() {
        if let m = recordMonitor {
            NSEvent.removeMonitor(m)
            recordMonitor = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.suppressHide = false
            }
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        guard !suppressHide else { return }
        // 刚显示时系统激活切换可能瞬间夺走 key，忽略这段竞态窗口
        guard Date().timeIntervalSince(lastShownAt) > 0.35 else { return }
        hide(restoreFocus: false)
    }

    // MARK: - 存储位置 / 备份

    /// 弹出系统对话框期间抑制面板失焦自动隐藏（与快捷键录制同一机制）
    private func modalProtect() {
        suppressHide = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.suppressHide = false
        }
    }

    /// 选择新的存储目录 -> 确认迁移 -> 刷新界面
    private func chooseStorageDir() {
        modalProtect()
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.storageRoot
        panel.message = L10n.chooseStorageMessage
        panel.prompt = L10n.choosePrompt
        let resp = panel.runModal()
        guard resp == .OK, let url = panel.url else { return }
        if url.standardizedFileURL.path == HistoryStore.defaultRoot().standardizedFileURL.path {
            resetStorageDir(silent: true)
            return
        }
        let target = url.appendingPathComponent("Local Clipboard", isDirectory: true)
        if let err = store.migrateData(to: target) {
            toast(err)
            return
        }
        settings.storageDir = target.path
        pushSettings()
        pushItems()
        toast(L10n.migrated)
    }

    /// 恢复默认存储位置（如有自定义则迁移回默认目录）
    private func resetStorageDir(silent: Bool = false) {
        let def = HistoryStore.defaultRoot()
        if settings.storageDir.isEmpty {
            if !silent { toast(L10n.alreadyDefault) }
            return
        }
        if let err = store.migrateData(to: def) {
            toast(err)
            return
        }
        settings.storageDir = ""
        pushSettings()
        pushItems()
        toast(L10n.restoredDefault)
    }

    private func exportBackup() {
        modalProtect()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "Local Clipboard Backup \(HistoryStore.transferStamp()).zip"
        panel.title = L10n.exportTitle
        let resp = panel.runModal()
        guard resp == .OK, let url = panel.url else { return }
        if let err = store.exportData(to: url) {
            toast(err)
        } else {
            toast(L10n.exported)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func importBackup() {
        modalProtect()
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip]
        panel.message = L10n.importMessage
        panel.prompt = L10n.importPrompt
        let resp = panel.runModal()
        guard resp == .OK, let url = panel.url else { return }
        let (n, msg) = store.importData(from: url)
        pushItems()
        pushSettings()
        if let msg {
            toast(msg)
        } else {
            toast(L10n.imported(n))
        }
    }
}
