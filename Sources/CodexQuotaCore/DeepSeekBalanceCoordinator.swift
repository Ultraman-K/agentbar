import Foundation

public actor DeepSeekBalanceCoordinator {
    private let provider: DeepSeekBalanceProvider
    private let cache: any DeepSeekBalanceCache
    private var apiKey: String?
    private var latest: DeepSeekBalanceSnapshot?
    private var inFlight = false

    public init(provider: DeepSeekBalanceProvider = .init(), cache: any DeepSeekBalanceCache, apiKey: String? = nil) {
        self.provider = provider
        self.cache = cache
        self.apiKey = apiKey
    }

    public func setAPIKey(_ apiKey: String?) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func loadCachedSnapshot() -> DeepSeekBalanceResult {
        guard let apiKey, !apiKey.isEmpty else { return .init(snapshot: nil, state: .unavailable, error: .missingAPIKey) }
        do {
            guard let cached = try cache.load() else { return .init(snapshot: nil, state: .unavailable) }
            latest = cached
            return .init(snapshot: cached, state: .lastKnown)
        } catch {
            return .init(snapshot: nil, state: .unavailable, error: .decoding)
        }
    }

    public func refresh() async -> DeepSeekBalanceResult {
        guard !inFlight else { return .init(snapshot: latest, state: latest == nil ? .unavailable : .lastKnown) }
        guard let apiKey, !apiKey.isEmpty else {
            latest = nil
            return .init(snapshot: nil, state: .unavailable, error: .missingAPIKey)
        }

        inFlight = true
        defer { inFlight = false }
        do {
            let snapshot = try await provider.fetch(apiKey: apiKey)
            try? cache.save(snapshot)
            latest = snapshot
            return .init(snapshot: snapshot, state: .live)
        } catch let error as DeepSeekBalanceError {
            return .init(snapshot: latest, state: latest == nil ? .unavailable : .lastKnown, error: error)
        } catch {
            return .init(snapshot: latest, state: latest == nil ? .unavailable : .lastKnown, error: .transport)
        }
    }

    public func current() -> DeepSeekBalanceResult {
        .init(snapshot: latest, state: latest == nil ? .unavailable : .lastKnown)
    }
}
