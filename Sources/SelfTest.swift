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

/// LC_SELFTEST=1 时的离线自检：迁移 / 导出 / 导入全链路，全部使用临时目录，不触碰真实用户数据
enum SelfTest {
    static func run() {
        let fm = FileManager.default
        let base = fm.temporaryDirectory
            .appendingPathComponent("LCSelfTest-\(UUID().uuidString)", isDirectory: true)

        // 造一份源数据：2 条文本 + 1 张图（占位文件即可，迁移只做文件拷贝）
        let src = base.appendingPathComponent("A", isDirectory: true)
        let srcImages = src.appendingPathComponent("images", isDirectory: true)
        try? fm.createDirectory(at: srcImages, withIntermediateDirectories: true)
        let items: [ClipItem] = [
            ClipItem(kind: .text, text: "hello selftest", createdAt: 1),
            ClipItem(kind: .link, text: "https://example.com/selftest", createdAt: 2),
            ClipItem(kind: .image, text: "", imageBase: "SELFTESTIMG", width: 10, height: 10, createdAt: 3, byteSize: 4)
        ]
        try? Data("PNG!".utf8).write(to: srcImages.appendingPathComponent("SELFTESTIMG.png"))
        try? JSONEncoder().encode(items).write(to: src.appendingPathComponent("history.json"))

        var failed = false
        func check(_ name: String, _ cond: Bool) {
            NSLog("LC_SELFTEST \(cond ? "PASS" : "FAIL") \(name)")
            if !cond { failed = true }
        }

        // 1. 加载
        let store = HistoryStore(root: src)
        store.load()
        check("load: 3 items", store.items.count == 3)

        // 2. 迁移到 B
        let dst = base.appendingPathComponent("B", isDirectory: true)
        let err = store.migrateData(to: dst)
        check("migrate: no error", err == nil)
        check("migrate: index copied", fm.fileExists(atPath: dst.appendingPathComponent("history.json").path))
        check("migrate: image copied", fm.fileExists(atPath: dst.appendingPathComponent("images/SELFTESTIMG.png").path))
        check("migrate: reloaded 3", store.items.count == 3)
        check("migrate: root moved", store.rootDir.standardizedFileURL.path == dst.standardizedFileURL.path)

        // 3. 导出 zip
        let zip = base.appendingPathComponent("backup.zip")
        let expErr = store.exportData(to: zip)
        let zipSize = (try? fm.attributesOfItem(atPath: zip.path))?[.size] as? Int ?? 0
        check("export: no error", expErr == nil)
        check("export: zip size >200B", zipSize > 200)

        // 4. 导入到空目录 C
        let c = base.appendingPathComponent("C", isDirectory: true)
        try? fm.createDirectory(at: c, withIntermediateDirectories: true)
        let store2 = HistoryStore(root: c)
        let (n, msg) = store2.importData(from: zip)
        check("import: 3 new", n == 3 && msg == nil)
        check("import: image restored", fm.fileExists(atPath: c.appendingPathComponent("images/SELFTESTIMG.png").path))

        // 5. 幂等：重复导入应 0 新增
        let (n2, _) = store2.importData(from: zip)
        check("re-import: dedupe 0", n2 == 0)

        try? fm.removeItem(at: base)
        NSLog("LC_SELFTEST \(failed ? "FAILED" : "ALL PASS")")
        exit(failed ? 1 : 0)
    }
}
