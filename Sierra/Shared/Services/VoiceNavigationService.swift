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
    private var cachedPreferredVoice: AVSpeechSynthesisVoice?

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
        utterance.voice = preferredVoice()
        utterance.rate  = 0.52
        utterance.pitchMultiplier = 1.08
        utterance.preUtteranceDelay = 0.08
        utterance.postUtteranceDelay = 0.04
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

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        if let cachedPreferredVoice { return cachedPreferredVoice }

        let voices = AVSpeechSynthesisVoice.speechVoices()

        let preferred = voices
            .filter { $0.language.lowercased().hasPrefix("en-us") }
            .max { voiceScore($0) < voiceScore($1) }
            ?? voices
            .filter { $0.language.lowercased().hasPrefix("en-") }
            .max { voiceScore($0) < voiceScore($1) }
            ?? AVSpeechSynthesisVoice(language: "en-US")

        cachedPreferredVoice = preferred
        return preferred
    }

    private func voiceScore(_ voice: AVSpeechSynthesisVoice) -> Int {
        let qualityScore: Int
        switch voice.quality {
        case .premium:
            qualityScore = 3
        case .enhanced:
            qualityScore = 2
        default:
            qualityScore = 1
        }

        let usBoost = voice.language.lowercased().hasPrefix("en-us") ? 20 : 0
        return usBoost + qualityScore
    }
}
