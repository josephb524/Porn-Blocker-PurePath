import Foundation

/// One turn in a buddy-chat conversation. The `id` is stable so the UI can
/// identify a streaming message as it fills in, and so per-message state
/// (feedback, read-aloud) survives a re-render.
struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    enum Feedback: String, Codable {
        case positive
        case negative
    }

    let id: UUID
    let role: Role
    var content: String
    let createdAt: Date
    var feedback: Feedback?

    init(id: UUID = UUID(),
         role: Role,
         content: String,
         createdAt: Date = Date(),
         feedback: Feedback? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.feedback = feedback
    }
}
