import AVFoundation

// MARK: - VoiceNavigationService
// Phase 10: Text-to-speech for turn-by-turn navigation announcements.
// Uses AVSpeechSynthesizer. Respects device silent mode via AVAudioSession check.

final class VoiceNavigationService {

    static let shared = VoiceNavigationService()

    private let synthesizer = AVSpeechSynthesizer()
    private var isMuted = false

    private init() {}

    /// Announce a navigation instruction aloud.
    /// No-ops if the user has muted voice or the device ringer is off.
    func announce(_ text: String) {
        guard !isMuted else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Respect device silent/ringer switch — if output volume is near zero, skip
        let session = AVAudioSession.sharedInstance()
        if session.outputVolume < 0.05 { return }

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
        utterance.rate  = 0.48
        utterance.pitchMultiplier = 1.05
        utterance.preUtteranceDelay = 0.15
        synthesizer.speak(utterance)
    }

    /// Toggle mute on/off.
    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// Current mute state.
    var isMutedState: Bool { isMuted }

    /// Stop any active speech immediately.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
