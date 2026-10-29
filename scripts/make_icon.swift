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
import Foundation

// 生成 Local Clipboard 应用图标（圆角方 + 渐变 + 剪贴板图形）
// 用法: swift scripts/make_icon.swift <输出 iconset 目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    let r = CGFloat((v >> 16) & 0xFF) / 255
    let g = CGFloat((v >> 8) & 0xFF) / 255
    let b = CGFloat(v & 0xFF) / 255
    return CGColor(red: r, green: g, blue: b, alpha: a)
}

func gradient(_ ctx: CGContext, colors: [CGColor], from: CGPoint, to: CGPoint) {
    let space = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(grad, start: from, end: to, options: [])
}

func drawIcon(_ size: CGFloat) -> CGImage? {
    let px = Int(size)
    guard let ctx = CGContext(data: nil, width: px, height: px,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    let s = size / 1024.0
    ctx.scaleBy(x: s, y: s)

    // 底板（squircle）
    let plate = CGPath(roundedRect: CGRect(x: 92, y: 92, width: 840, height: 840),
                       cornerWidth: 205, cornerHeight: 205, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 46,
                  color: CGColor(red: 0.15, green: 0.1, blue: 0.4, alpha: 0.42))
    ctx.addPath(plate)
    ctx.setFillColor(hex(0x6F7BFF))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(plate)
    ctx.clip()
    gradient(ctx, colors: [hex(0x9B7CFF), hex(0x5C7BFF), hex(0x3FC7F5)],
             from: CGPoint(x: 130, y: 950), to: CGPoint(x: 920, y: 110))

    // 顶部高光
    gradient(ctx, colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.30),
                           CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)],
             from: CGPoint(x: 512, y: 932), to: CGPoint(x: 512, y: 560))

    // 底部柔光
    gradient(ctx, colors: [CGColor(red: 0.05, green: 0.0, blue: 0.25, alpha: 0.0),
                           CGColor(red: 0.05, green: 0.0, blue: 0.3, alpha: 0.34)],
             from: CGPoint(x: 512, y: 520), to: CGPoint(x: 512, y: 92))
    ctx.restoreGState()

    // 内描边
    ctx.addPath(plate)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
    ctx.setLineWidth(5)
    ctx.strokePath()

    // ---- 剪贴板图形 ----
    let board = CGRect(x: 330, y: 250, width: 364, height: 452)
    let boardPath = CGPath(roundedRect: board, cornerWidth: 76, cornerHeight: 76, transform: nil)

    // 背后叠影（历史记录）
    for (i, alpha) in [0.20, 0.34].enumerated() {
        let off = CGFloat(22 * (i + 1))
        let back = CGPath(roundedRect: board.insetBy(dx: off * 0.5, dy: 0).offsetBy(dx: -off * 0.9, dy: off * 0.55),
                          cornerWidth: 76, cornerHeight: 76, transform: nil)
        ctx.addPath(back)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha))
        ctx.fillPath()
    }

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 26,
                  color: CGColor(red: 0.05, green: 0.02, blue: 0.3, alpha: 0.32))
    ctx.addPath(boardPath)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // 顶部夹子
    let clip = CGPath(roundedRect: CGRect(x: 442, y: 668, width: 140, height: 78),
                      cornerWidth: 36, cornerHeight: 36, transform: nil)
    ctx.addPath(clip)
    ctx.setFillColor(hex(0x6E6BFF))
    ctx.fillPath()

    // 文本线条
    let bars: [(CGFloat, CGFloat, CGFloat)] = [(410, 560, 206), (410, 486, 150), (410, 412, 178)]
    for (x, y, w) in bars {
        let bar = CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: 28),
                         cornerWidth: 14, cornerHeight: 14, transform: nil)
        ctx.addPath(bar)
        ctx.setFillColor(hex(0x8B8CFF, 0.9))
        ctx.fillPath()
    }

    // 右上角星芒
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 18, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    let star = CGMutablePath()
    let cx: CGFloat = 762, cy: CGFloat = 726, r1: CGFloat = 62, r2: CGFloat = 17
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4 - .pi / 2
        let r = i % 2 == 0 ? r1 : r2
        let p = CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
        if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
    }
    star.closeSubpath()
    ctx.addPath(star)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.fillPath()
    ctx.restoreGState()

    return ctx.makeImage()
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]

for (px, name) in sizes {
    guard let cg = drawIcon(CGFloat(px)) else { continue }
    let rep = NSBitmapImageRep(cgImage: cg)
    rep.size = NSSize(width: px, height: px)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    try? data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}

print("iconset ready: \(outDir)")
