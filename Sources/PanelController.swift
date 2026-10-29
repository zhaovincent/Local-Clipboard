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

    init(store: HistoryStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.window = PanelWindow(contentRect: NSRect(origin: .zero, size: panelSize),
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered,
                                  defer: false)
        super.init()
        configureWindow()
        configureContent()
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
            toast(keep ? "已清空历史，保留置顶项" : "已清空全部历史")

        case "preview":
            if let id = body["id"] as? String, let item = store.item(id) {
                call("preview", jsonString(["id": id, "src": store.previewDataURL(item) ?? ""]))
            }

        case "getSettings":
            pushSettings()
            pushItems()

        case "applySettings":
            if let payload = body["values"] as? [String: Any] {
                settings.apply(payload)
                store.prune()
                store.save()
                pushItems()
                pushSettings()
                if payload["launchAtLogin"] != nil {
                    toast(LaunchAtLogin.isEnabled ? "已开启开机自启动" : "已关闭开机自启动")
                }
                if payload["autoPaste"] as? Bool == true, !PasteService.isTrusted {
                    PasteService.requestTrust()
                    toast("自动粘贴需要在「辅助功能」中授权")
                }
            }

        case "recordHotkey":
            startRecording()

        case "cancelRecord":
            stopRecording()

        case "revealData":
            NSWorkspace.shared.activateFileViewerSelecting([store.rootDir])

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
            toast("这条记录已失效")
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
                self.call("toast", self.jsonString(["text": "请同时按下 ⌘ / ⌃ / ⌥ / ⇧ 中的一个"]))
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
}
