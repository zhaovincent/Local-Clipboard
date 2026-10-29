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

/// 全局快捷键（Carbon RegisterEventHotKey，无需辅助功能权限）
final class HotKeyManager {
    static let shared = HotKeyManager()

    var handler: (() -> Void)?

    private(set) var isRegistered = false
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    @discardableResult
    func register(code: Int, mods: Int) -> Bool {
        unregister()
        isRegistered = false
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // 'CLIP'
        let status = RegisterEventHotKey(UInt32(code),
                                        UInt32(mods),
                                        hotKeyID,
                                        GetApplicationEventTarget(),
                                        0,
                                        &ref)
        if status == noErr {
            hotKeyRef = ref
            isRegistered = true
            return true
        }
        NSLog("Local Clipboard hotkey register failed: \(status)")
        return false
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            isRegistered = false
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            HotKeyManager.shared.handler?()
            return noErr
        }, 1, &eventType, nil, &handlerRef)
    }
}
