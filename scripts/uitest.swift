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

// 离屏渲染自检：加载真实 UI，注入示例数据，输出 DOM 指标并截图
// 用法: swift scripts/uitest.swift <web目录> <截图输出路径>

let args = CommandLine.arguments
let webDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "Web")
let shotPath = args.count > 2 ? args[2] : "/tmp/localclipboard-ui.png"

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGImage? {
    guard let ctx = CGContext(data: nil, width: 240, height: 150, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let colors = [CGColor(red: r, green: g, blue: b, alpha: 1),
                  CGColor(red: 0.35, green: 0.85, blue: 1, alpha: 1)] as CFArray
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil)!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 240, y: 150), options: [])
    return ctx.makeImage()
}

func thumbURL() -> String {
    guard let cg = rgb(0.55, 0.45, 1.0) else { return "" }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else { return "" }
    return "data:image/jpeg;base64," + data.base64EncodedString()
}

final class LogSink: NSObject, WKScriptMessageHandler {
    var messages: [String] = []
    func userContentController(_ u: WKUserContentController, didReceive message: WKScriptMessage) {
        messages.append("\(message.body)")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 452, height: 704))
let sink = LogSink()
let config = WKWebViewConfiguration()
config.userContentController.add(sink, name: "log")
config.userContentController.addUserScript(WKUserScript(source: """
window.__errs = [];
window.addEventListener('error', function(e){
  window.webkit.messageHandlers.log.postMessage('JS-ERROR ' + e.message + ' @' + e.filename + ':' + e.lineno);
});
(function(){ var oe = console.error; console.error = function(){ 
  window.webkit.messageHandlers.log.postMessage('CONSOLE-ERROR ' + Array.prototype.join.call(arguments,' ')); oe.apply(console, arguments); }; })();
""", injectionTime: .atDocumentStart, forMainFrameOnly: true))
webView.configuration.userContentController.add(sink, name: "log")

let window = NSWindow(contentRect: NSRect(x: 120, y: 160, width: 452, height: 704),
                      styleMask: [.borderless], backing: .buffered, defer: false)
window.contentView = webView
window.orderFrontRegardless()

let indexURL = webDir.appendingPathComponent("index.html")
webView.setValue(false, forKey: "drawsBackground")
webView.loadFileURL(indexURL, allowingReadAccessTo: webDir)

let thumb = thumbURL()
let now = Date().timeIntervalSince1970
// LC_UI_DARK=1 时注入深色主题，验证暗色变量整套生效
let dark = ProcessInfo.processInfo.environment["LC_UI_DARK"] == "1"
let darkAppearance = dark ? "dark" : "auto"
let items: [[String: Any]] = [
    ["id": "1", "kind": "text", "text": "Local Clipboard 会把复制的文字、图片、文件都收进来，支持搜索和置顶。", "createdAt": now - 40, "pinned": true, "len": 62, "size": 180, "source": "Safari 浏览器"],
    ["id": "2", "kind": "link", "text": "https://www.apple.com.cn/macbook-pro/", "createdAt": now - 320, "pinned": false, "len": 37, "size": 37, "source": "Google Chrome"],
    ["id": "3", "kind": "image", "text": "图片 240 × 150", "createdAt": now - 900, "pinned": false, "len": 10, "size": 24000, "w": 240, "h": 150, "thumb": thumb, "source": "Screenshots"],
    ["id": "4", "kind": "file", "text": "/Users/me/Desktop/设计稿终版.png\n/Users/me/Desktop/需求说明.pdf", "createdAt": now - 3400, "pinned": false, "len": 60, "size": 1024, "source": "Finder"],
    ["id": "5", "kind": "text", "text": "npm run build && open build/Local Clipboard.app", "createdAt": now - 7300, "pinned": false, "len": 41, "size": 41, "source": "终端"],
    ["id": "6", "kind": "text", "text": "会议纪要：下周一 10:00 评审新版本的交互方案，记得提前同步设计稿。", "createdAt": now - 90000, "pinned": false, "len": 34, "size": 100, "source": "飞书"]
]

DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
    let inject = """
    window.__native.items(\(jsonString(items)));
    window.__native.stats(\(jsonString(["count": 6, "images": 1, "pinned": 1, "bytes": 28451, "bytesText": "27.8 KB"])));
    window.__native.settings(\(jsonString(["hotkey": "⌘⇧V", "autoPaste": true, "maxItems": 300, "maxImageMB": 200, "maxDays": 0, "version": "1.1.0", "trusted": true, "launchAtLogin": false, "appearance": darkAppearance, "dark": dark, "storageDir": "/Users/me/Library/Application Support/Local Clipboard", "storageIsCustom": false])));
    window.__native.open();
    """
    webView.evaluateJavaScript(inject) { _, err in
        if let err { print("inject error: \(err)") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let probe = """
            (function(){
              var q = function(s){ return document.querySelector(s); };
              var cards = Array.prototype.map.call(document.querySelectorAll('.card'), function(c){
                var r = c.getBoundingClientRect();
                return { id: c.dataset.id, kind: c.className, h: Math.round(r.height), y: Math.round(r.top) };
              });
              var panel = q('#panel').getBoundingClientRect();
              var empty = q('#empty').getBoundingClientRect();
              return JSON.stringify({
                cards: cards,
                secheads: Array.prototype.map.call(document.querySelectorAll('.sechead'), function(e){ return e.textContent; }),
                panelRect: { w: Math.round(panel.width), h: Math.round(panel.height) },
                panelOpacity: getComputedStyle(q('#panel')).opacity,
                emptyShown: q('#empty').classList.contains('show'),
                emptyRect: { w: Math.round(empty.width), h: Math.round(empty.height) },
                indWidth: q('#tabind').style.width,
                subtitle: q('#subtitle').textContent,
                brandTitle: q('.btext .title').textContent,
                brandTitleW: Math.round(q('.btext .title').getBoundingClientRect().width),
                brandBoxW: Math.round(q('.brand').getBoundingClientRect().width),
                hdrBtnsLeft: Math.round(q('.hdr-btns').getBoundingClientRect().left),
                aboutName: q('.about-name') ? q('.about-name').textContent : '',
                docTitle: document.title,
                firstText: q('.card .txt') ? q('.card .txt').textContent.slice(0, 24) : '',
                meta: q('.card .meta') ? q('.card .meta').textContent : '',
                listScrollH: q('#list').scrollHeight,
                listClientH: q('#list').clientHeight,
                bodyOpen: document.body.classList.contains('open'),
                theme: document.documentElement.dataset.theme || '(unset)',
                themeBG: getComputedStyle(q('#panel')).getPropertyValue('--bg-bottom').trim(),
                themeTXT: getComputedStyle(document.documentElement).getPropertyValue('--txt').trim(),
                themeBtnOn: (document.querySelector('.pills[data-key="appearance"] button.on')||{}).textContent || '',
                storageLabel: (q('#storageDirLabel')||{}).textContent || '',
                themeBtns: document.querySelectorAll('[data-theme-btn]').length,
                backupBtns: [q('#btnExport'), q('#btnImport')].filter(Boolean).length
              });
            })()
            """
            webView.evaluateJavaScript(probe) { result, err in
                if let err { print("probe error: \(err)") }
                print("=== PROBE ===")
                print(result ?? "nil")
                print("=== JS MESSAGES ===")
                print(sink.messages.isEmpty ? "(无错误)" : sink.messages.joined(separator: "\n"))

                let cfg = WKSnapshotConfiguration()
                cfg.rect = CGRect(x: 0, y: 0, width: 452, height: 704)
                webView.takeSnapshot(with: cfg) { image, snapErr in
                    if let image, let tiff = image.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: shotPath))
                        print("=== SNAPSHOT ===")
                        print("\(shotPath) \(rep.pixelsWide)x\(rep.pixelsHigh) bytes=\(png.count)")
                        // 采样中心区域像素，确认非空白
                        var sum = 0.0; var n = 0; var distinct = Set<Int>()
                        for y in stride(from: 100, to: 600, by: 40) {
                            for x in stride(from: 60, to: 400, by: 40) {
                                if let c = rep.colorAt(x: x, y: y) {
                                    sum += (c.redComponent + c.greenComponent + c.blueComponent) / 3
                                    distinct.insert(Int(c.redComponent * 40) * 10000 + Int(c.greenComponent * 40) * 100 + Int(c.blueComponent * 40))
                                    n += 1
                                }
                            }
                        }
                        print("avg luminance=\(String(format: "%.3f", sum / Double(max(n,1)))) distinctColors=\(distinct.count)")
                    } else {
                        print("snapshot failed: \(String(describing: snapErr))")
                    }
                    exit(0)
                }
            }
        }
    }
}

func jsonString(_ obj: Any) -> String {
    guard let d = try? JSONSerialization.data(withJSONObject: obj),
          let s = String(data: d, encoding: .utf8) else { return "null" }
    return s
}

app.run()
