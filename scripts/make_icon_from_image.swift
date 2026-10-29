import AppKit
import Foundation

// 从设计稿图片生成 macOS 图标集（iconset）
// 用法: swift scripts/make_icon_from_image.swift <源图> <输出目录> [页头图输出路径]
//
// 处理逻辑：
// 1) 设计稿通常是「白底 + 居中圆角方图版」，先按饱和度/亮度分割出图版，得到精确 bbox
// 2) 按 bbox 正方形裁切（宽高不一致时取小边、居中），非等比轻微缩放（<5%，不可见）
// 3) 放入 1024 画布：透明底 + 苹果式投影 + squircle 圆角裁切（半径 185.4/824）
// 4) 输出 iconset 全尺寸 + 可选页头图

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("用法: make_icon_from_image.swift <源图> <输出目录> [页头图输出路径]")
    exit(1)
}
let srcPath = args[1]
let outDir = args[2]
let headerPath: String? = args.count > 3 ? args[3] : nil

guard let srcImage = NSImage(contentsOfFile: srcPath),
      let srcRep = NSBitmapImageRep(data: srcImage.tiffRepresentation!),
      let srcCG = srcRep.cgImage else {
    print("错误: 无法读取源图 \(srcPath)")
    exit(1)
}

let W = srcCG.width, H = srcCG.height
print("源图: \(W)x\(H)")

// ---- 读入像素缓冲 ----
let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: W * H * 4)
defer { buf.deallocate() }
guard let readCtx = CGContext(data: buf, width: W, height: H, bitsPerComponent: 8,
                             bytesPerRow: W * 4, space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    print("错误: 像素缓冲创建失败"); exit(1)
}
readCtx.draw(srcCG, in: CGRect(x: 0, y: 0, width: W, height: H))

@inline(__always) func isPlate(_ x: Int, _ y: Int) -> Bool {
    let i = (y * W + x) * 4
    let r = Int(buf[i]), g = Int(buf[i + 1]), b = Int(buf[i + 2])
    let mx = max(r, max(g, b)), mn = min(r, min(g, b))
    let sat = mx == 0 ? 0.0 : Double(mx - mn) / Double(mx)
    let lum = Double(r * 299 + g * 587 + b * 114) / 1000.0
    return sat > 0.06 || lum < 200
}

// ---- 逐行/逐列统计，抗阴影抗光晕 ----
var rowCount = [Int](repeating: 0, count: H)
var colCount = [Int](repeating: 0, count: W)
for y in 0..<H {
    for x in 0..<W {
        if isPlate(x, y) { rowCount[y] += 1; colCount[x] += 1 }
    }
}
let maxRow = rowCount.max() ?? 0, maxCol = colCount.max() ?? 0
let rowTh = Int(Double(maxRow) * 0.45), colTh = Int(Double(maxCol) * 0.45)

var y0 = 0, y1 = H - 1, x0 = 0, x1 = W - 1
while y0 < H - 1 && rowCount[y0] < rowTh { y0 += 1 }
while y1 > 0 && rowCount[y1] < rowTh { y1 -= 1 }
while x0 < W - 1 && colCount[x0] < colTh { x0 += 1 }
while x1 > 0 && colCount[x1] < colTh { x1 -= 1 }

var bw = x1 - x0 + 1, bh = y1 - y0 + 1
if bw < W / 2 || bh < H / 2 {           // 分割失败，退回整图
    print("警告: 未识别到图版边界，使用整图")
    x0 = 0; y0 = 0; bw = W; bh = H
}
print("图版 bbox: x \(x0)...\(x1)  y \(y0)...\(y1)  宽 \(bw) 高 \(bh)")

// ---- 正方形裁切 ----
// 顶部/左右边缘锐利可靠，底部是柔和渐隐（设计稿底部渐白），
// 因此以顶边为锚点向下取 side，保证裁切落在图版内部、不代入白底。
let side = min(bw, bh)
let cropX = x0 + (bw - side) / 2
let cropY = y0
let cropRect = CGRect(x: cropX, y: cropY, width: side, height: side)
guard let cropped = srcCG.cropping(to: cropRect) else {
    print("错误: 裁切失败"); exit(1)
}
print("裁切: \(Int(cropRect.origin.x)),\(Int(cropRect.origin.y)) \(side)x\(side)")

// ---- 合成 1024 母版 ----
let master = 1024
let plateInset = 100.0                       // 苹果图标网格：824x824 居中
let plateSide = Double(master) - plateInset * 2
let cornerRadius = plateSide * (185.4 / 824.0)   // 苹果 squircle 近似半径
let imageInset = 2.0                        // 图版向内缩 2px，保证圆角处不露白边

guard let ctx = CGContext(data: nil, width: master, height: master,
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    print("错误: 画布创建失败"); exit(1)
}
ctx.setAllowsAntialiasing(true)
ctx.interpolationQuality = .high
ctx.clear(CGRect(x: 0, y: 0, width: master, height: master))

let plateRect = CGRect(x: plateInset, y: plateInset, width: plateSide, height: plateSide)
let platePath = CGPath(roundedRect: plateRect, cornerWidth: cornerRadius,
                       cornerHeight: cornerRadius, transform: nil)

// 1) 投影（先画，被图版覆盖后只留外扩阴影）
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40,
              color: CGColor(red: 0.06, green: 0.04, blue: 0.20, alpha: 0.40))
ctx.addPath(platePath)
ctx.setFillColor(CGColor(red: 0.10, green: 0.08, blue: 0.26, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// 2) 圆角裁切后铺入设计稿
ctx.saveGState()
ctx.addPath(platePath)
ctx.clip()
ctx.draw(cropped, in: plateRect.insetBy(dx: imageInset, dy: imageInset))

// 3) 顶部极淡高光，贴合系统玻璃质感（不改变设计稿主色）
if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.16),
                                  CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)] as CFArray,
                         locations: [0, 1]) {
    let mid = Double(master) / 2
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: mid, y: plateRect.maxY),
                           end: CGPoint(x: mid, y: plateRect.midY + plateSide * 0.22),
                           options: [])
}
ctx.restoreGState()

// 4) 内描边（苹果图标常见的 1px 亮边）
ctx.addPath(platePath)
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
ctx.setLineWidth(3)
ctx.strokePath()

guard let masterCG = ctx.makeImage() else { print("错误: 母版生成失败"); exit(1) }

// ---- 输出 iconset ----
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func writePNG(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
}

func scaled(_ image: CGImage, _ size: Int) -> CGImage? {
    guard let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    c.interpolationQuality = .high
    c.setAllowsAntialiasing(true)
    c.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return c.makeImage()
}

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in variants {
    guard let img = size == master ? masterCG : scaled(masterCG, size) else { continue }
    writePNG(img, to: "\(outDir)/\(name)")
}
print("已生成 iconset: \(outDir)")

if let headerPath = headerPath, let header = scaled(masterCG, 128) {
    if let dir = (headerPath as NSString).deletingLastPathComponent as String?,
       !dir.isEmpty {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }
    writePNG(header, to: headerPath)
    print("已生成页头图: \(headerPath)")
}
