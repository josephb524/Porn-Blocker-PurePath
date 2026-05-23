import Foundation

/// A single buddy-chat thread — an ordered list of `ChatMessage`s plus a
/// title derived from the first user prompt.
struct ChatConversation: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         title: String = "New chat",
         messages: [ChatMessage] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// A short title derived from the first user message — `nil` until one exists.
    var derivedTitle: String? {
        guard let first = messages.first(where: { $0.role == .user })?.content else { return nil }
        let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        // Trim to a single line, ~40 chars.
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        return firstLine.count > 40 ? String(firstLine.prefix(40)) + "…" : firstLine
    }
}
