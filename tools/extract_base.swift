// Dumps per-key output of macOS keyboard layouts via UCKeyTranslate to JSON.
// Usage: swift tools/extract_base.swift build/base.json
import Carbon
import Foundation

// Usage: extract_base.swift OUT.json [register:/path/to.bundle ...] [source-id ...]
// With no source ids given, dumps the Russian PC and US layouts.
var sources = ["com.apple.keylayout.RussianWin", "com.apple.keylayout.US"]
let extra = Array(CommandLine.arguments.dropFirst(2))
if !extra.isEmpty {
    sources = []
    for a in extra {
        if a.hasPrefix("register:") {
            let url = URL(fileURLWithPath: String(a.dropFirst(9))) as CFURL
            let st = TISRegisterInputSource(url)
            FileHandle.standardError.write("register status \(st)\n".data(using: .utf8)!)
        } else { sources.append(a) }
    }
}
// Carbon modifier bits >> 8
let states: [(String, UInt32)] = [
    ("base", 0), ("shift", 2), ("caps", 4), ("option", 8),
    ("optionShift", 10), ("capsOption", 12), ("command", 1),
    ("commandShift", 3), ("commandOption", 9), ("commandOptionShift", 11), ("control", 16),
]
// 40 = ANSI, 41 = ISO (kKeyboardISO)
let kbdTypes: [(String, UInt32)] = [("ansi", 40), ("iso", 41), ("jis", 42)]

func layoutData(_ id: String) -> Data? {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
          let src = list.first,
          let ptr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData)
    else { return nil }
    return Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
}

var result: [String: Any] = [:]
for id in sources {
    guard let data = layoutData(id) else {
        FileHandle.standardError.write("cannot load \(id)\n".data(using: .utf8)!)
        exit(1)
    }
    var perType: [String: Any] = [:]
    for (tname, ttype) in kbdTypes {
        var perState: [String: Any] = [:]
        for (sname, mods) in states {
            var keys: [String: Any] = [:]
            for code in 0..<128 {
                var dead: UInt32 = 0
                var len = 0
                var chars = [UniChar](repeating: 0, count: 8)
                let status = data.withUnsafeBytes { raw -> OSStatus in
                    let layout = raw.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self)
                    return UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDown), mods,
                                          ttype, 0, &dead, 8, &len, &chars)
                }
                if status != 0 { continue }
                let s = String(utf16CodeUnits: chars, count: len)
                if dead != 0 && len == 0 {
                    keys[String(code)] = ["dead": true]
                } else {
                    keys[String(code)] = ["out": s]
                }
            }
            perState[sname] = keys
        }
        perType[tname] = perState
    }
    result[id] = perType
}
let json = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try json.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote \(CommandLine.arguments[1])")
