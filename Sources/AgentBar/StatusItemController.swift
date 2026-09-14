import AppKit
import CodexQuotaCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
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
        item.length = reservedStatusItemWidth
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
        item.length = reservedStatusItemWidth
        render(display: currentDisplay)
        item.menu = makeMenu()
    }

    private func render(display: QuotaDisplay) {
        guard let button = item.button else { return }
        let title = statusTitle(display: display)
        if title.length == 0 {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = ""
            button.image = NSApp.applicationIconImage
            button.imagePosition = .imageOnly
        } else {
            button.image = nil
            button.imagePosition = .noImage
            button.attributedTitle = title
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
        let codexGroup = NSMutableAttributedString()
        var codexParts: [NSAttributedString] = []
        let cards = [
            display.cards.first(where: { $0.title == "5 小时使用限制" }),
            display.cards.first(where: { $0.title == "每周使用限额" })
        ]
        let labels = ["5h", "7d"]
        if showCodexRing {
            for index in cards.indices {
                guard let card = cards[index] else { continue }
                codexParts.append(metricText(showCodexQuota ? "\(labels[index]) \(card.remainingPercent)%" : labels[index], card: card, muted: display.isStale))
            }
        } else if showCodexQuota {
            let values = cards.enumerated().compactMap { index, card in card.map { "\(labels[index]) \($0.remainingPercent)%" } }
            if !values.isEmpty {
                let combined = NSMutableAttributedString()
                for (index, value) in values.enumerated() {
                    if index > 0 { combined.append(separator(" · ")) }
                    combined.append(NSAttributedString(string: value, attributes: [.foregroundColor: QuotaVisualColor.foreground(for: cards[index]?.alert)]))
                }
                codexParts.append(combined)
            }
        }
        if !codexParts.isEmpty {
            codexGroup.append(codexParts[0])
            if codexParts.count > 1 {
                codexGroup.append(separator(" · "))
                codexGroup.append(codexParts[1])
            }
        }
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
            if title.length > 0 { title.append(separator(" ｜ ")) }
            title.append(deepSeekGroup)
        }
        return title
    }

    private func separator(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.foregroundColor: NSColor.secondaryLabelColor])
    }

    private func metricText(_ text: String, card: QuotaCardDisplay?, muted: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let attachment = NSTextAttachment()
        attachment.image = QuotaRingRenderer.image(remainingPercent: card?.remainingPercent, alert: card?.alert, muted: muted)
        attachment.bounds = NSRect(x: 0, y: -2, width: 14, height: 14)
        result.append(NSAttributedString(attachment: attachment))
        result.append(NSAttributedString(string: " \(text)", attributes: [.foregroundColor: muted ? NSColor.secondaryLabelColor : QuotaVisualColor.foreground(for: card?.alert)]))
        return result
    }

    private var menuContentWidth: CGFloat {
        max(MenuLayout.minimumWidth, ceil(item.length))
    }

    /// Reserve width from the configured elements, not the current numbers.
    /// Percentages and balances change digits over time; a fixed reservation keeps
    /// the status item from crossing the notch/menu-bar visibility threshold.
    private var reservedStatusItemWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 13)
        let textWidth: (String) -> CGFloat = { text in
            ceil((text as NSString).size(withAttributes: [.font: font]).width)
        }
        let separatorWidth = textWidth(" · ")
        var groups: [CGFloat] = []

        var codexWidth: CGFloat = 0
        if statusPreferences.showCodexRing {
            let ringItemWidth = { (label: String) in
                CGFloat(14) + textWidth(" ") + textWidth(label)
            }
            codexWidth = ringItemWidth(statusPreferences.showCodexQuota ? "5h 100%" : "5h")
                + separatorWidth
                + ringItemWidth(statusPreferences.showCodexQuota ? "7d 100%" : "7d")
        } else if statusPreferences.showCodexQuota {
            codexWidth = textWidth("5h 100% · 7d 100%")
        }
        if codexWidth > 0 { groups.append(codexWidth) }
        if statusPreferences.showDeepSeekBalance {
            groups.append(textWidth("¥9999.99"))
        }

        let groupsWidth = groups.reduce(0, +) + (groups.count > 1 ? textWidth(" ｜ ") : 0)
        return max(NSStatusItem.squareLength, groupsWidth + 16)
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
