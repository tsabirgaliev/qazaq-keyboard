// Renders the "ҚҚ" menu-bar label as a black-on-clear template TIFF (1x + 2x). Usage: swift make_icon.swift out.tiff
import Cocoa

let out = CommandLine.arguments[1]
func rep(scale: CGFloat) -> NSBitmapImageRep {
    let size = NSSize(width: 22, height: 16)
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    r.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.black]
    let s = NSAttributedString(string: "ҚҚ", attributes: attrs)
    let b = s.size()
    s.draw(at: NSPoint(x: (size.width - b.width) / 2, y: (size.height - b.height) / 2))
    NSGraphicsContext.restoreGraphicsState()
    return r
}
let data = NSBitmapImageRep.tiffRepresentationOfImageReps(in: [rep(scale: 1), rep(scale: 2)], using: .lzw, factor: 0)!
try! data.write(to: URL(fileURLWithPath: out))
