import Foundation
import AVFoundation

/// Speaks form errors aloud via text-to-speech in Russian.
/// Prevents interrupting itself — only speaks after cooldown period.
final class VoiceCoach {
    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenError: String = ""
    private var lastSpokenTime: Date = .distantPast
    /// Minimum seconds between consecutive speech utterances
    var cooldownSeconds: TimeInterval = 4.0

    init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[KiviFit] Audio session error: \(error)")
        }
    }

    /// Speaks the most critical error if cooldown has elapsed.
    func announce(errors: [FormError]) {
        guard !errors.isEmpty else { return }

        // Prefer critical errors
        let toSpeak = errors.first(where: { $0.severity == .critical }) ?? errors.first!

        let now = Date()
        guard toSpeak.message != lastSpokenError ||
              now.timeIntervalSince(lastSpokenTime) >= cooldownSeconds else { return }

        lastSpokenError = toSpeak.message
        lastSpokenTime = now

        speak(toSpeak.message)
    }

    func speak(_ text: String) {
        // Never interrupt ongoing speech — let it finish first.
        guard !synthesizer.isSpeaking else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
}
