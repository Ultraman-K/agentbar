import AppKit
import CodexQuotaCore

@MainActor
final class CodexMenuSectionView: NSView {
    private let cardsView: QuotaCardMenuItemView
    private let resetTitle = NSTextField(labelWithString: "完整重置")
    private let resetExpiry = NSTextField(labelWithString: "")
    private let resetCount = NSTextField(labelWithString: "")
    private let freshness = NSTextField(labelWithString: "")
    private let freshnessDot = NSView()

    init(cards: [QuotaCardDisplay], resetCredits: RateLimitResetCredits?, displayState: QuotaDisplayState, freshnessText: String?, width: CGFloat = MenuLayout.minimumWidth, now: Date = .now) {
        cardsView = QuotaCardMenuItemView(cards: cards, leadingInset: 14)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 330))

        let heading = textLabel("Codex", size: 16, weight: .medium)
        let meta = textLabel("额度与重置", size: 12, weight: .regular)
        let header = NSView(frame: .zero)
        header.addSubview(heading)
        header.addSubview(meta)
        addSubview(header)
        addSubview(cardsView)

        let summary = QuotaPresentation.resetSummary(resetCredits, now: now)
        if let summary {
            resetTitle.font = .systemFont(ofSize: 13, weight: .medium)
            resetTitle.textColor = .labelColor
            resetExpiry.stringValue = summary.nearestExpiry.map { "最近 \($0) 到期" } ?? "到期时间未知"
            resetExpiry.font = .systemFont(ofSize: 12)
            resetExpiry.textColor = .secondaryLabelColor
            resetCount.stringValue = "\(summary.count) 次"
            resetCount.font = .systemFont(ofSize: 13, weight: .medium)
            resetCount.alignment = .right
            addSubview(resetTitle)
            addSubview(resetExpiry)
            addSubview(resetCount)
        }

        freshness.stringValue = freshnessText ?? (displayState == .live ? "实时" : "数据暂不可用")
        freshness.font = .systemFont(ofSize: 12)
        freshness.textColor = displayState == .live ? .systemGreen : .secondaryLabelColor
        freshnessDot.wantsLayer = true
        freshnessDot.layer?.cornerRadius = 4
        freshnessDot.layer?.backgroundColor = (displayState == .live ? NSColor.systemGreen : NSColor.secondaryLabelColor).cgColor
        addSubview(freshnessDot)
        addSubview(freshness)

        header.frame = NSRect(x: 0, y: 286, width: bounds.width, height: 44)
        heading.frame = NSRect(x: 14, y: 20, width: bounds.width - 28, height: 20)
        meta.frame = NSRect(x: 14, y: 2, width: bounds.width - 28, height: 17)
        cardsView.frame = NSRect(x: 0, y: 96, width: bounds.width, height: 184)
        resetTitle.frame = NSRect(x: 14, y: 70, width: 92, height: 18)
        resetExpiry.frame = NSRect(x: 14, y: 49, width: bounds.width - 28, height: 17)
        resetCount.frame = NSRect(x: bounds.width - 58, y: 70, width: 44, height: 18)
        freshnessDot.frame = NSRect(x: 14, y: 18, width: 8, height: 8)
        freshness.frame = NSRect(x: 29, y: 13, width: bounds.width - 43, height: 18)
    }

    required init?(coder: NSCoder) { nil }
}

@MainActor
final class DeepSeekMenuItemView: NSView {
    init(snapshot: DeepSeekBalanceSnapshot?, state: DeepSeekDisplayState, width: CGFloat = MenuLayout.minimumWidth) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 142))
        let heading = textLabel("DeepSeek", size: 16, weight: .medium)
        let meta = textLabel("API 余额", size: 12, weight: .regular)
        let value = textLabel(snapshot?.cnyBalance.map { "¥\($0.total.formatted(.number.precision(.fractionLength(2))))" } ?? "配置 API Key 后显示余额", size: snapshot == nil ? 13 : 24, weight: .medium)
        value.textColor = snapshot == nil ? .secondaryLabelColor : .labelColor
        addSubview(heading)
        addSubview(meta)
        addSubview(value)
        heading.frame = NSRect(x: 14, y: 105, width: bounds.width - 28, height: 20)
        meta.frame = NSRect(x: 14, y: 87, width: bounds.width - 28, height: 17)
        value.frame = NSRect(x: 14, y: 49, width: bounds.width - 28, height: 28)

        let freshness = textLabel(freshnessText(snapshot: snapshot, state: state), size: 12, weight: .regular)
        freshness.textColor = state == .live ? .systemGreen : .secondaryLabelColor
        let dot = NSView(frame: NSRect(x: 14, y: 20, width: 8, height: 8))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = (state == .live ? NSColor.systemGreen : NSColor.secondaryLabelColor).cgColor
        addSubview(dot)
        freshness.frame = NSRect(x: 29, y: 15, width: bounds.width - 43, height: 18)
        addSubview(freshness)
    }

    required init?(coder: NSCoder) { nil }

    private func freshnessText(snapshot: DeepSeekBalanceSnapshot?, state: DeepSeekDisplayState) -> String {
        guard let updatedAt = snapshot?.updatedAt else { return "数据暂不可用" }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = Calendar.current.isDateInToday(updatedAt) ? "'实时 · 今天' HH:mm" : "'上次更新' M月d日 HH:mm"
        return formatter.string(from: updatedAt)
    }
}

@MainActor
private func textLabel(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: size, weight: weight)
    label.lineBreakMode = .byTruncatingTail
    return label
}
