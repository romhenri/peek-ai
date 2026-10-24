// peek-hotkey: atalho global ⌃⌥P que abre o Peek.app (Carbon, funciona em qualquer app e não pede Acessibilidade)
import AppKit
import Carbon

var ref: EventHotKeyRef?
var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Peek.app"))
    return noErr
}, 1, &spec, nil, nil)
RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey),
                    EventHotKeyID(signature: OSType(0x5045_454B), id: 1), GetApplicationEventTarget(), 0, &ref)
NSApplication.shared.run()
