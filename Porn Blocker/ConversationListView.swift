import SwiftUI

/// Chat-history sheet. Tapping a row delegates back via `onSelect`; rows can
/// be swiped to delete. Persistence flows through `ConversationStore`.
struct ConversationListView: View {
    @StateObject private var store = ConversationStore.shared
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ChatConversation) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if store.conversations.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.conversations) { conv in
                            Button {
                                onSelect(conv)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conv.title.isEmpty ? "New chat" : conv.title)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(conv.updatedAt, format: .relative(presentation: .named))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { store.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No conversations yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
