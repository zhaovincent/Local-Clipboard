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

import Foundation
import AppKit

/// 备份导出 / 导入：history.json + images/ 打包为 zip（借助系统 /usr/bin/ditto，零第三方依赖）
extension HistoryStore {

    // MARK: - 导出

    /// 把全部历史与图片打包成 zip；返回错误文案，nil 表示成功
    func exportData(to zipURL: URL) -> String? {
        let fm = FileManager.default
        save()

        let staging = fm.temporaryDirectory
            .appendingPathComponent("LCExport-\(UUID().uuidString)", isDirectory: true)
        let pkg = staging.appendingPathComponent("Local Clipboard Backup \(Self.transferStamp())", isDirectory: true)
        defer { try? fm.removeItem(at: staging) }

        do {
            try fm.createDirectory(at: pkg.appendingPathComponent("images", isDirectory: true),
                                   withIntermediateDirectories: true)
            if fm.fileExists(atPath: indexURL.path) {
                try fm.copyItem(at: indexURL, to: pkg.appendingPathComponent("history.json"))
            }
            if let files = try? fm.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil) {
                let dstImages = pkg.appendingPathComponent("images", isDirectory: true)
                for f in files {
                    try? fm.copyItem(at: f, to: dstImages.appendingPathComponent(f.lastPathComponent))
                }
            }
            let info: [String: Any] = [
                "app": "Local Clipboard",
                "format": 1,
                "exportedAt": ISO8601DateFormatter().string(from: Date()),
                "count": items.count,
                "images": items.filter { $0.kind == .image }.count
            ]
            try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
                .write(to: pkg.appendingPathComponent("info.json"))

            if fm.fileExists(atPath: zipURL.path) { try fm.removeItem(at: zipURL) }
            let rc = Self.runTool("/usr/bin/ditto", ["-c", "-k", "--keepParent", pkg.path, zipURL.path])
            guard rc == 0 else { return L10n.dittoFailed(rc, "打包备份失败", "Failed to create the backup") }
        } catch {
            return L10n.failed(error.localizedDescription, "导出失败", "Export failed")
        }
        return nil
    }

    // MARK: - 导入

    /// 从 zip 恢复：按 id 与内容去重合并；返回 (新增条数, 提示文案)
    func importData(from zipURL: URL) -> (imported: Int, message: String?) {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory
            .appendingPathComponent("LCImport-\(UUID().uuidString)", isDirectory: true)
        do {
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        } catch {
            return (0, L10n.noTempDir)
        }
        defer { try? fm.removeItem(at: staging) }

        let rc = Self.runTool("/usr/bin/ditto", ["-x", "-k", zipURL.path, staging.path])
        guard rc == 0 else { return (0, L10n.dittoFailed(rc, "无法读取该备份文件", "Cannot read the backup file")) }

        guard let indexFile = Self.findHistoryJSON(in: staging) else {
            return (0, L10n.noHistoryJSON)
        }
        guard let data = try? Data(contentsOf: indexFile),
              let arr = try? JSONDecoder().decode([ClipItem].self, from: data) else {
            return (0, L10n.badBackupFormat)
        }

        // 恢复条目引用的图片文件
        let srcImages = indexFile.deletingLastPathComponent().appendingPathComponent("images", isDirectory: true)
        for it in arr {
            guard let base = it.imageBase else { continue }
            for suffix in [".png", "_thumb.jpg", "_prev.jpg"] {
                let src = srcImages.appendingPathComponent(base + suffix)
                let dst = imagesDir.appendingPathComponent(base + suffix)
                if fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) {
                    try? fm.copyItem(at: src, to: dst)
                }
            }
        }

        let n = mergeImported(arr)
        return (n, n == 0 ? L10n.backupIdentical : nil)
    }

    // MARK: - 工具

    /// 在解压目录里定位 history.json（兼容带/不带外层文件夹两种打包方式）
    private static func findHistoryJSON(in dir: URL) -> URL? {
        let fm = FileManager.default
        let direct = dir.appendingPathComponent("history.json")
        if fm.fileExists(atPath: direct.path) { return direct }
        if let subs = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) {
            for s in subs where (try? s.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                let candidate = s.appendingPathComponent("history.json")
                if fm.fileExists(atPath: candidate.path) { return candidate }
            }
        }
        return nil
    }

    static func transferStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    @discardableResult
    static func runTool(_ path: String, _ args: [String]) -> Int32 {
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
