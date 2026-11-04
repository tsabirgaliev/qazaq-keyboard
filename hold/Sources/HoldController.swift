import Cocoa
import InputMethodKit

typealias Client = IMKTextInput & NSObjectProtocol

/// Keyboard-type input method: all typing goes through the bundled "Kazakh - PC+" layout (overrideKeyboard),
/// and only a held letter that has variants is intercepted, ABC-style:
///  - the letter is typed normally on key down; when the key starts repeating, repeats are swallowed and the
///    popup appears above the letter;
///  - 1…9 or a click picks a variant (it replaces the letter); ←/→/Tab highlight one, Return picks it;
///  - Esc keeps the letter; any other key picks the highlighted variant (if any) and is then typed normally;
///    a click elsewhere keeps the letter.
/// Repeats follow ABC: held letters/digits don't repeat, other keys and Cmd/Ctrl shortcuts do.
@objc(HoldController)
final class HoldController: IMKInputController {
    static let layoutName = "Kazakh - PC+"  // the .keylayout in Contents/Resources
    static let panel = PopupPanel()

    private static let numberKeys: [UInt16: Int] = [
        18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8,  // number row 1…9
        83: 0, 84: 1, 85: 2, 86: 3, 87: 4, 88: 5, 89: 6, 91: 7, 92: 8,  // keypad 1…9
    ]
    private static let left: UInt16 = 123, right: UInt16 = 124, tab: UInt16 = 48
    private static let escape: UInt16 = 53, returnKey: UInt16 = 36, enter: UInt16 = 76

