import Foundation

public enum QuotaKind: String, Codable, Sendable { case fiveHour, weekly }
public enum QuotaSource: String, Codable, Sendable { case appServer, sessionLog, cache }
public enum QuotaFreshness: String, Codable, Sendable { case fresh, stale, unavailable }
public enum QuotaAlert: String, Codable, Sendable { case normal, warning, danger, unknown }
public enum QuotaDisplayState: Equatable, Sendable { case live, refreshing, lastKnown, expired, unavailable }
public enum QuotaFailureReason: Equatable, Sendable { case timeout, codexNotFound, notAuthenticated, processExited, protocolError, networkUnavailable, cacheUnreadable, unknown }

public struct RateLimitResetCredit: Codable, Equatable, Sendable {
    public let id: String
    public let status: String
    public let expiresAt: Date?
    public let title: String?

    public init(id: String, status: String = "unknown", expiresAt: Date?, title: String? = nil) {
        self.id = id
        self.status = status
        self.expiresAt = expiresAt
        self.title = title
    }
}

public struct RateLimitResetCredits: Codable, Equatable, Sendable {
    public let availableCount: Int
    public let credits: [RateLimitResetCredit]?

    public init(availableCount: Int, credits: [RateLimitResetCredit]? = nil) {
        self.availableCount = max(0, availableCount)
        self.credits = credits
    }
}

public struct QuotaRefreshResult: Equatable, Sendable {
    public let snapshot: QuotaSnapshot?
    public let state: QuotaDisplayState
    public let failureReason: QuotaFailureReason?
    public let nextRetryAt: Date?

    public init(snapshot: QuotaSnapshot?, state: QuotaDisplayState, failureReason: QuotaFailureReason? = nil, nextRetryAt: Date? = nil) {
        self.snapshot = snapshot
        self.state = state
        self.failureReason = failureReason
        self.nextRetryAt = nextRetryAt
    }
}

public struct RawQuotaWindow: Equatable, Sendable {
    public let windowMinutes: Int
    public let usedPercent: Int
    public let resetsAt: Date?
    public init(windowMinutes: Int, usedPercent: Int, resetsAt: Date?) {
        self.windowMinutes = windowMinutes
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }
}

public struct RawQuotaSnapshot: Equatable, Sendable {
    public let windows: [RawQuotaWindow]
    public let capturedAt: Date
    public let resetCredits: RateLimitResetCredits?
    public init(windows: [RawQuotaWindow], capturedAt: Date, resetCredits: RateLimitResetCredits? = nil) {
        self.windows = windows
        self.capturedAt = capturedAt
        self.resetCredits = resetCredits
    }
}

public struct QuotaWindow: Codable, Equatable, Sendable {
    public let kind: QuotaKind
    public let windowMinutes: Int
    public let usedPercent: Int
    public let remainingPercent: Int
    public let resetsAt: Date?
    public let alert: QuotaAlert
}

public struct QuotaSnapshot: Codable, Equatable, Sendable {
    public let fiveHour: QuotaWindow?
    public let weekly: QuotaWindow?
    public let source: QuotaSource
    public let freshness: QuotaFreshness
    public let updatedAt: Date
    public let resetCredits: RateLimitResetCredits?

    public init(
        fiveHour: QuotaWindow?,
        weekly: QuotaWindow?,
        source: QuotaSource,
        freshness: QuotaFreshness,
        updatedAt: Date,
        resetCredits: RateLimitResetCredits? = nil
    ) {
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.source = source
        self.freshness = freshness
        self.updatedAt = updatedAt
        self.resetCredits = resetCredits
    }
}
