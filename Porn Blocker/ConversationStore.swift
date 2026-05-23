import Foundation

/// Persists buddy-chat conversations to disk and publishes them so views
/// stay in sync. The store is the single source of truth for the chat
/// history list and for the currently-active conversation.
@MainActor
final class ConversationStore: ObservableObject {
    static let shared = ConversationStore()

    @Published private(set) var conversations: [ChatConversation] = []

    private let fileURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("buddy_chat_conversations.json")
    }()

    private init() {
        load()
    }

    // MARK: - Public API

    func upsert(_ conversation: ChatConversation) {
        var updated = conversation
        updated.updatedAt = Date()
        if let index = conversations.firstIndex(where: { $0.id == updated.id }) {
            conversations[index] = updated
        } else {
            conversations.insert(updated, at: 0)
        }
        sortByRecency()
        save()
    }

    func delete(_ conversation: ChatConversation) {
        conversations.removeAll { $0.id == conversation.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        conversations.remove(atOffsets: offsets)
        save()
    }

    func conversation(with id: UUID) -> ChatConversation? {
        conversations.first { $0.id == id }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.iso8601.decode([ChatConversation].self, from: data) else {
            conversations = []
            return
        }
        conversations = decoded
        sortByRecency()
    }

    private func save() {
        let snapshot = conversations
        let url = fileURL
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder.iso8601.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                Log.error("ConversationStore: save failed — \(error)")
            }
        }
    }

    private func sortByRecency() {
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }
}

// MARK: - Coders

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
