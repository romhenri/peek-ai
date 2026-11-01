// peek-hotkey: atalho global ⌃⌥P que abre o Peek.app (Carbon, funciona em qualquer app e não pede Acessibilidade)
// ⌃⌥P sozinho usa prompts/answer.txt; ⌃⌥P seguido de uma letra usa o prompt dela (⌃⌥P, I = info)
// O nome do prompt vai em .prompt, que o peek.sh lê
import AppKit
import Carbon

// Nova variação: adicione a letra aqui e crie prompts/<nome>.txt
let followers: [(key: Int, prompt: String)] = [
    (kVK_ANSI_I, "info"),
]
let wait = 0.8   // segundos esperando a letra antes de cair no answer
let promptFile = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent(".prompt")
let target = GetApplicationEventTarget()
let sig = OSType(0x5045_454B)

var armed: [EventHotKeyRef] = []
var timeout: DispatchWorkItem?

func fire(_ prompt: String) {
    timeout?.cancel(); timeout = nil
    armed.forEach { UnregisterEventHotKey($0) }; armed = []
    try? prompt.write(to: promptFile, atomically: true, encoding: .utf8)
    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Peek.app"))
}

// Depois do ⌃⌥P, as letras ficam presas só durante a espera (com e sem ⌃⌥, caso ainda estejam pressionados)
func arm() {
    for (i, f) in followers.enumerated() {
        for mods in [0, controlKey | optionKey] {
            var ref: EventHotKeyRef?
            if RegisterEventHotKey(UInt32(f.key), UInt32(mods), EventHotKeyID(signature: sig, id: UInt32(i + 1)), target, 0, &ref) == noErr,
               let ref { armed.append(ref) }
        }
    }
    let item = DispatchWorkItem { fire("answer") }
    timeout = item
    DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: item)
}

var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
InstallEventHandler(target, { _, event, _ in
    var id = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                      nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    if id.id == 0 { if timeout == nil { arm() } } else { fire(followers[Int(id.id) - 1].prompt) }
    return noErr
}, 1, &spec, nil, nil)
var ref: EventHotKeyRef?
RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey), EventHotKeyID(signature: sig, id: 0), target, 0, &ref)
NSApplication.shared.run()
