import AVFoundation

// MARK: - ElevenLabs TTS Service

final class ElevenLabsService: NSObject, AVAudioPlayerDelegate {
    static let shared = ElevenLabsService()

    // Chris — charming, down-to-earth, warm
    private let voiceID = "iP95p4xoKVk5"
    private let apiURL = "https://api.elevenlabs.io/v1/text-to-speech/"
    private let model = "eleven_turbo_v2_5"

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "ELEVENLABS_API_KEY") ?? ""
    }

    private var audioPlayer: AVAudioPlayer?
    private var isSpeaking = false

    // Throttle: don't voice every single message
    private var lastSpeakTime: Date = .distantPast
    private let minInterval: TimeInterval = 50  // seconds between voiced lines

    private override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Non-fatal — audio just won't play
        }
    }

    // MARK: - Public API

    /// Speak a message as Chip. Throttled and fire-and-forget.
    func speak(_ text: String) {
        guard !apiKey.isEmpty else { return }
        guard !isSpeaking else { return }

        let now = Date()
        guard now.timeIntervalSince(lastSpeakTime) >= minInterval else { return }
        lastSpeakTime = now

        Task {
            await synthesizeAndPlay(text)
        }
    }

    /// Stop any current playback.
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }

    // MARK: - API Call

    private func synthesizeAndPlay(_ text: String) async {
        isSpeaking = true

        guard let url = URL(string: "\(apiURL)\(voiceID)") else {
            isSpeaking = false
            return
        }

        let body: [String: Any] = [
            "text": text,
            "model_id": model,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
                "style": 0.4,
                "use_speaker_boost": true
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            isSpeaking = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  data.count > 1000 else {  // sanity check — valid audio is > 1KB
                isSpeaking = false
                return
            }

            await MainActor.run {
                playAudio(data: data)
            }
        } catch {
            isSpeaking = false
        }
    }

    private func playAudio(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 0.85
            audioPlayer?.play()
        } catch {
            isSpeaking = false
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isSpeaking = false
        audioPlayer = nil
    }
}
