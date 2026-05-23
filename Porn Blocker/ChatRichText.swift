import SwiftUI

/// Lightweight markdown renderer for assistant messages.
///
/// The buddy chat's system prompt biases the model toward conversational
/// prose, so we only handle the common inline cases plus blockquotes and
/// bullet lists. Headings, tables, code fences, and HTML are flattened to
/// plain text so the assistant can't visually overrun the chat bubble.
struct ChatRichText: View {
    let content: String

    var body: some View {
        let blocks = Self.parseBlocks(content)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
    }

    // MARK: - Block model

    private enum Block {
        case paragraph(String)
        case bullets([String])
        case quote(String)
    }

    private static func parseBlocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var quote: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }
        func flushBullets() {
            if !bullets.isEmpty {
                blocks.append(.bullets(bullets))
                bullets.removeAll()
            }
        }
        func flushQuote() {
            if !quote.isEmpty {
                blocks.append(.quote(quote.joined(separator: " ")))
                quote.removeAll()
            }
        }
        func flushAll() {
            flushParagraph(); flushBullets(); flushQuote()
        }

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushAll()
                continue
            }
            // Strip headings (`# Title`) to plain emphasized text.
            if line.hasPrefix("#") {
                flushBullets(); flushQuote()
                let stripped = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                paragraph.append("**\(stripped)**")
                continue
            }
            if line == "---" || line == "***" {
                flushAll()
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flushParagraph(); flushQuote()
                bullets.append(String(line.dropFirst(2)))
                continue
            }
            if line.hasPrefix("> ") {
                flushParagraph(); flushBullets()
                quote.append(String(line.dropFirst(2)))
                continue
            }
            flushBullets(); flushQuote()
            paragraph.append(line)
        }
        flushAll()
        return blocks
    }

    // MARK: - Rendering

    @ViewBuilder
    private func render(_ block: Block) -> some View {
        switch block {
        case .paragraph(let text):
            inlineText(text)
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        inlineText(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(width: 3)
                inlineText(text)
                    .foregroundColor(.secondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Renders inline markdown (`**bold**`, `*italic*`, `` `code` ``, links).
    /// Falls back to plain text if the markdown parser rejects the input.
    private func inlineText(_ s: String) -> Text {
        if let attr = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(s)
    }
}

/// Three pulsing dots — shown while the assistant message is empty and
/// streaming hasn't yielded its first delta yet.
struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animate ? 1.0 : 0.55)
                    .opacity(animate ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: animate
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
        .onAppear { animate = true }
    }
}
