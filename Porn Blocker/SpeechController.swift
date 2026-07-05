import AVFoundation
import Foundation

/// Read-aloud controller for assistant messages. Wraps `AVSpeechSynthesizer`
/// and tracks which message is currently being spoken so the UI can flip
/// the speaker icon to "stop".
@MainActor
final class SpeechController: NSObject, ObservableObject {
    static let shared = SpeechController()

    @Published private(set) var speakingMessageID: UUID?

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public API

    func toggle(messageID: UUID, text: String) {
        if speakingMessageID == messageID {
            stop()
        } else {
            speak(messageID: messageID, text: text)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingMessageID = nil
        deactivateAudioSession()
    }

    // MARK: - Private

    private func speak(messageID: UUID, text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        // .playback so speech is audible with the ringer switch muted — the
        // default session category silences the synthesizer on muted devices.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
        let clean = Self.stripMarkdown(text)
        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
        speakingMessageID = messageID
    }

    fileprivate func handleSpeechEnded() {
        // The didCancel delegate callback lands on a later runloop turn; if a
        // new utterance already started (toggle from message A to B), don't
        // clear B's indicator or tear down the session underneath it.
        guard !synthesizer.isSpeaking else { return }
        speakingMessageID = nil
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Strips markdown noise that shouldn't be spoken aloud.
    static func stripMarkdown(_ s: String) -> String {
        var out = s
        for token in ["**", "__", "*", "_", "`", "###", "##", "#"] {
            out = out.replacingOccurrences(of: token, with: "")
        }
        // Strip blockquote markers and bullet leaders.
        out = out.replacingOccurrences(of: "\n> ", with: "\n")
        out = out.replacingOccurrences(of: "\n- ", with: "\n")
        out = out.replacingOccurrences(of: "\n* ", with: "\n")
        out = out.replacingOccurrences(of: "\n• ", with: "\n")
        if out.hasPrefix("> ") { out = String(out.dropFirst(2)) }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Delegate

extension SpeechController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.handleSpeechEnded() }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.handleSpeechEnded() }
    }
}
