import AppKit

final class HistoryStore {
    static let shared = HistoryStore()

    private(set) var items: [ClipItem] = []
    let rootDir: URL
    let imagesDir: URL
    private let indexURL: URL

    private var thumbCache: [String: String] = [:]
    private var previewCache: [String: String] = [:]

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        rootDir = base.appendingPathComponent("Local Clipboard", isDirectory: true)
        imagesDir = rootDir.appendingPathComponent("images", isDirectory: true)
        indexURL = rootDir.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
    }

    // MARK: - 持久化

    func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let arr = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        items = arr
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            NSLog("Local Clipboard save failed: \(error)")
        }
    }

    // MARK: - 查询

    func item(_ id: String) -> ClipItem? {
        items.first { $0.id == id }
    }

    /// 置顶优先，其次按时间倒序
    var ordered: [ClipItem] {
        let pinned = items.filter { $0.pinned }.sorted { $0.createdAt > $1.createdAt }
        let normal = items.filter { !$0.pinned }.sorted { $0.createdAt > $1.createdAt }
        return pinned + normal
    }

    func payload() -> [[String: Any]] {
        ordered.map { $0.payload(thumb: thumbDataURL($0)) }
    }

    // MARK: - 写入

    func add(_ item: ClipItem) {
        // 文本类重复内容合并，避免历史被刷屏
        if item.kind != .image,
           let idx = items.firstIndex(where: { $0.kind == item.kind && $0.text == item.text }) {
            let existing = items.remove(at: idx)
            existing.createdAt = item.createdAt
            existing.source = item.source ?? existing.source
            items.append(existing)
            save()
            return
        }
        items.append(item)
        prune()
        save()
    }

    func togglePin(_ id: String) {
        guard let it = item(id) else { return }
        it.pinned.toggle()
        save()
    }

    func delete(_ id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        removeFiles(items[idx])
        items.remove(at: idx)
        save()
    }

    func clear(keepPinned: Bool) {
        if keepPinned {
            for it in items where !it.pinned { removeFiles(it) }
            items.removeAll { !$0.pinned }
        } else {
            for it in items { removeFiles(it) }
            items.removeAll()
        }
        thumbCache.removeAll()
        previewCache.removeAll()
        save()
    }

    private func removeFiles(_ item: ClipItem) {
        thumbCache.removeValue(forKey: item.id)
        previewCache.removeValue(forKey: item.id)
        guard let base = item.imageBase else { return }
        for suffix in [".png", "_thumb.jpg", "_prev.jpg"] {
            try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(base + suffix))
        }
    }

    // MARK: - 自动清理

    func prune() {
        let s = SettingsStore.shared

        // 1. 按条数
        while items.count > s.maxItems {
            guard let idx = items.firstIndex(where: { !$0.pinned }) else { break }
            removeFiles(items[idx])
            items.remove(at: idx)
        }

        // 2. 按天数
        if s.maxDays > 0 {
            let deadline = Date().timeIntervalSince1970 - Double(s.maxDays) * 86400
            let expired = items.filter { !$0.pinned && $0.createdAt < deadline }
            for it in expired { removeFiles(it) }
            items.removeAll { !$0.pinned && $0.createdAt < deadline }
        }

        // 3. 按图片占用
        let limit = Double(s.maxImageMB) * 1024 * 1024
        var imageBytes = Double(items.filter { $0.kind == .image }.reduce(0) { $0 + $1.byteSize })
        if imageBytes > limit {
            let candidates = items.filter { $0.kind == .image && !$0.pinned }
                .sorted { $0.createdAt < $1.createdAt }
            for old in candidates {
                if imageBytes <= limit { break }
                imageBytes -= Double(old.byteSize)
                removeFiles(old)
                items.removeAll { $0.id == old.id }
            }
        }
    }

    // MARK: - 图片资源

    func originalImageURL(_ item: ClipItem) -> URL? {
        guard let base = item.imageBase else { return nil }
        return imagesDir.appendingPathComponent(base + ".png")
    }

    func thumbDataURL(_ item: ClipItem) -> String? {
        guard let base = item.imageBase else { return nil }
        if let cached = thumbCache[item.id] { return cached }
        let url = imagesDir.appendingPathComponent(base + "_thumb.jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let s = "data:image/jpeg;base64," + data.base64EncodedString()
        thumbCache[item.id] = s
        return s
    }

    func previewDataURL(_ item: ClipItem) -> String? {
        guard let base = item.imageBase else { return nil }
        if let cached = previewCache[item.id] { return cached }
        let url = imagesDir.appendingPathComponent(base + "_prev.jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let s = "data:image/jpeg;base64," + data.base64EncodedString()
        previewCache[item.id] = s
        return s
    }

    /// 保存图片，返回 (base, width, height, byteSize)
    func storeImage(_ cg: CGImage) -> (String, Int, Int, Int)? {
        guard let png = ImageUtils.pngData(cg) else { return nil }
        let base = UUID().uuidString
        let original = imagesDir.appendingPathComponent(base + ".png")
        do {
            try png.write(to: original)
        } catch { return nil }
        if let thumb = ImageUtils.scaledJPEG(cg, maxDimension: 420, quality: 0.72) {
            try? thumb.write(to: imagesDir.appendingPathComponent(base + "_thumb.jpg"))
        }
        if let prev = ImageUtils.scaledJPEG(cg, maxDimension: 1400, quality: 0.86) {
            try? prev.write(to: imagesDir.appendingPathComponent(base + "_prev.jpg"))
        }
        return (base, cg.width, cg.height, png.count)
    }

    // MARK: - 统计

    var totalBytes: Int {
        items.reduce(0) { $0 + $1.byteSize }
    }

    var stats: [String: Any] {
        let imageCount = items.filter { $0.kind == .image }.count
        return [
            "count": items.count,
            "images": imageCount,
            "pinned": items.filter { $0.pinned }.count,
            "bytes": totalBytes,
            "bytesText": ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
        ]
    }
}
