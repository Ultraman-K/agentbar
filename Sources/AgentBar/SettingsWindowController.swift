import AppKit
import CodexQuotaCore

struct SettingsDraft {
    var statusPreferences: StatusBarPreferences
    var proxy: ProxyConfiguration
    var apiKey: String?
    var removeAPIKey: Bool
    var launchAtLogin: Bool
}

enum DeepSeekTestOutcome: Sendable {
    case success(String)
    case failure(String)
}

@MainActor
final class SettingsWindowController: NSWindowController {
    enum Section: CaseIterable { case general, providers, network }

    /// One row of a vertical stack plus the exact gap that follows it, mirroring the
    /// prototype's per-element margins instead of one uniform stack spacing.
    private struct Row {
        let view: NSView
        let spacingAfter: CGFloat
    }

    private let onSave: (SettingsDraft) -> Void
    private let onTestDeepSeek: (String, @escaping (DeepSeekTestOutcome) -> Void) -> Void
    private var preferences: StatusBarPreferences
    private var proxyConfiguration: ProxyConfiguration
    private var hasStoredAPIKey: Bool
    private var launchAtLoginEnabled: Bool
    private var selectedSection: Section = .general
    private var selectedProxyMode: ProxyMode = .direct
    private var apiKeyBox: SettingsBox?

    private let contentView = SettingsSurfaceView(token: .window)
    private let generalView = NSView()
    private let providersView = NSView()
    private let networkView = NSView()
    private var navItems: [Section: SettingsNavItem] = [:]
    private var proxyCards: [ProxyMode: SettingsCardControl] = [:]
    private var panelStacks: [Section: NSStackView] = [:]

    private let ringCheck = SettingsCheckControl(title: "圆环", target: nil, action: nil)
    private let quotaCheck = SettingsCheckControl(title: "额度数字", target: nil, action: nil)
    private let balanceCheck = SettingsCheckControl(title: "余额", target: nil, action: nil)
    private var chipBoxes: [ObjectIdentifier: SettingsBox] = [:]
    private let launchSwitch = SettingsSwitchControl(target: nil, action: nil)

    private let apiKeyField = SettingsSecureTextField()
    private let keyStatusRow = SettingsStatusRow()
    private let proxyHostField = SettingsTextField()
    private let proxyPortField = SettingsTextField()
    private let proxyStatusRow = SettingsStatusRow()

    // Targets are attached after `super.init` because `self` is not available yet.
    private let generalSaveButton = SettingsButton(
        title: "保存", role: .primary, target: nil, action: #selector(saveSettings)
    )
    private let providersSaveButton = SettingsButton(
        title: "保存", role: .primary, target: nil, action: #selector(saveSettings)
    )
    private let networkSaveButton = SettingsButton(
        title: "保存", role: .primary, target: nil, action: #selector(saveSettings)
    )
    private let removeKeyButton = SettingsButton(
        title: "移除 API Key", role: .danger, target: nil, action: #selector(removeAPIKey)
    )
    private let showKeyButton = SettingsButton(
        title: "显示", role: .plain, target: nil, action: #selector(toggleAPIKeyVisibility)
    )
    private let testKeyButton = SettingsButton(
        title: "测试连接", role: .plain, target: nil, action: #selector(testDeepSeek)
    )

