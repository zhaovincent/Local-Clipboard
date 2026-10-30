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

// 端到端复现真实链路：完全照搬 PanelController 的 jsReady 门控逻辑，
// 只有页面真的发出 "ready" 才推送数据，然后把真实历史喂进去看渲染结果。
// 用法: swift scripts/verify_live.swift <web目录> <history.json>

let args = CommandLine.arguments
let webDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "Web")
let historyPath = args.count > 2 ? args[2] : ""

// 把 history.json(ClipItem Codable) 转成前端 payload 字段
func loadPayload() -> [[String: Any]] {
    guard !historyPath.isEmpty,
          let data = FileManager.default.contents(atPath: historyPath),
          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
    return arr.map { raw -> [String: Any] in
        var d: [String: Any] = [:]
        d["id"] = raw["id"]
        d["kind"] = raw["kind"]
        let text = raw["text"] as? String ?? ""
        d["text"] = String(text.prefix(6000))
        d["createdAt"] = raw["createdAt"]
        d["pinned"] = raw["pinned"]
        d["size"] = raw["byteSize"] ?? 0
        d["len"] = text.count
        if let s = raw["source"], !(s is NSNull) { d["source"] = s }
        if let w = raw["width"], let h = raw["height"] { d["w"] = w; d["h"] = h }
        // 图片缩略图：真实 App 会带 base64，这里用占位色块代替，只为验证卡片数量与布局
        if (raw["kind"] as? String) == "image" {
            d["thumb"] = "data:image/gif;base64,R0lGODdhAQABAIAAAP///wAAACwAAAAAAQABAAACAkQBADs="
        }
        return d
    }
}

let payload = loadPayload()

final class Bridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    var jsReady = false
    var pending: [(String, String)] = []
    var webView: WKWebView!
    var logs: [String] = []
    var onReady: (() -> Void)?

    func json(_ o: Any) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: o),
              let s = String(data: d, encoding: .utf8) else { return "null" }
        return s
    }

    func call(_ fn: String, _ json: String = "null") {
        guard jsReady else { pending.append((fn, json)); return }
        webView.evaluateJavaScript("window.__native && window.__native.\(fn)(\(json))", completionHandler: nil)
    }

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        if m.name == "log" { logs.append("\(m.body)"); return }
        guard let body = m.body as? [String: Any], let cmd = body["cmd"] as? String else { return }
        if cmd == "ready" {
            let first = !jsReady
            jsReady = true
            call("items", json(payload))
            call("stats", json(["count": payload.count, "images": 0, "pinned": 0,
                                "bytes": 0, "bytesText": "0 KB"]))
            call("settings", json(["hotkey": "⌘⇧V", "autoPaste": true, "version": "1.1.0",
                                   "hotkeyOk": true, "trusted": true,
                                   "appearance": "auto", "dark": false,
                                   "storageDir": "/Users/me/Library/Application Support/Local Clipboard",
                                   "storageIsCustom": false]))
            let q = pending; pending = []
            for (f, j) in q { call(f, j) }
            if first { onReady?() }
        } else {
            logs.append("cmd:" + cmd)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let bridge = Bridge()
let config = WKWebViewConfiguration()
let ucc = WKUserContentController()
ucc.add(bridge, name: "clip")
ucc.add(bridge, name: "log")
ucc.addUserScript(WKUserScript(source: """
window.__errs=[];
window.addEventListener('error',function(e){window.webkit.messageHandlers.log.postMessage('JS-ERROR '+e.message+' @'+e.lineno);});
""", injectionTime: .atDocumentStart, forMainFrameOnly: true))
config.userContentController = ucc

let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 452, height: 704), configuration: config)
webView.setValue(false, forKey: "drawsBackground")
bridge.webView = webView

let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 452, height: 704),
                      styleMask: [.borderless], backing: .buffered, defer: false)
window.contentView = webView
window.orderFrontRegardless()

// 记录页面是否真的发出了 ready
var gotReady = false
bridge.onReady = {
    gotReady = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        let probe = """
        JSON.stringify({
          cards: document.querySelectorAll('#list .card').length,
          emptyShown: document.querySelector('#empty').classList.contains('show'),
          subtitle: document.querySelector('#subtitle').textContent,
          firstText: (document.querySelector('#list .card .txt')||{}).textContent || '',
          sections: Array.from(document.querySelectorAll('.sechead')).map(function(e){return e.textContent}),
          bodyOpen: document.body.classList.contains('open'),
          theme: document.documentElement.dataset.theme || '(unset)',
          storageLabel: (document.getElementById('storageDirLabel')||{}).textContent || '',
          themeBtns: document.querySelectorAll('[data-theme-btn]').length,
          backupBtns: [document.getElementById('btnExport'), document.getElementById('btnImport')].filter(Boolean).length
        })
        """
        webView.evaluateJavaScript(probe) { r, e in
            print("READY_RECEIVED=\(gotReady)")
            print("PROBE=\(r ?? "nil")")
            if let e { print("PROBE_ERR=\(e)") }
            if !bridge.logs.isEmpty { print("LOGS=\(bridge.logs)") }
            exit(0)
        }
    }
}

let indexURL = webDir.appendingPathComponent("index.html")
webView.loadFileURL(indexURL, allowingReadAccessTo: webDir)

// 超时保护
DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
    print("READY_RECEIVED=false (页面未发出 ready)")
    print("LOGS=\(bridge.logs)")
    exit(2)
}

app.run()
