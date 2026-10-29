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
