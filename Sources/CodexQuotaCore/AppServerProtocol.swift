import Foundation

public struct AppServerWireWindow: Codable, Equatable, Sendable {
    public let usedPercent: Int
    public let windowDurationMins: Int?
    public let resetsAt: Int?

    public init(usedPercent: Int, windowDurationMins: Int?, resetsAt: Int?) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }
}

public struct AppServerWireSnapshot: Codable, Equatable, Sendable {
    public let limitId: String?
    public let primary: AppServerWireWindow?
    public let secondary: AppServerWireWindow?

    public init(limitId: String? = nil, primary: AppServerWireWindow?, secondary: AppServerWireWindow?) {
        self.limitId = limitId
        self.primary = primary
        self.secondary = secondary
    }

    public func mergingSparse(_ update: Self) -> Self {
        .init(
            limitId: update.limitId ?? limitId,
            primary: update.primary ?? primary,
            secondary: update.secondary ?? secondary
        )
    }

    public func toRaw(capturedAt: Date, resetCredits: RateLimitResetCredits? = nil) -> RawQuotaSnapshot {
        let windows = [primary, secondary].compactMap { window -> RawQuotaWindow? in
            guard let window, let duration = window.windowDurationMins else { return nil }
            return .init(
                windowMinutes: duration,
                usedPercent: window.usedPercent,
                resetsAt: window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            )
        }
        return .init(windows: windows, capturedAt: capturedAt, resetCredits: resetCredits)
    }
}

private struct AppServerWireResetCredit: Decodable, Sendable {
    let id: String
    let status: String?
    let expiresAt: Int?
    let title: String?
}

private struct AppServerWireResetCredits: Decodable, Sendable {
    let availableCount: Int
    let credits: [AppServerWireResetCredit]?

    func domain() -> RateLimitResetCredits {
        .init(
            availableCount: availableCount,
            credits: credits?.map {
                .init(
                    id: $0.id,
                    status: $0.status ?? "unknown",
                    expiresAt: $0.expiresAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                    title: $0.title
                )
            }
        )
    }
}

public struct AppServerDecodedMessage: Sendable {
    public let id: Int?
    public let method: String?
    public let snapshot: AppServerWireSnapshot?
    public let resetCredits: RateLimitResetCredits?
    public let errorCode: Int?
    public let errorMessage: String?
}

public enum AppServerMessageDecoder {
    public static func decode(_ data: Data) throws -> AppServerDecodedMessage {
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            return .init(
                id: envelope.id,
                method: envelope.method,
                snapshot: envelope.result?.selectedRateLimits ?? envelope.params?.selectedRateLimits,
                resetCredits: envelope.result?.rateLimitResetCredits?.domain() ?? envelope.params?.rateLimitResetCredits?.domain(),
                errorCode: envelope.error?.code,
                errorMessage: envelope.error?.message
            )
        } catch {
            throw RateLimitProviderError.protocolViolation("Invalid app-server message: \(error.localizedDescription)")
        }
    }
}

private struct Envelope: Decodable {
    let id: Int?
    let method: String?
    let result: Payload?
    let params: Payload?
    let error: ErrorPayload?
}

private struct Payload: Decodable {
    let rateLimits: AppServerWireSnapshot?
    let rateLimitsByLimitId: [String: AppServerWireSnapshot]?
    let rateLimitResetCredits: AppServerWireResetCredits?

    var selectedRateLimits: AppServerWireSnapshot? {
        if let codex = rateLimitsByLimitId?["codex"] { return codex }
        guard let rateLimits, rateLimits.limitId == nil || rateLimits.limitId == "codex" else { return nil }
        return rateLimits
    }
}

private struct ErrorPayload: Decodable {
    let code: Int?
    let message: String?
}
