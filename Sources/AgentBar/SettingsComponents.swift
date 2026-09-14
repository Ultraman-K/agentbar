import AppKit

/// Base class that re-applies layer-level colors whenever the effective appearance changes.
/// `NSColor.cgColor` captures a single appearance, so layer styling has to be refreshed.
/// Custom controls that own their value change. Mirrors `NSButton.performClick(_:)`
/// so tests exercise the same path as a real click instead of firing the action bare.
@MainActor
protocol SettingsActivating: AnyObject {
    func performActivate()
}

@MainActor
class ThemedView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applyTheme()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyTheme()
        needsDisplay = true
    }

    func applyTheme() {}
}

// MARK: - Surfaces

/// Solid background painted from a theme token, refreshed on appearance changes.
@MainActor
final class SettingsSurfaceView: ThemedView {
    var token: SettingsTheme.Token = .window {
        didSet { applyTheme() }
    }

    init(token: SettingsTheme.Token) {
        self.token = token
        super.init(frame: .zero)
        applyTheme()
    }

    required init?(coder: NSCoder) { nil }

    override func applyTheme() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [self] in
            wantsLayer = true
            layer?.backgroundColor = SettingsTheme.color(token, for: effectiveAppearance).cgColor
        }
    }
}

/// 1px divider painted from the border token.
@MainActor
final class SettingsHairlineView: ThemedView {
    override func applyTheme() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [self] in
            wantsLayer = true
            layer?.backgroundColor = SettingsTheme.color(.border, for: effectiveAppearance).cgColor
        }
    }
}

// MARK: - Selection card

/// Mirrors the prototype's `.qm-radio-option`: fixed control height, 13px horizontal
/// padding, radio glyph then label, purple accent when chosen.
@MainActor
final class SettingsCardControl: NSControl {
    let title: String
    private let dot = RadioDotView()
    private let label = NSTextField(labelWithString: "")

    var isChosen = false {
        didSet {
            dot.isOn = isChosen
            applyTheme()
            setAccessibilityValue(isChosen ? 1 : 0)
        }
    }

    init(title: String, target: AnyObject?, action: Selector?) {
        self.title = title
        super.init(frame: .zero)
        self.target = target
        self.action = action

        wantsLayer = true
        layer?.cornerRadius = SettingsMetrics.controlRadius
        layer?.borderWidth = 1

        dot.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = title
        label.font = .systemFont(ofSize: 13)
        label.textColor = SettingsTheme.dynamic(.text)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(dot)
        addSubview(label)
        let padding = SettingsMetrics.cardPadding
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: SettingsMetrics.controlHeight),
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: SettingsMetrics.radioDotSize),
            dot.heightAnchor.constraint(equalToConstant: SettingsMetrics.radioDotSize),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: SettingsMetrics.chipContentGap),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -padding),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setAccessibilityRole(.radioButton)
        setAccessibilityLabel(title)
        setAccessibilityValue(0)
        applyTheme()
    }

    required init?(coder: NSCoder) { nil }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        performActivate()
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 49 else { return super.keyDown(with: event) }
        performActivate()
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyTheme()
    }

    func applyTheme() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [self] in
            let accent = SettingsTheme.color(.purple, for: effectiveAppearance)
            layer?.borderColor = (isChosen ? accent : SettingsTheme.color(.border, for: effectiveAppearance)).cgColor
            layer?.backgroundColor = isChosen
                ? accent.withAlphaComponent(0.1).cgColor
                : SettingsTheme.color(.popover, for: effectiveAppearance).cgColor
        }
    }
}

extension SettingsCardControl: SettingsActivating {
    func performActivate() {
        sendAction(action, to: target)
    }
}

