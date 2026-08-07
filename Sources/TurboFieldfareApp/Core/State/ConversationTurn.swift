import Foundation

/// One completed exchange, retained so later prompts can see earlier ones.
///
/// Turns are carried to the inference client inside the existing prompt field,
/// separated by an ASCII record separator, which keeps the app-to-helper wire
/// format unchanged. A payload with no separator is a single user message,
/// exactly as before.
public struct ConversationTurn: Codable, Sendable, Equatable {
    public let prompt: String
    public let response: String

    public init(prompt: String, response: String) {
        self.prompt = prompt
        self.response = response
    }

    /// ASCII RS. Chosen because it cannot occur in ordinary typed text.
    public static let separator = "\u{001E}"

    /// Roughly the number of characters of history worth sending. Trimming by
    /// characters is an approximation of the token limit, deliberately
    /// conservative so a long conversation degrades by forgetting its oldest
    /// turns rather than failing outright with a context overflow.
    public static let characterBudget = 24_000
}
