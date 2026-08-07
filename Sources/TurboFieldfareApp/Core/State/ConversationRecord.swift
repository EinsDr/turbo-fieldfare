import Foundation

/// A saved conversation. Stored as JSON rather than Markdown because JSON
/// round-trips exactly; parsing Markdown back into turns starts guessing the
/// moment a response contains a heading that resembles the delimiter.
public struct ConversationRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var turns: [ConversationTurn]

    public init(
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        turns: [ConversationTurn]
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.turns = turns
    }

    /// First prompt, condensed to something that fits a sidebar row.
    public static func title(from turns: [ConversationTurn]) -> String {
        guard let first = turns.first?.prompt else { return "New Conversation" }
        let flattened = first
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !flattened.isEmpty else { return "New Conversation" }
        return flattened.count <= 60
            ? flattened
            : String(flattened.prefix(60)) + "\u{2026}"
    }

    /// Human-readable export, for reading elsewhere or pasting into another model.
    public var markdown: String {
        var lines = ["# \(title)", ""]
        for turn in turns {
            lines.append("## You")
            lines.append("")
            lines.append(turn.prompt)
            lines.append("")
            lines.append("## Answer")
            lines.append("")
            lines.append(turn.response)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
