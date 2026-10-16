import AppKit
import CodexQuotaCore

enum QuotaVisualColor {
    static func foreground(for alert: QuotaAlert?) -> NSColor {
        switch alert {
        case .warning: .systemYellow
        case .danger: .systemRed
        case .unknown, nil: .secondaryLabelColor
        case .normal: .labelColor
        }
    }
}

enum QuotaRingRenderer {
    /// One `ring + text` line of the stacked status bar metric.
    struct MetricRow {
        let remainingPercent: Int?
        let alert: QuotaAlert?
        let text: String
    }

    private static let ringSize: CGFloat = 9
    private static let fontSize: CGFloat = 9
    /// Fixed, deliberately not the font's line height (10.6pt at 9pt): two of those would
    /// overflow the menu bar. Text is centered on its cap height instead.
    private static let rowHeight: CGFloat = 9
    private static let rowSpacing: CGFloat = 1
    private static let ringTextGap: CGFloat = 2

    /// Draws the rows top-to-bottom, each row being an optional ring with its text to the right.
    /// A status bar button renders a single line, so the stack has to be baked into one image.
    static func stackedImage(rows: [MetricRow], muted: Bool, showsRing: Bool = true) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        let leading = showsRing ? ringSize + ringTextGap : 0
        let textWidth = rows
            .map { ($0.text as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        let size = NSSize(
            width: ceil(leading + textWidth),
            height: rowHeight * CGFloat(rows.count) + rowSpacing * CGFloat(max(0, rows.count - 1))
        )
        let image = NSImage(size: size, flipped: false) { _ in
            for (index, row) in rows.enumerated() {
                // Row 0 is the top row, and the context is bottom-origin (`flipped: false`).
                let rowBottom = size.height - rowHeight * CGFloat(index + 1) - rowSpacing * CGFloat(index)
                let centerY = rowBottom + rowHeight / 2
                if showsRing {
                    drawRing(
                        in: NSRect(
                            x: 0,
                            y: centerY - ringSize / 2,
                            width: ringSize,
                            height: ringSize
                        ),
                        remainingPercent: row.remainingPercent,
                        alert: row.alert,
                        muted: muted
                    )
                }
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: muted ? NSColor.secondaryLabelColor : QuotaVisualColor.foreground(for: row.alert)
                ]
                // `draw(at:)` takes the line box origin, one descender below the baseline.
                let baseline = centerY - font.capHeight / 2
                (row.text as NSString).draw(
                    at: NSPoint(x: leading, y: baseline + font.descender),
                    withAttributes: attributes
                )
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawRing(in rect: NSRect, remainingPercent: Int?, alert: QuotaAlert?, muted: Bool) {
        let lineWidth = max(1.2, rect.width * 0.18)
        let radius = rect.width / 2 - lineWidth / 2 - rect.width * 0.05
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let color = muted ? NSColor.secondaryLabelColor : QuotaVisualColor.foreground(for: alert)
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        track.lineWidth = lineWidth
        color.withAlphaComponent(0.28).setStroke()
        track.stroke()

        guard let remainingPercent else { return }
        let progress = max(0, min(100, remainingPercent))
        guard progress > 0 else { return }
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - CGFloat(progress) * 3.6,
            clockwise: true
        )
        arc.lineCapStyle = .round
        arc.lineWidth = lineWidth
        color.setStroke()
        arc.stroke()
    }
}
