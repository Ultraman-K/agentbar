import Foundation

public struct DeepSeekBalanceItem: Codable, Equatable, Sendable {
    public let currency: String
    public let total: Decimal
    public let granted: Decimal
    public let toppedUp: Decimal

    public init(currency: String, total: Decimal, granted: Decimal = 0, toppedUp: Decimal = 0) {
        self.currency = currency
        self.total = total
        self.granted = granted
        self.toppedUp = toppedUp
    }
}

public struct DeepSeekBalanceSnapshot: Codable, Equatable, Sendable {
    public let isAvailable: Bool
    public let balances: [DeepSeekBalanceItem]
    public let updatedAt: Date

    public init(isAvailable: Bool, balances: [DeepSeekBalanceItem], updatedAt: Date) {
        self.isAvailable = isAvailable
        self.balances = balances
        self.updatedAt = updatedAt
    }

    public var cnyBalance: DeepSeekBalanceItem? {
        balances.first { $0.currency == "CNY" }
    }
}

public enum DeepSeekBalanceError: Error, Equatable, Sendable {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case server(Int)
    case transport
    case decoding
}

public enum DeepSeekDisplayState: Equatable, Sendable {
    case live
    case refreshing
    case lastKnown
    case unavailable
}

public struct DeepSeekBalanceResult: Equatable, Sendable {
    public let snapshot: DeepSeekBalanceSnapshot?
    public let state: DeepSeekDisplayState
    public let error: DeepSeekBalanceError?

    public init(snapshot: DeepSeekBalanceSnapshot?, state: DeepSeekDisplayState, error: DeepSeekBalanceError? = nil) {
        self.snapshot = snapshot
        self.state = state
        self.error = error
    }
}
