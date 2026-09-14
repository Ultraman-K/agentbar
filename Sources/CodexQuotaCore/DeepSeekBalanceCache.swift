import Foundation

public protocol DeepSeekBalanceCache: Sendable {
    func load() throws -> DeepSeekBalanceSnapshot?
    func save(_ snapshot: DeepSeekBalanceSnapshot) throws
}

public struct FileDeepSeekBalanceCache: DeepSeekBalanceCache, Sendable {
    public let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> DeepSeekBalanceSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(DeepSeekBalanceSnapshot.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ snapshot: DeepSeekBalanceSnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
    }
}
