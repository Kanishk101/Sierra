import AVFoundation

// MARK: - VoiceNavigationService
// Phase 10: Text-to-speech for turn-by-turn navigation announcements.
// Uses AVSpeechSynthesizer. Respects device silent mode via AVAudioSession check.

final class VoiceNavigationService {

    static let shared = VoiceNavigationService()

    private let synthesizer = AVSpeechSynthesizer()
    private var isMuted = false
    private var lastAnnouncement: String = ""
    private var lastAnnouncementAt: Date = .distantPast

    private init() {}

    /// Announce a navigation instruction aloud.
    /// No-ops if the user has muted voice or the device ringer is off.
    func announce(_ text: String) {
        guard !isMuted else { return }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        // De-dupe repeated announcements in a short window.
        if normalized == lastAnnouncement,
           Date().timeIntervalSince(lastAnnouncementAt) < 4 {
            return
        }
        lastAnnouncement = normalized
        lastAnnouncementAt = Date()

        // Activate audio session for playback (ducks music, works when locked)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)

        // Respect device silent/ringer switch — if output volume is near zero, skip
        if session.outputVolume < 0.05 { return }

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: normalized)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
        utterance.rate  = 0.48
        utterance.pitchMultiplier = 1.05
        utterance.preUtteranceDelay = 0.15
        synthesizer.speak(utterance)
    }

    /// Toggle mute on/off.
    func toggleMute() {
        setMuted(!isMuted)
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted { synthesizer.stopSpeaking(at: .immediate) }
    }

    /// Current mute state.
    var isMutedState: Bool { isMuted }

    /// Stop any active speech immediately.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
