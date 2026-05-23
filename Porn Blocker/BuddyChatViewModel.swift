import Foundation

/// Owns the active buddy-chat conversation, the input draft, and the
/// streaming task. Auto-persists on each exchange.
@MainActor
final class BuddyChatViewModel: ObservableObject {
    @Published var conversation: ChatConversation
    @Published var draft: String = ""
    @Published private(set) var isStreaming = false
    @Published var streamError: String?

    private var streamTask: Task<Void, Never>?
    private let store: ConversationStore
    private let subManager: SubscriptionManager

    /// Common-case init — resolves the singletons inside the body to avoid
    /// the Swift 6 "main actor-isolated default argument" warning.
    init() {
        self.conversation = ChatConversation()
        self.store = .shared
        self.subManager = .shared
    }

    /// Test-friendly init.
    init(conversation: ChatConversation,
         store: ConversationStore,
         subManager: SubscriptionManager) {
        self.conversation = conversation
        self.store = store
        self.subManager = subManager
    }

    // MARK: - Actions

    /// Sends the current draft. No-ops if empty, already streaming, or unsubscribed.
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        guard let jws = subManager.signedTransactionJWS else {
            streamError = "Your subscription isn't ready yet — try again in a moment."
            return
        }

        draft = ""
        streamError = nil

        // Append the user message and an empty assistant placeholder.
        var working = conversation
        working.messages.append(ChatMessage(role: .user, content: text))
        if working.title.isEmpty || working.title == "New chat" {
            working.title = working.derivedTitle ?? working.title
        }
        let assistantID = UUID()
        working.messages.append(ChatMessage(id: assistantID, role: .assistant, content: ""))
        conversation = working
        store.upsert(conversation)

        // Build the request body — drop the empty placeholder; the model
        // only sees real turns.
        let messagesForRequest = Array(conversation.messages.dropLast())

        isStreaming = true
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = BuddyChatService.streamChat(
                    signedTransaction: jws,
                    messages: messagesForRequest
                )
                for try await delta in stream {
                    self.appendDelta(delta, to: assistantID)
                }
            } catch is CancellationError {
                // user cancelled, nothing to surface
            } catch {
                self.streamError = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
            self.isStreaming = false
            self.store.upsert(self.conversation)
        }
    }

    /// Cancels an in-flight stream. Whatever has been streamed so far stays.
    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        store.upsert(conversation)
    }

    /// Starts a fresh conversation, discarding the current draft and any
    /// in-flight stream. The previous conversation has already been persisted.
    func newChat() {
        cancel()
        conversation = ChatConversation()
        draft = ""
        streamError = nil
    }

    /// Loads an existing conversation from history.
    func load(_ conversation: ChatConversation) {
        cancel()
        self.conversation = conversation
        draft = ""
        streamError = nil
    }

    /// Sets (or clears) a thumbs up/down for an assistant message. Tapping the
    /// same value again clears it.
    func setFeedback(messageID: UUID, feedback: ChatMessage.Feedback?) {
        guard let idx = conversation.messages.firstIndex(where: { $0.id == messageID }) else { return }
        conversation.messages[idx].feedback = feedback
        store.upsert(conversation)
    }

    // MARK: - Private

    private func appendDelta(_ text: String, to messageID: UUID) {
        guard let idx = conversation.messages.firstIndex(where: { $0.id == messageID }) else { return }
        conversation.messages[idx].content += text
    }
}
