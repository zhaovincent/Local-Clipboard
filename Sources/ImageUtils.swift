import AppKit

enum ImageUtils {
    static func scaledJPEG(_ cg: CGImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        guard w > 0, h > 0 else { return nil }
        let scale = min(1.0, maxDimension / max(w, h))
        let nw = max(1, Int((w * scale).rounded()))
        let nh = max(1, Int((h * scale).rounded()))
        guard let ctx = CGContext(data: nil,
                                  width: nw,
                                  height: nh,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: nw, height: nh))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        guard let out = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: out)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    static func pngData(_ cg: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cg)
        return rep.representation(using: .png, properties: [:])
    }
}
