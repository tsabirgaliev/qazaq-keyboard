// Prints the ISO languages macOS reports for an input source, one per line.
// Press-and-hold (long-press) variants are chosen from these, so the first must be "kk".
// Usage: swift tools/languages.swift <input-source-id>
import Carbon
import Foundation

let id = CommandLine.arguments[1]
let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
      let src = list.first,
      let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceLanguages)
else {
    FileHandle.standardError.write("cannot load \(id)\n".data(using: .utf8)!)
    exit(1)
}
for lang in Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as! [String] { print(lang) }