@MainActor
private final class RadioDotView: NSView {
    var isOn = false {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let selected = isOn
        let ring = selected
            ? SettingsTheme.color(.purple, for: effectiveAppearance)
            : SettingsTheme.color(.muted, for: effectiveAppearance)
        let outer = NSBezierPath(ovalIn: bounds.insetBy(dx: 1.5, dy: 1.5))
        outer.lineWidth = 1.5
        ring.setStroke()
        outer.stroke()
        guard selected else { return }
        ring.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 5, dy: 5)).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - Checkbox

/// Mirrors `.qm-choice input`: a 16 x 16 box with a purple accent and a 7px gap to
/// its label. Drawn by hand because `NSButton`'s checkbox glyph and title colour
/// follow the system appearance instead of this window's tokens.
@MainActor
final class SettingsCheckControl: NSControl {
    let title: String
    private let label = NSTextField(labelWithString: "")
    private let boxSide: CGFloat = 16
    private let boxGap: CGFloat = 7

    var isOn = false {
        didSet {
            needsDisplay = true
            setAccessibilityValue(isOn ? 1 : 0)
        }
    }

    init(title: String, target: AnyObject?, action: Selector?) {
        self.title = title
        super.init(frame: .zero)
        self.target = target
        self.action = action

        label.stringValue = title
        label.font = .systemFont(ofSize: 13)
        label.textColor = SettingsTheme.dynamic(.text)
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)

        setAccessibilityRole(.checkBox)
        setAccessibilityLabel(title)
        setAccessibilityValue(0)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        // Measure the string directly and leave room for the label cell's ~2pt
        // per-side caret inset, otherwise the label truncates to an ellipsis.
        let textWidth = ceil(
            (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width
        )
        return NSSize(width: boxSide + boxGap + textWidth + 4, height: boxSide)
    }

    override func layout() {
        super.layout()
        label.frame = NSRect(
            x: boxSide + boxGap,
            y: 0,
            width: max(0, bounds.width - boxSide - boxGap),
            height: bounds.height
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let origin = NSPoint(x: 0, y: (bounds.height - boxSide) / 2)
        let box = NSRect(origin: origin, size: NSSize(width: boxSide, height: boxSide))
        let path = NSBezierPath(roundedRect: box.insetBy(dx: 0.75, dy: 0.75), xRadius: 4, yRadius: 4)
        let accent = SettingsTheme.color(.purple, for: effectiveAppearance)

        if isOn {
            accent.setFill()
            path.fill()
            let check = NSBezierPath()
            check.move(to: NSPoint(x: box.minX + 4, y: box.minY + box.height / 2))
            check.line(to: NSPoint(x: box.minX + 6.8, y: box.minY + box.height / 2 - 3))
            check.line(to: NSPoint(x: box.maxX - 3.8, y: box.minY + box.height / 2 + 3.6))
            check.lineWidth = 1.8
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSColor.white.setStroke()
            check.stroke()
        } else {
            path.lineWidth = 1.5
            SettingsTheme.color(.muted, for: effectiveAppearance).setStroke()
            path.stroke()
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        performActivate()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 49 else { return super.keyDown(with: event) }
        performActivate()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

extension SettingsCheckControl: SettingsActivating {
    func performActivate() {
        isOn.toggle()
        sendAction(action, to: target)
    }
}

// MARK: - Switch

/// Mirrors the prototype's 40 x 24 switch with a green track when on.
@MainActor
final class SettingsSwitchControl: NSControl {
    var isOn = false {
        didSet {
            needsDisplay = true
            setAccessibilityValue(isOn ? 1 : 0)
        }
    }

    init(target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        setAccessibilityRole(.checkBox)
        setAccessibilityValue(0)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: SettingsMetrics.switchSize.width),
            heightAnchor.constraint(equalToConstant: SettingsMetrics.switchSize.height)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        performActivate()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 49 else { return super.keyDown(with: event) }
        performActivate()
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        (isOn
            ? SettingsTheme.color(.green, for: effectiveAppearance)
            : SettingsTheme.color(.track, for: effectiveAppearance)).setFill()
        track.fill()

        let diameter = bounds.height - 4
        let knob = NSBezierPath(
            ovalIn: NSRect(
                x: isOn ? bounds.maxX - 2 - diameter : 2,
                y: 2,
                width: diameter,
                height: diameter
            )
        )
        NSColor.white.setFill()
        knob.fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

extension SettingsSwitchControl: SettingsActivating {
    func performActivate() {
        isOn.toggle()
        sendAction(action, to: target)
    }
}

// MARK: - Sidebar item

/// Mirrors `.qm-nav-button`: control height, 9px radius, 11px padding, 9px icon gap,
/// surface-hover background and medium weight when selected.
@MainActor
final class SettingsNavItem: NSControl {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    var isChosen = false {
        didSet {
            label.font = .systemFont(ofSize: 13, weight: isChosen ? .medium : .regular)
            iconView.contentTintColor = isChosen
                ? SettingsTheme.dynamic(.text)
                : SettingsTheme.dynamic(.muted)
            applyTheme()
            setAccessibilityValue(isChosen ? 1 : 0)
        }
    }

    init(title: String, systemSymbol: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.target = target
        self.action = action

        wantsLayer = true
        layer?.cornerRadius = SettingsMetrics.controlRadius

        iconView.image = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: title)
        iconView.contentTintColor = SettingsTheme.dynamic(.muted)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown

        label.stringValue = title
        label.font = .systemFont(ofSize: 13)
        label.textColor = SettingsTheme.dynamic(.text)
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: SettingsMetrics.controlHeight),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: SettingsMetrics.navItemIconSize),
            iconView.heightAnchor.constraint(equalToConstant: SettingsMetrics.navItemIconSize),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: SettingsMetrics.navItemIconGap),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -11),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
        setAccessibilityValue(0)
        applyTheme()
    }

