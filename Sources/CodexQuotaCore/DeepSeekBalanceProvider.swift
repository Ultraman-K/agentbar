import Foundation

public protocol DeepSeekHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionDeepSeekHTTPClient: DeepSeekHTTPClient {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw DeepSeekBalanceError.invalidResponse
        }
        return (data, response)
    }
}

public struct DeepSeekBalanceProvider: Sendable {
    public static let endpoint = URL(string: "https://api.deepseek.com/user/balance")!

    private let client: any DeepSeekHTTPClient
    private let now: @Sendable () -> Date

    public init(client: any DeepSeekHTTPClient = URLSessionDeepSeekHTTPClient(), now: @escaping @Sendable () -> Date = Date.init) {
        self.client = client
        self.now = now
    }

    public func fetch(apiKey: String) async throws -> DeepSeekBalanceSnapshot {
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else { throw DeepSeekBalanceError.missingAPIKey }

        var request = URLRequest(url: Self.endpoint, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.setValue("Bearer \(normalizedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await client.data(for: request)
        } catch let error as DeepSeekBalanceError {
            throw error
        } catch {
            throw DeepSeekBalanceError.transport
        }

        switch response.statusCode {
        case 200..<300: break
        case 401, 403: throw DeepSeekBalanceError.unauthorized
        case 429: throw DeepSeekBalanceError.rateLimited
        case 400...599: throw DeepSeekBalanceError.server(response.statusCode)
        default: throw DeepSeekBalanceError.invalidResponse
        }

        do {
            let wire = try JSONDecoder().decode(WireResponse.self, from: data)
            return .init(
                isAvailable: wire.isAvailable,
                balances: try wire.balanceInfos.map(DeepSeekBalanceItem.init),
                updatedAt: now()
            )
        } catch let error as DeepSeekBalanceError {
            throw error
        } catch {
            throw DeepSeekBalanceError.decoding
        }
    }
}

private struct WireResponse: Decodable {
    let isAvailable: Bool
    let balanceInfos: [WireBalanceItem]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

private struct WireBalanceItem: Decodable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }

    func makeDecimal(_ value: String) throws -> Decimal {
        guard let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DeepSeekBalanceError.decoding
        }
        return decimal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currency = try container.decode(String.self, forKey: .currency)
        totalBalance = try container.decode(String.self, forKey: .totalBalance)
        grantedBalance = try container.decodeIfPresent(String.self, forKey: .grantedBalance) ?? "0"
        toppedUpBalance = try container.decodeIfPresent(String.self, forKey: .toppedUpBalance) ?? "0"
    }

    func makeItem() throws -> DeepSeekBalanceItem {
        try .init(currency: currency, total: makeDecimal(totalBalance), granted: makeDecimal(grantedBalance), toppedUp: makeDecimal(toppedUpBalance))
    }
}

private extension DeepSeekBalanceItem {
    init(_ wire: WireBalanceItem) throws {
        self = try wire.makeItem()
    }
}
