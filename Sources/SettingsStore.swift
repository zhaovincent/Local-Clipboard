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

final class SettingsStore {
    static let shared = SettingsStore()

    private let d = UserDefaults.standard

    private init() {
        d.register(defaults: [
            "maxItems": 300,
            "maxDays": 0,
            "maxImageMB": 200,
            "autoPaste": true,
            "pastePlainText": false,
            "playSound": false,
            "hotKeyCode": 9,
            "hotKeyMods": Int(cmdKey | shiftKey)
        ])
    }

    var maxItems: Int {
        get { d.integer(forKey: "maxItems") }
        set { d.set(max(20, newValue), forKey: "maxItems") }
    }

    var maxDays: Int {
        get { d.integer(forKey: "maxDays") }
        set { d.set(newValue, forKey: "maxDays") }
    }

    var maxImageMB: Int {
        get { d.integer(forKey: "maxImageMB") }
        set { d.set(max(10, newValue), forKey: "maxImageMB") }
    }

    var autoPaste: Bool {
        get { d.bool(forKey: "autoPaste") }
        set { d.set(newValue, forKey: "autoPaste") }
    }

    var pastePlainText: Bool {
        get { d.bool(forKey: "pastePlainText") }
        set { d.set(newValue, forKey: "pastePlainText") }
    }

    var playSound: Bool {
        get { d.bool(forKey: "playSound") }
        set { d.set(newValue, forKey: "playSound") }
    }

    var hotKeyCode: Int {
        get { d.integer(forKey: "hotKeyCode") }
        set { d.set(newValue, forKey: "hotKeyCode") }
    }

    var hotKeyMods: Int {
        get { d.integer(forKey: "hotKeyMods") }
        set { d.set(newValue, forKey: "hotKeyMods") }
    }

    var didOnboard: Bool {
        get { d.bool(forKey: "didOnboard") }
        set { d.set(newValue, forKey: "didOnboard") }
    }

    var hotKeyDisplay: String {
        HotKeyNames.display(code: hotKeyCode, mods: hotKeyMods)
    }

    func payload() -> [String: Any] {
        [
            "maxItems": maxItems,
            "maxDays": maxDays,
            "maxImageMB": maxImageMB,
            "autoPaste": autoPaste,
            "pastePlainText": pastePlainText,
            "playSound": playSound,
            "launchAtLogin": LaunchAtLogin.isEnabled,
            "hotkey": hotKeyDisplay,
            "trusted": PasteService.isTrusted,
            "hotkeyOk": HotKeyManager.shared.isRegistered,
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        ]
    }

    /// 前端批量下发的设置项
    func apply(_ payload: [String: Any]) {
        if let v = payload["maxItems"] as? Int { maxItems = v }
        if let v = payload["maxDays"] as? Int { maxDays = v }
        if let v = payload["maxImageMB"] as? Int { maxImageMB = v }
        if let v = payload["autoPaste"] as? Bool { autoPaste = v }
        if let v = payload["pastePlainText"] as? Bool { pastePlainText = v }
        if let v = payload["playSound"] as? Bool { playSound = v }
        if let v = payload["launchAtLogin"] as? Bool { LaunchAtLogin.set(v) }
    }
}

enum HotKeyNames {
    static func display(code: Int, mods: Int) -> String {
        var s = ""
        if mods & controlKey != 0 { s += "⌃" }
        if mods & optionKey != 0 { s += "⌥" }
        if mods & shiftKey != 0 { s += "⇧" }
        if mods & cmdKey != 0 { s += "⌘" }
        s += key(code)
        return s
    }

    static func key(_ code: Int) -> String {
        let map: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
            24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 42: "\\", 41: ";", 43: ",", 44: "/", 47: ".", 50: "`",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        return map[code] ?? "Key\(code)"
    }
}

enum LaunchAtLogin {
    static let label = "com.localclipboard.app"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func set(_ on: Bool) {
        if on {
            guard let exe = Bundle.main.executableURL?.resolvingSymlinksInPath().path else { return }
            let dict: [String: Any] = [
                "Label": label,
                "ProgramArguments": [exe],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive",
                "LimitLoadToSessionType": "Aqua"
            ]
            guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) else { return }
            try? FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: plistURL)
            _ = run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
            _ = run("/bin/launchctl", ["enable", "gui/\(getuid())/\(label)"])
        } else {
            _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())", plistURL.path])
            try? FileManager.default.removeItem(at: plistURL)
        }
    }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus
        } catch {
            return -1
        }
    }
}
