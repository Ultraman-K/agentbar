import AppKit
import CodexQuotaCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    /// How far the metric block's center sits above the title baseline. Matches the previous
    /// single-ring layout (bounds `y: -2` + a 14pt image), so the ¥ balance stays centered.
    private static let metricCenterAboveBaseline: CGFloat = 5
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onRefresh: () -> Void
    private let onToggleLaunchAtLogin: () -> Void
    private let onToggleCompactMode: () -> Void
    private let onConfigureProxy: () -> Void
    private let onOpenSettings: () -> Void
    private var currentDisplay = QuotaPresentation.make(snapshot: nil)
    private var deepSeekSnapshot: DeepSeekBalanceSnapshot?
    private var deepSeekState: DeepSeekDisplayState = .unavailable
    private var statusPreferences: StatusBarPreferences
    private var launchAtLoginEnabled = false
    private var displayMode: StatusBarDisplayMode
    private var statusItemWidth: CGFloat?
    private var isRefreshing = false
    private var errorMessage: String?
    private var proxyMenuText: String

    init(
        onRefresh: @escaping () -> Void,
        onToggleLaunchAtLogin: @escaping () -> Void,
        onToggleCompactMode: @escaping () -> Void,
        onConfigureProxy: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void = {},
        proxyMenuText: String,
        displayMode: StatusBarDisplayMode,
        statusPreferences: StatusBarPreferences = .load()
    ) {
        self.onRefresh = onRefresh
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        self.onToggleCompactMode = onToggleCompactMode
        self.onConfigureProxy = onConfigureProxy
        self.onOpenSettings = onOpenSettings
        self.statusPreferences = statusPreferences
        self.proxyMenuText = proxyMenuText
        self.displayMode = displayMode
        super.init()
        render(display: currentDisplay)
        item.menu = makeMenu()
    }

    func render(snapshot: QuotaSnapshot?) {
        render(result: .init(snapshot: snapshot, state: snapshot == nil ? .unavailable : .live))
    }

    func render(result: QuotaRefreshResult) {
        currentDisplay = QuotaPresentation.make(result: result)
        render(display: currentDisplay)
        item.menu = makeMenu()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginEnabled = enabled
        item.menu = makeMenu()
    }

    func setDisplayMode(_ mode: StatusBarDisplayMode) {
        displayMode = mode
        render(display: currentDisplay)
        item.menu = makeMenu()
    }

    func setRefreshing(_ refreshing: Bool) {
        isRefreshing = refreshing
        item.menu = makeMenu()
    }

    func setError(_ message: String?) {
        errorMessage = message
        item.menu = makeMenu()
    }

    func setProxyMenuText(_ text: String) {
        proxyMenuText = text
        item.menu = makeMenu()
    }

    func render(deepSeek result: DeepSeekBalanceResult) {
        deepSeekSnapshot = result.snapshot
        deepSeekState = result.state
        render(display: currentDisplay)
        item.menu = makeMenu()
    }

    func setStatusPreferences(_ preferences: StatusBarPreferences) {
        statusPreferences = preferences
        statusItemWidth = nil
        render(display: currentDisplay)
        item.menu = makeMenu()
    }

    private func render(display: QuotaDisplay) {
        guard let button = item.button else { return }
        let title = statusTitle(display: display)
        if title.length == 0 {
            statusItemWidth = nil
            item.length = NSStatusItem.squareLength
            button.attributedTitle = NSAttributedString(string: "")
            button.title = ""
            button.image = NSApp.applicationIconImage
            button.imagePosition = .imageOnly
        } else {
            let renderedTitle = NSMutableAttributedString(attributedString: title)
            renderedTitle.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: 13),
                range: NSRange(location: 0, length: renderedTitle.length)
            )
            let measuredWidth = ceil(renderedTitle.size().width)
            statusItemWidth = max(statusItemWidth ?? 0, measuredWidth)
            item.length = max(NSStatusItem.squareLength, statusItemWidth ?? measuredWidth)
            button.image = nil
            button.imagePosition = .noImage
            button.alignment = .left
            button.attributedTitle = renderedTitle
        }
        button.toolTip = display.tooltip
        button.setAccessibilityLabel(display.tooltip)
    }

    private func statusTitle(display: QuotaDisplay) -> NSAttributedString {
        customStatusTitle(
            display: display,
            showCodexRing: statusPreferences.showCodexRing,
            showCodexQuota: statusPreferences.showCodexQuota,
            showDeepSeekBalance: statusPreferences.showDeepSeekBalance
        )
    }

    private func customStatusTitle(
        display: QuotaDisplay,
        showCodexRing: Bool,
        showCodexQuota: Bool,
        showDeepSeekBalance: Bool
    ) -> NSAttributedString {
        let codexGroup: NSAttributedString
        let cards = [
            display.cards.first(where: { $0.title == "5 小时使用限制" }),
            display.cards.first(where: { $0.title == "每周使用限额" })
        ]
        let labels = ["5h", "7d"]
        let rows = cards.enumerated().compactMap { index, card -> QuotaRingRenderer.MetricRow? in
            guard let card, showCodexRing || showCodexQuota else { return nil }
            return QuotaRingRenderer.MetricRow(
                remainingPercent: showCodexRing ? card.remainingPercent : nil,
                alert: card.alert,
                text: showCodexQuota ? "\(labels[index]) \(card.remainingPercent)%" : labels[index]
            )
        }
        codexGroup = rows.isEmpty ? NSAttributedString() : stackedMetrics(rows, muted: display.isStale, showsRing: showCodexRing)
        let deepSeekGroup = NSMutableAttributedString()
        if showDeepSeekBalance {
            if let balance = deepSeekSnapshot?.cnyBalance {
                deepSeekGroup.append(NSAttributedString(string: "¥\(balance.total.formatted(.number.precision(.fractionLength(2))))", attributes: [.foregroundColor: NSColor.labelColor]))
            } else {
                deepSeekGroup.append(NSAttributedString(string: "¥--", attributes: [.foregroundColor: NSColor.secondaryLabelColor]))
            }
        }

        let title = NSMutableAttributedString()
        if codexGroup.length > 0 { title.append(codexGroup) }
        if deepSeekGroup.length > 0 {
            if title.length > 0 { title.append(separator("｜")) }
            title.append(deepSeekGroup)
        }
        return title
    }

    private func separator(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.foregroundColor: NSColor.secondaryLabelColor])
    }

    /// The rows share one image because a status bar button only renders a single line.
    private func stackedMetrics(_ rows: [QuotaRingRenderer.MetricRow], muted: Bool, showsRing: Bool) -> NSAttributedString {
        let image = QuotaRingRenderer.stackedImage(rows: rows, muted: muted, showsRing: showsRing)
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(
            x: 0,
            y: Self.metricCenterAboveBaseline - image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        )
        return NSAttributedString(attachment: attachment)
    }

    private var menuContentWidth: CGFloat {
        max(MenuLayout.minimumWidth, ceil(item.length))
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        let contentWidth = menuContentWidth
        menu.minimumWidth = contentWidth
        menu.autoenablesItems = false
        if currentDisplay.cards.isEmpty {
            for line in currentDisplay.tooltip.split(separator: "\n", omittingEmptySubsequences: false) {
                let detail = NSMenuItem(title: String(line), action: nil, keyEquivalent: "")
                detail.isEnabled = false
                menu.addItem(detail)
            }
        } else {
            let codexSection = NSMenuItem()
            codexSection.view = CodexMenuSectionView(
                cards: currentDisplay.cards,
                resetCredits: currentDisplay.resetCredits,
                displayState: currentDisplay.state,
                freshnessText: currentDisplay.detailStatusText,
                width: contentWidth
            )
            menu.addItem(codexSection)
            menu.addItem(.separator())
        }
        let deepSeek = NSMenuItem()
        deepSeek.view = DeepSeekMenuItemView(snapshot: deepSeekSnapshot, state: deepSeekState, width: contentWidth)
        menu.addItem(deepSeek)
        if let errorMessage {
            let error = NSMenuItem()
            error.view = StatusMessageMenuItemView(text: errorMessage, width: contentWidth)
            menu.addItem(error)
        }
        if let retryText = currentDisplay.retryText {
            let retry = NSMenuItem(title: retryText, action: nil, keyEquivalent: "")
            retry.isEnabled = false
            menu.addItem(retry)
        }
        menu.addItem(.separator())
        let refresh = NSMenuItem(title: isRefreshing ? "正在刷新…" : "立即刷新", action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self
        refresh.keyEquivalentModifierMask = [.command]
        refresh.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "立即刷新")
        refresh.isEnabled = !isRefreshing
        menu.addItem(refresh)
        let settings = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        settings.keyEquivalentModifierMask = [.command]
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置")
        menu.addItem(settings)
        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        quit.keyEquivalentModifierMask = [.command]
        quit.image = NSImage(systemSymbolName: "power", accessibilityDescription: "退出")
        menu.addItem(quit)
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard let refreshItem = menu.items.first(where: { $0.action == #selector(refresh) }) else { return }
        refreshItem.isEnabled = !isRefreshing
    }

    @objc private func refresh(_ sender: NSMenuItem) {
        guard !isRefreshing else { return }
        let trackingMenu = sender.menu
        sender.title = "正在刷新…"
        sender.isEnabled = false
        onRefresh()
        DispatchQueue.main.async {
            trackingMenu?.cancelTrackingWithoutAnimation()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func toggleLaunchAtLogin() {
        onToggleLaunchAtLogin()
    }

    @objc private func toggleCompactMode() {
        onToggleCompactMode()
    }

    @objc private func configureProxy() {
        onConfigureProxy()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
