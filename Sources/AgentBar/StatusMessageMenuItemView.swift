import AppKit

@MainActor
final class StatusMessageMenuItemView: NSView {
    init(text: String, width: CGFloat = MenuLayout.minimumWidth) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 24))
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .systemRed
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 12, y: 4, width: bounds.width - 24, height: 16)
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }
}
