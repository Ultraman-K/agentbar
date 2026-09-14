import Foundation

public enum StatusBarMode: String, Codable, CaseIterable, Sendable {
    case recommended
    case codex
    case deepSeek
    case mixed
}

public struct StatusBarModeSettings: Codable, Equatable, Sendable {
    public var showRing: Bool
    public var showQuota: Bool
    public var showPotion: Bool
    public var showBalance: Bool

    public init(showRing: Bool, showQuota: Bool, showPotion: Bool, showBalance: Bool) {
        self.showRing = showRing
        self.showQuota = showQuota
        self.showPotion = showPotion
        self.showBalance = showBalance
    }

    public static let recommended = Self(showRing: true, showQuota: true, showPotion: false, showBalance: false)
    public static let codex = Self(showRing: true, showQuota: true, showPotion: true, showBalance: false)
    public static let deepSeek = Self(showRing: false, showQuota: false, showPotion: false, showBalance: true)
    public static let mixed = Self(showRing: true, showQuota: true, showPotion: false, showBalance: true)
}

public struct StatusBarPreferences: Codable, Equatable, Sendable {
    public var showCodexRing: Bool
    public var showCodexQuota: Bool
    public var showDeepSeekBalance: Bool

    private static let key = "CodexQuotaMenu.statusBarPreferences.v1"
    private static let migrationKey = "CodexQuotaMenu.statusBarPreferences.migrated"

    private enum CodingKeys: String, CodingKey {
        case showCodexRing
        case showCodexQuota
        case showDeepSeekBalance
        case mode
        case modes
    }

    public init(showCodexRing: Bool, showCodexQuota: Bool, showDeepSeekBalance: Bool) {
        self.showCodexRing = showCodexRing
        self.showCodexQuota = showCodexQuota
        self.showDeepSeekBalance = showDeepSeekBalance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let ring = try container.decodeIfPresent(Bool.self, forKey: .showCodexRing) {
            showCodexRing = ring
            showCodexQuota = try container.decodeIfPresent(Bool.self, forKey: .showCodexQuota) ?? true
            showDeepSeekBalance = try container.decodeIfPresent(Bool.self, forKey: .showDeepSeekBalance) ?? false
            return
        }

        let mode = try container.decodeIfPresent(StatusBarMode.self, forKey: .mode) ?? .recommended
        let modes = try container.decodeIfPresent([StatusBarMode: StatusBarModeSettings].self, forKey: .modes) ?? [:]
        let legacy = modes[mode] ?? .recommended
        showCodexRing = legacy.showRing
        showCodexQuota = legacy.showQuota
        showDeepSeekBalance = legacy.showBalance
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showCodexRing, forKey: .showCodexRing)
        try container.encode(showCodexQuota, forKey: .showCodexQuota)
        try container.encode(showDeepSeekBalance, forKey: .showDeepSeekBalance)
    }

    public static func load(from defaults: UserDefaults = .standard) -> Self {
        if let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(Self.self, from: data) {
            return value
        }
        let legacyCompact = defaults.object(forKey: "CodexQuotaMenu.compactStatusBar") as? Bool
        let value = Self(
            showCodexRing: true,
            showCodexQuota: legacyCompact != true,
            showDeepSeekBalance: false
        )
        save(value, to: defaults)
        defaults.set(true, forKey: migrationKey)
        return value
    }

    public static func save(_ value: Self, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
