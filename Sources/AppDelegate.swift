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
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let store = HistoryStore.shared
    private let settings = SettingsStore.shared
    private var panel: PanelController!
    private var statusItem: NSStatusItem!
    private var monitor: ClipboardMonitor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 离线自检：LC_SELFTEST=1 时跑迁移/导出/导入全链路后退出，不触碰真实数据
        if ProcessInfo.processInfo.environment["LC_SELFTEST"] == "1" {
            SelfTest.run()
            return
        }
        buildMainMenu()

        // 上次运行使用过自定义目录：本次启动直接从该目录读取
        if !settings.storageDir.isEmpty {
            store.rebindRoot(settings.storageRoot)
        }
        store.load()

        panel = PanelController(store: store, settings: settings)
        setupStatusItem()

        monitor = ClipboardMonitor(store: store)
        monitor.start()

        HotKeyManager.shared.handler = { [weak self] in
            self?.togglePanel()
        }
        registerInitialHotKey()

        if ProcessInfo.processInfo.environment["LC_DEBUG"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.panel.show()
            }
        }

        if !settings.didOnboard {
            settings.didOnboard = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.panel.show()
            }
        }
    }

    /// 依次尝试可用组合，并把真正注册成功的组合持久化，避免界面显示与实际不一致
    private func registerInitialHotKey() {
        let candidates: [(Int, Int)] = [
            (settings.hotKeyCode, settings.hotKeyMods),
            (9, Int(cmdKey | shiftKey)),
            (9, Int(controlKey | optionKey)),
            (9, Int(controlKey | shiftKey)),
            (8, Int(cmdKey | shiftKey))
        ]
        for (code, mods) in candidates where HotKeyManager.shared.register(code: code, mods: mods) {
            settings.hotKeyCode = code
            settings.hotKeyMods = mods
            return
        }
        NSLog("Local Clipboard: 所有候选快捷键均注册失败，请在设置中手动指定")
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }

    // MARK: - 菜单

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于 Local Clipboard", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏面板", action: #selector(hidePanel), keyEquivalent: "w")
        appMenu.addItem(withTitle: "退出 Local Clipboard", action: #selector(quitApp), keyEquivalent: "q")

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func hidePanel() {
        panel?.hide()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - 状态栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = StatusIcon.make()
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Local Clipboard · \(settings.hotKeyDisplay)"
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            togglePanel()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "打开剪贴板面板", action: #selector(openPanelFromMenu), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "清空历史（保留置顶）", action: #selector(clearFromMenu), keyEquivalent: "").target = self
        menu.addItem(withTitle: "打开设置", action: #selector(openSettingsFromMenu), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Local Clipboard", action: #selector(quitApp), keyEquivalent: "").target = self

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPanelFromMenu() { panel.show() }

    @objc private func openSettingsFromMenu() {
        panel.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.panel.call("openSettings")
        }
    }

    @objc private func clearFromMenu() {
        store.clear(keepPinned: true)
        panel.pushItems()
        panel.toast("已清空历史，保留置顶项")
    }

    // MARK: - 面板

    private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible { panel.hide() } else { panel.show() }
    }
}

/// 动态绘制状态栏图标（剪贴板 + 闪光）
enum StatusIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let body = NSBezierPath(roundedRect: NSRect(x: 4.2, y: 1.6, width: 9.6, height: 12.4),
                                    xRadius: 2.4, yRadius: 2.4)
            body.lineWidth = 1.5
            NSColor.black.setStroke()
            body.stroke()

            let clip = NSBezierPath(roundedRect: NSRect(x: 6.6, y: 12.2, width: 4.8, height: 3.2),
                                    xRadius: 1.4, yRadius: 1.4)
            clip.lineWidth = 1.5
            clip.stroke()

            let line1 = NSBezierPath()
            line1.move(to: NSPoint(x: 6.6, y: 9.6))
            line1.line(to: NSPoint(x: 11.4, y: 9.6))
            line1.lineWidth = 1.4
            line1.lineCapStyle = .round
            line1.stroke()

            let line2 = NSBezierPath()
            line2.move(to: NSPoint(x: 6.6, y: 6.6))
            line2.line(to: NSPoint(x: 9.8, y: 6.6))
            line2.lineWidth = 1.4
            line2.lineCapStyle = .round
            line2.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }
}
