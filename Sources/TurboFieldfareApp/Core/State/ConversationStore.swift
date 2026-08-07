import Foundation

/// Reads and writes conversations as one JSON file each, under
/// Application Support. Every operation fails quietly: losing a saved
/// conversation should never interrupt a generation in progress.
public struct ConversationStore: Sendable {
    public static let shared = ConversationStore()

    public init() {}

    public var directory: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask).first else { return nil }
        return base
            .appendingPathComponent("TurboFieldfare", isDirectory: true)
            .appendingPathComponent("Conversations", isDirectory: true)
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Newest first.
    public func load() -> [ConversationRecord] {
        guard let directory,
              let names = try? FileManager.default.contentsOfDirectory(
                atPath: directory.path) else { return [] }
        var records: [ConversationRecord] = []
        for name in names where name.hasSuffix(".json") {
            let url = directory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                  let record = try? decoder().decode(
                    ConversationRecord.self, from: data) else { continue }
            records.append(record)
        }
        return records.sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    public func save(_ record: ConversationRecord) -> Bool {
        guard let directory else { return false }
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        guard let data = try? encoder().encode(record) else { return false }
        let url = directory.appendingPathComponent("\(record.id.uuidString).json")
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    @discardableResult
    public func delete(id: UUID) -> Bool {
        guard let directory else { return false }
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        return (try? FileManager.default.removeItem(at: url)) != nil
    }
}
