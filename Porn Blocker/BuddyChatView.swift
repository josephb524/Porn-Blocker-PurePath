import SwiftUI

/// The Buddy tab. Shows the chat for subscribers; a marketing/paywall gate
/// otherwise — same pattern as `SafeBrowserView` so the locked feature feels
/// consistent across the app.
struct BuddyChatView: View {
    @StateObject private var subManager = SubscriptionManager.shared

    var body: some View {
        if subManager.isSubscribed {
            BuddyChatContent()
        } else {
            BuddyLockedView()
        }
    }
}

// MARK: - Locked Gate (non-subscribers)

private struct BuddyLockedView: View {
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var showPaywall = false

    private let accent = Color(hue: 0.38, saturation: 0.65, brightness: 0.5)

    /// Caption under the "Unlock Buddy Chat" button. Mirrors the paywall:
    /// if the default plan (yearly) has a free-trial offer, mention it;
    /// otherwise just say "Cancel anytime".
    private var trialTeaserText: String {
        if let trial = subManager.yearlyProduct?.freeTrialText {
            return "\(trial) · Cancel anytime"
        }
        return "Cancel anytime"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: 0.6, saturation: 0.5, brightness: 0.15),
                        Color(hue: 0.6, saturation: 0.6, brightness: 0.08)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(hue: 0.6, saturation: 0.6, brightness: 0.4).opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -80, y: -120)

                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 250, height: 250)
                    .blur(radius: 50)
                    .offset(x: 100, y: 200)

                VStack(spacing: 28) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 110, height: 110)
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 80, height: 80)
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(hue: 0.6, saturation: 0.3, brightness: 0.9)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }

                    VStack(spacing: 10) {
                        Text("Talk to your buddy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("A judgment-free chat for your journey to quit porn. Talk through urges, relapses, and wins — anytime.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    VStack(spacing: 10) {
                        LockedFeatureRow(icon: "heart.text.square.fill", text: "Empathetic, non-judgmental support")
                        LockedFeatureRow(icon: "clock.fill",             text: "Available whenever an urge hits")
                        LockedFeatureRow(icon: "lock.fill",              text: "Conversations stay on your device")
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.open.fill")
                                Text("Unlock Buddy Chat")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(hue: 0.6, saturation: 0.7, brightness: 0.75),
                                        accent
                                    ],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(18)
                            .shadow(
                                color: accent.opacity(0.4),
                                radius: 14, x: 0, y: 6
                            )
                        }
                        .padding(.horizontal, 24)

                        Text(trialTeaserText)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPaywall) {
                NavigationStack {
                    PaywallScreen(isPresented: $showPaywall)
                }
            }
        }
    }
}

private struct LockedFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hue: 0.6, saturation: 0.4, brightness: 0.85))
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Chat Content (subscribers)

private struct BuddyChatContent: View {
    @StateObject private var viewModel = BuddyChatViewModel()
    @StateObject private var store = ConversationStore.shared
    @StateObject private var speech = SpeechController.shared
    @FocusState private var inputFocused: Bool
    @State private var showHistory = false

    private let accent = Color(hue: 0.38, saturation: 0.65, brightness: 0.5)

    private let suggestedPrompts: [String] = [
        "I just had an urge — what should I do?",
        "I relapsed last night. Can we talk?",
        "How do I tell my partner I'm struggling with this?",
        "What's a healthier way to deal with stress?"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .onTapGesture { inputFocused = false }

                VStack(spacing: 0) {
                    messagesList

                    if let err = viewModel.streamError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }

                    composer
                }
            }
            .navigationTitle("Buddy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                    .accessibilityLabel("Chat history")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.newChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New chat")
                }
            }
            .sheet(isPresented: $showHistory) {
                ConversationListView { conversation in
                    viewModel.load(conversation)
                    showHistory = false
                }
            }
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private var messagesList: some View {
        if viewModel.conversation.messages.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.conversation.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                        // Typing indicator while we're streaming but haven't
                        // received the first delta yet.
                        if viewModel.isStreaming,
                           let last = viewModel.conversation.messages.last,
                           last.role == .assistant,
                           last.content.isEmpty {
                            HStack {
                                TypingIndicator()
                                Spacer(minLength: 40)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.conversation.messages.last?.id) { newID in
                    guard let newID else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(newID, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.conversation.messages.last?.content) { _ in
                    if let id = viewModel.conversation.messages.last?.id {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 96, height: 96)
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(accent)
                }

                VStack(spacing: 6) {
                    Text("Hey, glad you're here.")
                        .font(.title3.bold())
                    Text("This is a private space. Tell me what's going on — an urge, a slip, a small win, anything.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 8) {
                    ForEach(suggestedPrompts, id: \.self) { prompt in
                        Button {
                            viewModel.draft = prompt
                            viewModel.send()
                        } label: {
                            HStack {
                                Text(prompt)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                Spacer(minLength: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Group {
                    if isUser {
                        Text(message.content)
                            .foregroundColor(.white)
                    } else {
                        ChatRichText(content: message.content)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isUser ? accent : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isUser ? Color.clear : Color(.systemGray5), lineWidth: 1)
                )

                if !isUser && !message.content.isEmpty {
                    assistantActionBar(message)
                }
            }

            if !isUser { Spacer(minLength: 48) }
        }
    }

    private func assistantActionBar(_ message: ChatMessage) -> some View {
        HStack(spacing: 16) {
            Button {
                UIPasteboard.general.string = message.content
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .accessibilityLabel("Copy")

            Button {
                speech.toggle(messageID: message.id, text: message.content)
            } label: {
                Image(systemName: speech.speakingMessageID == message.id
                      ? "stop.circle"
                      : "speaker.wave.2")
            }
            .accessibilityLabel("Read aloud")

            Spacer()

            Button {
                viewModel.setFeedback(
                    messageID: message.id,
                    feedback: message.feedback == .positive ? nil : .positive
                )
            } label: {
                Image(systemName: message.feedback == .positive
                      ? "hand.thumbsup.fill"
                      : "hand.thumbsup")
                    .foregroundColor(message.feedback == .positive ? accent : .secondary)
            }
            .accessibilityLabel("Helpful")

            Button {
                viewModel.setFeedback(
                    messageID: message.id,
                    feedback: message.feedback == .negative ? nil : .negative
                )
            } label: {
                Image(systemName: message.feedback == .negative
                      ? "hand.thumbsdown.fill"
                      : "hand.thumbsdown")
                    .foregroundColor(message.feedback == .negative ? .red : .secondary)
            }
            .accessibilityLabel("Not helpful")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 4)
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message your buddy", text: $viewModel.draft, axis: .vertical)
                .focused($inputFocused)
                .lineLimit(1...5)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                )

            Button {
                if viewModel.isStreaming {
                    viewModel.cancel()
                } else {
                    viewModel.send()
                }
            } label: {
                Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(sendButtonColor)
                    )
            }
            .disabled(!viewModel.isStreaming && draftIsEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }

    private var draftIsEmpty: Bool {
        viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sendButtonColor: Color {
        if viewModel.isStreaming { return .red }
        return draftIsEmpty ? Color(.systemGray3) : accent
    }
}

#Preview {
    BuddyChatView()
}