    required init?(coder: NSCoder) { nil }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        performActivate()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyTheme()
    }

    func applyTheme() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [self] in
            layer?.backgroundColor = isChosen
                ? SettingsTheme.color(.surfaceHover, for: effectiveAppearance).cgColor
                : NSColor.clear.cgColor
        }
    }
}

extension SettingsNavItem: SettingsActivating {
    func performActivate() {
        sendAction(action, to: target)
    }
}

// MARK: - Buttons

/// Mirrors `.qm-button` / `.qm-button-primary` / `.qm-button-danger`.
@MainActor
final class SettingsButton: NSButton {
    enum Role {
        case plain
        case primary
        case danger
    }

    var role: Role = .plain {
        didSet { applyTheme() }
    }

    init(title: String, role: Role, target: AnyObject?, action: Selector) {
        self.role = role
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        font = .systemFont(ofSize: 13)
        wantsLayer = true
        layer?.cornerRadius = SettingsMetrics.controlRadius
        translatesAutoresizingMaskIntoConstraints = false
        let contentWidth = ceil(
            (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width
        )
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: SettingsMetrics.controlHeight),
            widthAnchor.constraint(equalToConstant: contentWidth + SettingsMetrics.buttonPadding * 2)
        ])
        applyTheme()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyTheme()
    }

    func applyTheme() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [self] in
            let border = SettingsTheme.color(.border, for: effectiveAppearance)
            switch role {
            case .plain:
                layer?.borderWidth = 1
                layer?.borderColor = border.cgColor
                layer?.backgroundColor = SettingsTheme.color(.popover, for: effectiveAppearance).cgColor
                contentTintColor = SettingsTheme.color(.text, for: effectiveAppearance)
            case .primary:
                layer?.borderWidth = 0
                layer?.backgroundColor = SettingsTheme.color(.text, for: effectiveAppearance).cgColor
                contentTintColor = SettingsTheme.color(.window, for: effectiveAppearance)
            case .danger:
                layer?.borderWidth = 1
                layer?.borderColor = border.cgColor
                layer?.backgroundColor = NSColor.clear.cgColor
                contentTintColor = SettingsTheme.color(.red, for: effectiveAppearance)
            }
        }
    }
}

