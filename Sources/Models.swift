import Foundation

enum ClipKind: String, Codable {
    case text
    case image
    case file
    case link
}

final class ClipItem: Codable {
    var id: String
    var kind: ClipKind
    var text: String
    var imageBase: String?
    var width: Int?
    var height: Int?
    var createdAt: Double
    var pinned: Bool
    var source: String?
    var byteSize: Int

    init(id: String = UUID().uuidString,
         kind: ClipKind,
         text: String,
         imageBase: String? = nil,
         width: Int? = nil,
         height: Int? = nil,
         createdAt: Double = Date().timeIntervalSince1970,
         pinned: Bool = false,
         source: String? = nil,
         byteSize: Int = 0) {
        self.id = id
        self.kind = kind
        self.text = text
        self.imageBase = imageBase
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.pinned = pinned
        self.source = source
        self.byteSize = byteSize
    }

    /// 传给前端的数据（文本做长度保护，避免面板 JSON 过大）
    func payload(thumb: String?) -> [String: Any] {
        var d: [String: Any] = [
            "id": id,
            "kind": kind.rawValue,
            "text": String(text.prefix(6000)),
            "createdAt": createdAt,
            "pinned": pinned,
            "size": byteSize
        ]
        if let source, !source.isEmpty { d["source"] = source }
        if let thumb { d["thumb"] = thumb }
        if let width, let height { d["w"] = width; d["h"] = height }
        d["len"] = text.count
        return d
    }
}