    /// The last key down whose repeats we handle: a letter/digit (repeats swallowed, as ABC does) that may also
    /// have variants (a repeat opens the popup).
    private struct Held { let keyCode: UInt16; let base: String; let hasVariants: Bool }
    private struct Session {
        let client: Client
        let keyCode: UInt16
        let base: String
        let items: [String]
        var range: NSRange  // where the base letter (or the previewed variant) is in the client's text
        var selected: Int?
    }
    private var held: Held?
    private var session: Session?
    private var mouseMonitor: Any?
    private var layoutApplied = false

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        applyLayout(inputClient)
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]).rawValue)
    }

    /// Makes the client translate keys with our layout. Apple says to do it on every activation; doing it when the
    /// controller is created (and lazily on the first event) also covers clients that reconnect after the input
    /// method process restarted, which get no activateServer.
    private func applyLayout(_ client: Any?) {
        guard let client = client as? Client else { return }
        client.overrideKeyboard(withKeyboardNamed: Self.layoutName)
        layoutApplied = true
    }

    override func activateServer(_ sender: Any!) {
        applyLayout(sender)
        held = nil
    }

    override func deactivateServer(_ sender: Any!) {
        close()
        held = nil
    }

    override func commitComposition(_ sender: Any!) {
        close()
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? Client else { return false }
        if !layoutApplied { applyLayout(client) }
        switch event.type {
        case .keyDown:
            return keyDown(event, client)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            close()
            held = nil
            return false
        default:
            return false
        }
    }

    // MARK: - Key handling

    private func keyDown(_ e: NSEvent, _ client: Client) -> Bool {
        Log.debug("down code=\(e.keyCode) repeat=\(e.isARepeat) chars=\(e.characters ?? "") mods=\(e.modifierFlags.rawValue) open=\(session != nil)")
        if session != nil { return keyDownWhileOpen(e, client) }
        if e.isARepeat {
            guard let h = held, h.keyCode == e.keyCode else { return false }
            if h.hasVariants {
                if open(h, client) { return true }
                held = Held(keyCode: h.keyCode, base: h.base, hasVariants: false)  // no popup here; don't retry
            }
            return true  // ABC: a held letter or digit doesn't repeat
        }
        held = nil
        // Same rule as ABC's press-and-hold (measured): letters and digits — including Option letters such as
        // ң — don't repeat when held, everything else (punctuation, space, Shift+digit symbols…) does.
        // Cmd/Ctrl combos are shortcuts, not text, and keep repeating. All of it is off when the user has
        // switched press-and-hold off system-wide (`defaults write -g ApplePressAndHoldEnabled -bool false`).
        let mods = e.modifierFlags.intersection([.command, .control])
        if mods.isEmpty, Self.pressAndHoldEnabled, let ch = e.characters, ch.count == 1,
           let c = ch.first, c.isLetter || c.isNumber {
            let hasVariants = !e.modifierFlags.contains(.option) && Variants.table[ch] != nil
            held = Held(keyCode: e.keyCode, base: ch, hasVariants: hasVariants)
        }
        return false  // the layout types the character
    }

    private static var pressAndHoldEnabled: Bool {
        UserDefaults.standard.object(forKey: "ApplePressAndHoldEnabled") as? Bool ?? true
    }

    private func keyDownWhileOpen(_ e: NSEvent, _ client: Client) -> Bool {
        guard let s = session else { return false }
        if e.keyCode == s.keyCode && e.isARepeat { return true }  // still holding the key
        let mods = e.modifierFlags.intersection([.command, .control, .option])
        if mods.isEmpty, let i = Self.numberKeys[e.keyCode], i < s.items.count {
            pick(i)
            return true
        }
        if mods.isEmpty {
            switch e.keyCode {
            case Self.left:
                highlight(s.selected.map { max($0 - 1, 0) } ?? s.items.count - 1)
                return true
            case Self.right, Self.tab:
                highlight(s.selected.map { ($0 + 1) % s.items.count } ?? 0)
                return true
            case Self.escape:
                close()
                return true
            case Self.returnKey, Self.enter:
                if let i = s.selected {
                    pick(i)
                    return true
                }
            default:
                break
            }
        }
        // Any other key: the highlighted variant (if any) replaces the letter, then the key is typed normally.
        if let i = s.selected { pick(i) } else { close() }
        return keyDown(e, client)
    }

    // MARK: - Popup session

    private func open(_ h: Held, _ client: Client) -> Bool {
        guard let items = Variants.table[h.base], !items.isEmpty else { return false }
        let sel = client.selectedRange()
        let len = (h.base as NSString).length
        guard sel.location != NSNotFound, sel.length == 0, sel.location >= len else {
            Log.debug("open: unusable selection \(sel)")
            return false
        }
        let range = NSRange(location: sel.location - len, length: len)
        if let typed = client.attributedSubstring(from: range)?.string, typed != h.base {
            Log.debug("open: text before the caret is not the held letter")
            return false
        }
        let rect = Self.letterRect(client, range)
        session = Session(client: client, keyCode: h.keyCode, base: h.base, items: items, range: range, selected: nil)
        Self.panel.onPick = { [weak self] i in self?.pick(i) }
        Self.panel.show(items, above: rect)
        // Clicks in other apps / elsewhere in the text field close the popup (mouse monitoring needs no permission).
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.close()
            self?.held = nil
        }
        Log.debug("open: \(h.base) -> \(items) at \(range) rect=\(rect)")
        return true
    }

    /// Screen rect of the typed letter: firstRect (most apps), else the line rect, else the mouse position.
    private static func letterRect(_ client: Client, _ range: NSRange) -> NSRect {
        var actual = NSRange(location: NSNotFound, length: 0)
        let first = client.firstRect(forCharacterRange: range, actualRange: &actual)
        if first.origin != .zero || first.size != .zero { return first }
        var line = NSRect.zero
        _ = client.attributes(forCharacterIndex: range.location, lineHeightRectangle: &line)
        if line.origin != .zero || line.size != .zero { return line }
        let m = NSEvent.mouseLocation
        return NSRect(x: m.x, y: m.y, width: 0, height: 0)
    }

    /// Highlights variant `i` in the popup only. (Replacing the text live while arrowing doesn't work: TextEdit
    /// ignores insertText sent while it handles an arrow key, so the text changes only when a variant is picked.)
    private func highlight(_ i: Int) {
        guard var s = session, s.items.indices.contains(i) else { return }
        s.selected = i
        session = s
        Self.panel.select(i)
    }

    /// Replaces the typed letter with variant `i` and closes the popup.
    private func pick(_ i: Int) {
        guard let s = session, s.items.indices.contains(i) else { return }
        s.client.insertText(s.items[i], replacementRange: s.range)
        Log.debug("pick \(s.items[i]) at \(s.range); text now \(s.client.attributedSubstring(from: NSRange(location: s.range.location, length: (s.items[i] as NSString).length))?.string ?? "nil")")
        close()
    }

    private func close() {
        guard session != nil else { return }
        session = nil
        Self.panel.hide()
        if let m = mouseMonitor {
            NSEvent.removeMonitor(m)
            mouseMonitor = nil
        }
    }
}
