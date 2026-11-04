import Cocoa

/// The ABC-style accent popup: one row of letters with their number keys underneath.
/// A non-activating panel, so the app being typed into keeps focus.
final class PopupPanel: NSPanel {
    var onPick: ((Int) -> Void)?
    private var cells: [CellView] = []
    private let effect = NSVisualEffectView()
    private let stack = NSStackView()

    static let cellSize = NSSize(width: 34, height: 44)
    static let inset: CGFloat = 5

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        effect.material = .popover
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.maskImage = Self.roundedMask(radius: 9)
        stack.orientation = .horizontal
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: Self.inset, left: Self.inset, bottom: Self.inset, right: Self.inset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        contentView = effect
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Shows `items` above `charRect` (screen coordinates of the typed base letter), first cell over the letter.
    func show(_ items: [String], above charRect: NSRect) {
        cells.forEach { $0.removeFromSuperview() }
        cells = items.enumerated().map { i, s in
            let c = CellView(text: s, number: i + 1)
            c.onClick = { [weak self] in self?.onPick?(i) }
            stack.addArrangedSubview(c)
            return c
        }
        let size = NSSize(width: CGFloat(items.count) * Self.cellSize.width + 2 * Self.inset,
                          height: Self.cellSize.height + 2 * Self.inset)
        var origin = NSPoint(x: charRect.midX - Self.inset - Self.cellSize.width / 2, y: charRect.maxY + 4)
        let screen = NSScreen.screens.first { $0.frame.contains(charRect.origin) } ?? NSScreen.main
        if let vis = screen?.visibleFrame {
            if origin.y + size.height > vis.maxY { origin.y = charRect.minY - size.height - 4 }  // no room above: go below
            origin.x = min(max(origin.x, vis.minX), vis.maxX - size.width)
            origin.y = min(max(origin.y, vis.minY), vis.maxY - size.height)
        }
        setFrame(NSRect(origin: origin, size: size), display: true)
        select(nil)
        orderFrontRegardless()
    }

    func select(_ index: Int?) {
        for (i, c) in cells.enumerated() { c.highlighted = (i == index) }
    }

    func hide() { orderOut(nil) }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let d = radius * 2 + 1
        let img = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        img.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        img.resizingMode = .stretch
        return img
    }
}

private final class CellView: NSView {
    var onClick: (() -> Void)?
    var highlighted = false { didSet { updateColors(); needsDisplay = true } }
    private let letter = NSTextField(labelWithString: "")
    private let number = NSTextField(labelWithString: "")

    init(text: String, number n: Int) {
        super.init(frame: NSRect(origin: .zero, size: PopupPanel.cellSize))
        letter.stringValue = text
        letter.font = .systemFont(ofSize: 20)
        letter.alignment = .center
        number.stringValue = "\(n)"
        number.font = .systemFont(ofSize: 10)
        number.alignment = .center
        for v in [letter, number] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
            v.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PopupPanel.cellSize.width),
            heightAnchor.constraint(equalToConstant: PopupPanel.cellSize.height),
            letter.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            number.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }

    override func draw(_ dirtyRect: NSRect) {
        guard highlighted else { return }
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
    }

    private func updateColors() {
        letter.textColor = highlighted ? .white : .labelColor
        number.textColor = highlighted ? .white : .secondaryLabelColor
    }
}