    init(
        preferences: StatusBarPreferences,
        proxy: ProxyConfiguration,
        hasAPIKey: Bool,
        launchAtLogin: Bool = false,
        onSave: @escaping (SettingsDraft) -> Void,
        onTestDeepSeek: @escaping (String, @escaping (DeepSeekTestOutcome) -> Void) -> Void
    ) {
        self.preferences = preferences
        self.proxyConfiguration = proxy
        self.hasStoredAPIKey = hasAPIKey
        self.launchAtLoginEnabled = launchAtLogin
        self.onSave = onSave
        self.onTestDeepSeek = onTestDeepSeek
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: SettingsMetrics.windowWidth,
                height: SettingsMetrics.minimumContentHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.isReleasedWhenClosed = false
        window.backgroundColor = SettingsTheme.dynamic(.window)
        super.init(window: window)

        [
            generalSaveButton,
            providersSaveButton,
            networkSaveButton,
            removeKeyButton,
            showKeyButton,
            testKeyButton
        ].forEach { $0.target = self }

        window.contentView = makeContent()
        renderSection()
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func show(section: Section = .general) {
        selectedSection = section
        renderSection()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if section == .providers {
            window?.makeFirstResponder(apiKeyField)
        }
    }

    // MARK: - Window chrome

    private func makeContent() -> NSView {
        let sidebar = SettingsSurfaceView(token: .sidebar)
        let hairline = SettingsHairlineView()
        let panelHost = NSView()
        contentView.addSubview(sidebar)
        contentView.addSubview(hairline)
        contentView.addSubview(panelHost)
        [sidebar, hairline, panelHost].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let sidebarLabel = NSTextField(labelWithString: "设置")
        sidebarLabel.font = .systemFont(ofSize: 11)
        sidebarLabel.textColor = SettingsTheme.dynamic(.muted)
        let navStack = NSStackView(views: [
            makeNavItem("通用", symbol: "slider.horizontal.3", section: .general),
            makeNavItem("供应商配置", symbol: "square.grid.2x2", section: .providers),
            makeNavItem("网络", symbol: "network", section: .network)
        ])
        navStack.orientation = .vertical
        navStack.alignment = .leading
        navStack.spacing = SettingsMetrics.navItemSpacing
        let sidebarStack = NSStackView(views: [sidebarLabel, navStack])
        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 0
        sidebarStack.setCustomSpacing(SettingsMetrics.navLabelSpacing, after: sidebarLabel)
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sidebarStack)

        let insets = SettingsMetrics.sidebarPadding
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: SettingsMetrics.sidebarWidth),

            hairline.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            hairline.topAnchor.constraint(equalTo: contentView.topAnchor),
            hairline.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            hairline.widthAnchor.constraint(equalToConstant: 1),

