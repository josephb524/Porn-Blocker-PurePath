import Foundation

/// Streaming client for the buddy-chat Cloudflare Worker.
///
/// The Worker verifies the StoreKit signed transaction, then proxies the
/// conversation to the AI provider and streams back the assistant reply as
/// Server-Sent Events. This client parses those events and yields each text
/// delta as it arrives.
enum BuddyChatService {

    /// Deployed Cloudflare Worker URL. **Update this after you run
    /// `wrangler deploy`** — see `worker/README.md`.
    static var endpoint: URL = URL(string: "https://porn-blocker-buddy.bible-chat-worker.workers.dev/chat")!

    // MARK: - Wire types

    private struct Request: Encodable {
        let signedTransaction: String
        let messages: [Message]
        struct Message: Encodable {
            let role: String   // "user" | "assistant"
            let content: String
        }
    }

    private struct SSEDelta: Decodable {
        let text: String?
    }

    // MARK: - Streaming

    /// Streams the assistant reply as text deltas. Throws on transport
    /// failure, on non-2xx HTTP responses, and on cancellation.
    static func streamChat(
        signedTransaction: String,
        messages: [ChatMessage]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var req = URLRequest(url: endpoint)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.timeoutInterval = 60

                    let payload = Request(
                        signedTransaction: signedTransaction,
                        messages: messages.map {
                            Request.Message(role: $0.role.rawValue, content: $0.content)
                        }
                    )
                    req.httpBody = try JSONEncoder().encode(payload)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)

                    guard let http = response as? HTTPURLResponse else {
                        throw BuddyChatError.invalidResponse
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        var body = ""
                        for try await line in bytes.lines {
                            body += line + "\n"
                            if body.count > 1024 { break }
                        }
                        throw BuddyChatError.http(
                            status: http.statusCode,
                            body: body.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line
                            .dropFirst("data:".count)
                            .trimmingCharacters(in: .whitespaces)
                        if payload.isEmpty || payload == "[DONE]" {
                            if payload == "[DONE]" { break }
                            continue
                        }
                        guard let data = payload.data(using: .utf8),
                              let delta = try? JSONDecoder().decode(SSEDelta.self, from: data),
                              let text = delta.text else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Errors

enum BuddyChatError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)
    case notSubscribed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        case .http(let status, let body):
            if body.isEmpty {
                return "Server error \(status)."
            }
            return "Server error \(status): \(body)"
        case .notSubscribed:
            return "Subscribe to chat with your buddy."
        }
    }
}