// MARK: - Bordered containers

/// Mirrors `.qm-input` (surface background) and `.qm-choice` (popover background).
@MainActor
final class SettingsBox: ThemedView {
    enum Style {
        case field
        case chip
    }

    private let style: Style
    var isChosen = false {
        didSet { applyTheme() }
    }
    var isFocused = false {
        didSet { applyTheme() }
    }

    init(style: Style, content: NSView) {
        self.style = style
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = SettingsMetrics.controlRadius

        let horizontal = style == .chip ? SettingsMetrics.chipPadding : SettingsMetrics.fieldPadding
        addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: SettingsMetrics.controlHeight),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontal),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontal)
        ])
        applyTheme()
    }

    required init?(coder: NSCoder) { nil }

    override func applyTheme() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [self] in
            let accent = SettingsTheme.color(.purple, for: effectiveAppearance)
            if isChosen {
                layer?.borderWidth = 1
                layer?.borderColor = accent.cgColor
                layer?.backgroundColor = accent.withAlphaComponent(0.1).cgColor
            } else {
                layer?.borderWidth = isFocused ? 2 : 1
                layer?.borderColor = (isFocused
                    ? accent
                    : SettingsTheme.color(.border, for: effectiveAppearance)).cgColor
                layer?.backgroundColor = SettingsTheme.color(backgroundToken, for: effectiveAppearance).cgColor
            }
        }
    }

    private var backgroundToken: SettingsTheme.Token {
        style == .field ? .surface : .popover
    }
}

// MARK: - Fields

/// Bezel-less fields that report focus so the surrounding box can show the focus border.
@MainActor
final class SettingsTextField: NSTextField {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { onFocusChange?(false) }
        return accepted
    }
}

@MainActor
final class SettingsSecureTextField: NSSecureTextField {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { onFocusChange?(false) }
        return accepted
    }
}

// MARK: - Composed rows

/// Mirrors `.qm-connection`: 12px text with a leading glyph, tinted by state.
@MainActor
final class SettingsStatusRow: NSStackView {
    enum Level {
        case normal
        case success
        case failure
    }

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = SettingsMetrics.connectionGap

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
            heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsMetrics.connectionMinHeight)
        ])

        label.font = .systemFont(ofSize: 12)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        addArrangedSubview(iconView)
        addArrangedSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    func render(symbol: String, text: String, level: Level) {
        let color: NSColor = switch level {
        case .normal: SettingsTheme.dynamic(.muted)
        case .success: SettingsTheme.dynamic(.green)
        case .failure: SettingsTheme.dynamic(.red)
        }
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        iconView.contentTintColor = color
        label.stringValue = text
        label.textColor = color
        setAccessibilityLabel(text)
    }
}

/// Mirrors `.qm-setting-vendor`: 14px brand mark + 12px medium title in the text color.
@MainActor
final class VendorHeadingRow: NSStackView {
    init(title: String, brand: String, fallbackSymbol: String) {
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = SettingsMetrics.vendorSpacing

        let image = BrandIconLoader.image(
            named: brand,
            size: NSSize(width: SettingsMetrics.vendorIconSize, height: SettingsMetrics.vendorIconSize)
        ) ?? NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: title) ?? NSImage()
        let iconView = NSImageView(image: image)
        iconView.contentTintColor = SettingsTheme.dynamic(.text)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: SettingsMetrics.vendorIconSize),
            iconView.heightAnchor.constraint(equalToConstant: SettingsMetrics.vendorIconSize),
            heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsMetrics.vendorMinHeight)
        ])

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = SettingsTheme.dynamic(.text)
        label.translatesAutoresizingMaskIntoConstraints = false

        addArrangedSubview(iconView)
        addArrangedSubview(label)
    }

    required init?(coder: NSCoder) { nil }
}