            panelHost.leadingAnchor.constraint(equalTo: hairline.trailingAnchor),
            panelHost.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            panelHost.topAnchor.constraint(equalTo: contentView.topAnchor),
            panelHost.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            sidebarStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: insets.left),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -insets.right),
            sidebarStack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: insets.top)
        ])

        buildGeneralView()
        buildProvidersView()
        buildNetworkView()
        panelHost.addSubview(generalView)
        panelHost.addSubview(providersView)
        panelHost.addSubview(networkView)
        [generalView, providersView, networkView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        let content = SettingsMetrics.contentInsets
        NSLayoutConstraint.activate([
            generalView.leadingAnchor.constraint(equalTo: panelHost.leadingAnchor, constant: content.left),
            generalView.trailingAnchor.constraint(equalTo: panelHost.trailingAnchor, constant: -content.right),
            generalView.topAnchor.constraint(equalTo: panelHost.topAnchor, constant: content.top),
            generalView.bottomAnchor.constraint(equalTo: panelHost.bottomAnchor, constant: -content.bottom),
            providersView.leadingAnchor.constraint(equalTo: generalView.leadingAnchor),
            providersView.trailingAnchor.constraint(equalTo: generalView.trailingAnchor),
            providersView.topAnchor.constraint(equalTo: generalView.topAnchor),
            providersView.bottomAnchor.constraint(equalTo: generalView.bottomAnchor),
            networkView.leadingAnchor.constraint(equalTo: generalView.leadingAnchor),
            networkView.trailingAnchor.constraint(equalTo: generalView.trailingAnchor),
            networkView.topAnchor.constraint(equalTo: generalView.topAnchor),
            networkView.bottomAnchor.constraint(equalTo: generalView.bottomAnchor)
        ])
        return contentView
    }

    private func makeNavItem(_ title: String, symbol: String, section: Section) -> SettingsNavItem {
        let item = SettingsNavItem(
            title: title,
            systemSymbol: symbol,
            target: self,
            action: #selector(selectSection(_:))
        )
        item.tag = Section.allCases.firstIndex(of: section) ?? 0
        item.translatesAutoresizingMaskIntoConstraints = false
        item.widthAnchor.constraint(
            equalToConstant: SettingsMetrics.sidebarWidth - SettingsMetrics.sidebarPadding.left - SettingsMetrics.sidebarPadding.right
        ).isActive = true
        navItems[section] = item
        return item
    }

    @objc private func selectSection(_ sender: NSControl) {
        selectedSection = Section.allCases[sender.tag]
        renderSection()
    }

    private func renderSection() {
        generalView.isHidden = selectedSection != .general
        providersView.isHidden = selectedSection != .providers
        networkView.isHidden = selectedSection != .network
        navItems.forEach { section, item in
            item.isChosen = section == selectedSection
        }
        resizeWindowToFitContent()
    }

    private func resizeWindowToFitContent() {
        guard let window, let stack = panelStacks[selectedSection] else { return }
        window.contentView?.layoutSubtreeIfNeeded()
        let insets = SettingsMetrics.contentInsets
        let height = max(
            SettingsMetrics.minimumContentHeight,
            stack.fittingSize.height + insets.top + insets.bottom
        )
        let currentHeight = window.contentRect(forFrameRect: window.frame).height
        guard abs(height - currentHeight) > 0.5 else { return }
        var frame = window.frame
        frame.origin.y -= height - currentHeight
        frame.size = window.frameRect(
            forContentRect: NSRect(x: 0, y: 0, width: SettingsMetrics.windowWidth, height: height)
        ).size
        window.setFrame(frame, display: true, animate: false)
    }

    // MARK: - General panel

    private func buildGeneralView() {
        [ringCheck, quotaCheck, balanceCheck].forEach {
            $0.target = self
            $0.action = #selector(elementChanged)
        }

        let codexBlock = stack([
            Row(
                view: VendorHeadingRow(title: "Codex", brand: "codex-mark", fallbackSymbol: "terminal"),
                spacingAfter: SettingsMetrics.vendorBlockSpacing
            ),
            Row(view: chipRow([ringCheck, quotaCheck]), spacingAfter: 0)
        ])
        let deepSeekBlock = stack([
            Row(
                view: VendorHeadingRow(title: "DeepSeek", brand: "deepseek-mark", fallbackSymbol: "sparkles"),
                spacingAfter: SettingsMetrics.vendorBlockSpacing
            ),
            Row(view: chipRow([balanceCheck]), spacingAfter: 0)
        ])
        let vendorConfig = stack([
            Row(view: codexBlock, spacingAfter: SettingsMetrics.vendorGroupSpacing),
            Row(view: deepSeekBlock, spacingAfter: 0)
        ])
        let contentGroup = stack([
            Row(view: label("菜单栏内容"), spacingAfter: SettingsMetrics.labelSpacing),
            Row(
                view: help("状态栏不显示供应商图标；重置次数只在展开菜单展示。"),
                spacingAfter: SettingsMetrics.vendorGroupSpacing
            ),
            Row(view: vendorConfig, spacingAfter: 0)
        ])

        launchSwitch.target = self
        launchSwitch.action = #selector(launchAtLoginChanged)
        launchSwitch.isOn = launchAtLoginEnabled
        let launchCopy = stack([
            Row(view: label("登录时自动启动"), spacingAfter: SettingsMetrics.helpSpacing),
            Row(view: help("登录 macOS 后在后台启动。"), spacingAfter: 0)
        ])
        let launchRow = NSStackView(views: [launchCopy, NSView(), launchSwitch])
        launchRow.orientation = .horizontal
        launchRow.alignment = .centerY
        launchRow.distribution = .fill
        launchRow.translatesAutoresizingMaskIntoConstraints = false
        launchRow.heightAnchor.constraint(
            greaterThanOrEqualToConstant: SettingsMetrics.toggleMinHeight
        ).isActive = true

        let footer = footerRow([generalSaveButton])
        let panel = stack([
            Row(view: titleLabel("通用"), spacingAfter: SettingsMetrics.titleSpacing),
            Row(
                view: subtitleLabel("控制菜单栏展示和应用启动行为。"),
                spacingAfter: SettingsMetrics.subtitleSpacing
            ),
            Row(view: contentGroup, spacingAfter: SettingsMetrics.groupSpacing),
            Row(view: launchRow, spacingAfter: SettingsMetrics.footerSpacing),
            Row(view: footer, spacingAfter: 0)
        ])
        pin(panel, to: generalView)
        panelStacks[.general] = panel
        fullWidth([contentGroup, launchRow, footer], in: generalView)
        syncElements()
    }

    private func chipRow(_ checks: [SettingsCheckControl]) -> NSStackView {
        let row = NSStackView(views: checks.map { chip($0) })
        row.orientation = .horizontal
        row.spacing = SettingsMetrics.chipSpacing
        return row
    }

    @objc private func elementChanged() {
        preferences.showCodexRing = ringCheck.isOn
        preferences.showCodexQuota = quotaCheck.isOn
        preferences.showDeepSeekBalance = balanceCheck.isOn
        refreshChips()
    }

    @objc private func launchAtLoginChanged() {
        launchAtLoginEnabled = launchSwitch.isOn
    }

    private func syncElements() {
        ringCheck.isOn = preferences.showCodexRing
        quotaCheck.isOn = preferences.showCodexQuota
        balanceCheck.isOn = preferences.showDeepSeekBalance
        refreshChips()
    }

    private func refreshChips() {
        [ringCheck, quotaCheck, balanceCheck].forEach { check in
            guard let box = chipBoxes[ObjectIdentifier(check)] else { return }
            box.isChosen = check.isOn
        }
    }

    // MARK: - Providers panel

    private func buildProvidersView() {
        configureField(apiKeyField)
        setPlaceholder(
            hasStoredAPIKey ? "已安全保存 · 输入新 Key 可替换" : "输入 DeepSeek API Key",
            on: apiKeyField
        )
        let fieldBox = SettingsBox(style: .field, content: apiKeyField)
        apiKeyBox = fieldBox
        apiKeyField.onFocusChange = { [weak self] focused in
            self?.apiKeyBox?.isFocused = focused
        }
        fieldBox.setContentHuggingPriority(.defaultLow, for: .horizontal)
        fieldBox.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let fieldRow = NSStackView(views: [fieldBox, showKeyButton, testKeyButton])
        fieldRow.orientation = .horizontal
        fieldRow.alignment = .centerY
        fieldRow.spacing = SettingsMetrics.fieldSpacing
        fieldRow.distribution = .fill

        let headerGroup = stack([
            Row(view: label("DeepSeek API"), spacingAfter: SettingsMetrics.labelSpacing),
            Row(view: help("使用官方接口读取余额。API Key 只保存在本机钥匙串。"), spacingAfter: 0)
        ])
        let keyGroup = stack([
            Row(view: label("API Key"), spacingAfter: SettingsMetrics.labelSpacing),
            Row(view: fieldRow, spacingAfter: SettingsMetrics.helpSpacing),
            Row(view: help("不会写入 UserDefaults、缓存或日志。"), spacingAfter: 0)
        ])
        let footer = footerRow([removeKeyButton, providersSaveButton])
        let panel = stack([
            Row(view: titleLabel("供应商配置"), spacingAfter: SettingsMetrics.titleSpacing),
            Row(
                view: subtitleLabel("MVP 只管理 Codex 与 DeepSeek 两个数据源。"),
                spacingAfter: SettingsMetrics.subtitleSpacing
            ),
            Row(view: headerGroup, spacingAfter: SettingsMetrics.groupSpacing),
            Row(
                view: help("配置 API Key 后自动查询余额，每 1 分钟刷新，也可从菜单手动刷新。"),
                spacingAfter: SettingsMetrics.groupSpacing
            ),
            Row(view: keyGroup, spacingAfter: SettingsMetrics.groupSpacing),
            Row(view: keyStatusRow, spacingAfter: SettingsMetrics.footerSpacing),
            Row(view: footer, spacingAfter: 0)
        ])
        pin(panel, to: providersView)
        panelStacks[.providers] = panel
        fullWidth([fieldRow, keyStatusRow, footer], in: providersView)
        renderKeyStatus(
            symbol: hasStoredAPIKey ? "checkmark.circle" : "key",
            text: hasStoredAPIKey ? "已保存 API Key" : "未配置 API Key",
            level: .normal
        )
    }

    // MARK: - Network panel

    private func buildNetworkView() {
        selectedProxyMode = proxyConfiguration.mode
        let isCustom = selectedProxyMode == .custom
        configureField(proxyHostField)
        configureField(proxyPortField)
        proxyHostField.stringValue = proxyConfiguration.host
        proxyPortField.stringValue = String(proxyConfiguration.port)
        setPlaceholder("127.0.0.1", on: proxyHostField)
        setPlaceholder("7897", on: proxyPortField)
        proxyHostField.isEnabled = isCustom
        proxyPortField.isEnabled = isCustom
        proxyHostField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        proxyHostField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let cardRow = NSStackView(views: [
            makeProxyCard("直接连接", mode: .direct),
            makeProxyCard("自定义 Clash 代理", mode: .custom)
        ])
        cardRow.orientation = .horizontal
        cardRow.spacing = SettingsMetrics.cardSpacing
        cardRow.distribution = .fillEqually

        let hostGroup = fieldGroup(caption: "主机", field: proxyHostField)
        let portGroup = fieldGroup(caption: "混合端口", field: proxyPortField)
        portGroup.translatesAutoresizingMaskIntoConstraints = false
        portGroup.widthAnchor.constraint(equalToConstant: SettingsMetrics.portFieldWidth).isActive = true
        let fields = NSStackView(views: [hostGroup, portGroup])
        fields.orientation = .horizontal
        fields.alignment = .top
        fields.spacing = SettingsMetrics.fieldSpacing
        // Without an explicit distribution the stack keeps gravity areas and never
        // stretches the host field, which collapses it to its caption width.
        fields.distribution = .fill
        hostGroup.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostGroup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hostGroup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        let modeGroup = stack([
            Row(view: label("连接方式"), spacingAfter: SettingsMetrics.labelSpacing),
            Row(view: cardRow, spacingAfter: 0)
        ])
        let addressGroup = stack([
            Row(view: label("代理地址"), spacingAfter: SettingsMetrics.labelSpacing),
            Row(view: fields, spacingAfter: 0)
        ])
        let footer = footerRow([networkSaveButton])
        let panel = stack([
            Row(view: titleLabel("网络"), spacingAfter: SettingsMetrics.titleSpacing),
            Row(
                view: subtitleLabel("代理只影响本应用读取 Codex 与 DeepSeek 数据。"),
                spacingAfter: SettingsMetrics.subtitleSpacing
            ),
            Row(view: modeGroup, spacingAfter: SettingsMetrics.groupSpacing),
            Row(view: addressGroup, spacingAfter: SettingsMetrics.groupSpacing),
            Row(view: proxyStatusRow, spacingAfter: SettingsMetrics.footerSpacing),
            Row(view: footer, spacingAfter: 0)
        ])
        pin(panel, to: networkView)
        panelStacks[.network] = panel
        fullWidth([cardRow, fields, proxyStatusRow, footer], in: networkView)
        renderProxyStatus(symbol: "shield.checkered", text: "配置保存后立即重连所有数据源", level: .normal)
    }

    private func makeProxyCard(_ title: String, mode: ProxyMode) -> SettingsCardControl {
        let card = SettingsCardControl(title: title, target: self, action: #selector(proxyModeChanged(_:)))
        card.tag = mode == .direct ? 0 : 1
        card.isChosen = mode == selectedProxyMode
        proxyCards[mode] = card
        return card
    }

    @objc private func proxyModeChanged(_ sender: NSControl) {
        selectedProxyMode = sender.tag == 0 ? .direct : .custom
        let isCustom = selectedProxyMode == .custom
        proxyHostField.isEnabled = isCustom
        proxyPortField.isEnabled = isCustom
        proxyCards.forEach { mode, card in
            card.isChosen = mode == selectedProxyMode
        }
        renderProxyStatus(symbol: "shield.checkered", text: "配置保存后立即重连所有数据源", level: .normal)
    }

    // MARK: - Field configuration

    private func configureField(_ field: NSTextField) {
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        field.textColor = SettingsTheme.dynamic(.text)
        field.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setPlaceholder(_ text: String, on field: NSTextField) {
        field.placeholderAttributedString = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: SettingsTheme.dynamic(.muted),
                .font: NSFont.systemFont(ofSize: 13)
            ]
        )
    }

    // MARK: - Actions

    @objc private func testDeepSeek() {
        let key = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            renderKeyStatus(symbol: "key", text: "请先输入 DeepSeek API Key", level: .failure)
            return
        }
        renderKeyStatus(symbol: "arrow.triangle.2.circlepath", text: "正在连接 DeepSeek…", level: .normal)
        onTestDeepSeek(key) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .success(let message):
                self.renderKeyStatus(symbol: "checkmark.circle", text: message, level: .success)
            case .failure(let message):
                self.renderKeyStatus(symbol: "xmark.circle", text: message, level: .failure)
            }
        }
    }

    @objc private func toggleAPIKeyVisibility() {
        guard let cell = apiKeyField.cell as? NSSecureTextFieldCell else { return }
        cell.echosBullets.toggle()
        showKeyButton.title = cell.echosBullets ? "显示" : "隐藏"
    }

    @objc private func removeAPIKey() {
        apiKeyField.stringValue = ""
        hasStoredAPIKey = false
        setPlaceholder("输入 DeepSeek API Key", on: apiKeyField)
        renderKeyStatus(symbol: "key", text: "已移除 API Key", level: .normal)
        onSave(SettingsDraft(
            statusPreferences: preferences,
            proxy: proxyConfiguration,
            apiKey: nil,
            removeAPIKey: true,
            launchAtLogin: launchAtLoginEnabled
        ))
    }

    @objc private func saveSettings() {
        var proxy = proxyConfiguration
        var proxyValid = true
        if let parsed = parseProxy() {
            proxy = parsed
            proxyConfiguration = parsed
        } else {
            proxyValid = false
        }
        onSave(SettingsDraft(
            statusPreferences: preferences,
            proxy: proxy,
            apiKey: apiKeyField.stringValue.isEmpty ? nil : apiKeyField.stringValue,
            removeAPIKey: false,
            launchAtLogin: launchAtLoginEnabled
        ))
        if !apiKeyField.stringValue.isEmpty {
            hasStoredAPIKey = true
            apiKeyField.stringValue = ""
            setPlaceholder("已安全保存 · 输入新 Key 可替换", on: apiKeyField)
        }
        switch selectedSection {
        case .general:
            renderKeyStatus(
                symbol: proxyValid ? "checkmark.circle" : "exclamationmark.triangle",
                text: proxyValid ? "设置已保存" : "设置已保存 · 代理地址未生效",
                level: proxyValid ? .success : .failure
            )
        case .providers:
            renderKeyStatus(
                symbol: proxyValid ? "checkmark.circle" : "exclamationmark.triangle",
                text: proxyValid ? "设置已保存" : "设置已保存 · 代理地址未生效",
                level: proxyValid ? .success : .failure
            )
        case .network:
            renderProxyStatus(
                symbol: proxyValid ? "checkmark.circle" : "exclamationmark.triangle",
                text: proxyValid ? "设置已保存 · 已重连数据源" : "代理主机或端口无效",
                level: proxyValid ? .success : .failure
            )
        }
    }

    private func parseProxy() -> ProxyConfiguration? {
        switch ProxyConfigurationResolver.resolve(
            mode: selectedProxyMode,
            host: proxyHostField.stringValue,
            portText: proxyPortField.stringValue
        ) {
        case .resolved(let configuration):
            return configuration
        case .invalid:
            renderProxyStatus(symbol: "exclamationmark.triangle", text: "代理主机或端口无效", level: .failure)
            return nil
        }
    }

    private func renderKeyStatus(symbol: String, text: String, level: SettingsStatusRow.Level) {
        keyStatusRow.render(symbol: symbol, text: text, level: level)
    }

    private func renderProxyStatus(symbol: String, text: String, level: SettingsStatusRow.Level) {
        proxyStatusRow.render(symbol: symbol, text: text, level: level)
    }

    // MARK: - Builders

    private func stack(_ rows: [Row]) -> NSStackView {
        let stack = NSStackView(views: rows.map(\.view))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        for row in rows.dropLast() where row.spacingAfter > 0 {
            stack.setCustomSpacing(row.spacingAfter, after: row.view)
        }
        return stack
    }

    private func fieldGroup(caption: String, field: NSTextField) -> NSStackView {
        let box = SettingsBox(style: .field, content: field)
        if let focusable = field as? SettingsTextField {
            focusable.onFocusChange = { [weak box] focused in
                box?.isFocused = focused
            }
        }
        let group = stack([
            Row(view: help(caption), spacingAfter: SettingsMetrics.helpSpacing),
            Row(view: box, spacingAfter: 0)
        ])
        // The box has no intrinsic width, so it has to follow the group. The row that
        // holds the groups then decides which one absorbs the leftover width.
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
        return group
    }

    private func chip(_ check: SettingsCheckControl) -> NSView {
        let box = SettingsBox(style: .chip, content: check)
        box.isChosen = check.isOn
        chipBoxes[ObjectIdentifier(check)] = box
        return box
    }

    private func footerRow(_ buttons: [SettingsButton]) -> NSStackView {
        let row = NSStackView(views: [NSView()] + buttons)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = SettingsMetrics.footerGap
        row.distribution = .fill
        return row
    }

    private func pin(_ stack: NSStackView, to container: NSView) {
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
    }

    /// Rows that must span the panel width so trailing items line up with the panel edge.
    /// Activate only after the panel hierarchy is installed.
    private func fullWidth(_ views: [NSView], in container: NSView) {
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        }
    }

    private func titleLabel(_ text: String) -> NSTextField {
        let value = NSTextField(labelWithString: text)
        value.font = .systemFont(ofSize: 23, weight: .medium)
        value.textColor = SettingsTheme.dynamic(.text)
        return value
    }

    private func subtitleLabel(_ text: String) -> NSTextField {
        let value = NSTextField(labelWithString: text)
        value.font = .systemFont(ofSize: 13)
        value.textColor = SettingsTheme.dynamic(.muted)
        return value
    }

    private func label(_ text: String) -> NSTextField {
        let value = NSTextField(labelWithString: text)
        value.font = .systemFont(ofSize: 13, weight: .medium)
        value.textColor = SettingsTheme.dynamic(.text)
        return value
    }

    private func help(_ text: String) -> NSTextField {
        let value = NSTextField(labelWithString: text)
        value.font = .systemFont(ofSize: 11)
        value.textColor = SettingsTheme.dynamic(.muted)
        value.lineBreakMode = .byTruncatingTail
        return value
    }
}
