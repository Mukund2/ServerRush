import AVFoundation

// MARK: - Game Sound Types

enum GameSound: CaseIterable {
    case build
    case incidentAlert
    case resolve
    case upgrade
    case coinCollect
    case coinEarned
    case toolDrag
    case toolDropSuccess
    case toolDropMiss
    case expansionUnlock
    case milestone
    case uiTap
    case sell
}

// MARK: - Procedural Sound Engine

final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let playerNodes: [AVAudioPlayerNode]
    private let playerCount = 4
    private var nextPlayer = 0

    private var buffers: [GameSound: AVAudioPCMBuffer] = [:]

    var enabled: Bool = true
    var masterVolume: Float = 0.6 {
        didSet { engine.mainMixerNode.outputVolume = masterVolume }
    }

    private let sampleRate: Double = 44100

    private init() {
        // Create player node pool
        var nodes: [AVAudioPlayerNode] = []
        for _ in 0..<playerCount {
            nodes.append(AVAudioPlayerNode())
        }
        playerNodes = nodes

        setupEngine()
        renderAllBuffers()
    }

    // MARK: - Engine Setup

    private func setupEngine() {
        // Configure audio session (compatible with ElevenLabsService)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Non-fatal
        }

        let mixer = engine.mainMixerNode
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        for node in playerNodes {
            engine.attach(node)
            engine.connect(node, to: mixer, format: format)
        }

        mixer.outputVolume = masterVolume

        do {
            try engine.start()
        } catch {
            // Non-fatal — sounds just won't play
        }
    }

    // MARK: - Play

    func play(_ sound: GameSound) {
        guard enabled, let buffer = buffers[sound] else { return }

        let player = playerNodes[nextPlayer]
        nextPlayer = (nextPlayer + 1) % playerCount

        if player.isPlaying {
            player.stop()
        }

        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    // MARK: - Buffer Rendering

    private func renderAllBuffers() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        for sound in GameSound.allCases {
            let spec = soundSpec(for: sound)
            let frameCount = AVAudioFrameCount(sampleRate * spec.duration)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { continue }
            buffer.frameLength = frameCount

            guard let data = buffer.floatChannelData?[0] else { continue }

            switch sound {
            case .build:
                renderSweep(data, frames: frameCount, startFreq: 300, endFreq: 600, duration: spec.duration)
            case .incidentAlert:
                renderTwoToneAlarm(data, frames: frameCount, freq1: 800, freq2: 600, duration: spec.duration)
            case .resolve:
                renderArpeggio(data, frames: frameCount, freqs: [400, 500, 700], duration: spec.duration)
            case .upgrade:
                renderArpeggio(data, frames: frameCount, freqs: [500, 650, 900], duration: spec.duration)
            case .coinCollect:
                renderPing(data, frames: frameCount, freq: 1200, duration: spec.duration)
            case .coinEarned:
                renderPing(data, frames: frameCount, freq: 900, duration: spec.duration)
            case .toolDrag:
                renderClick(data, frames: frameCount, freq: 600, duration: spec.duration)
            case .toolDropSuccess:
                renderChord(data, frames: frameCount, freqs: [700, 1050], duration: spec.duration)
            case .toolDropMiss:
                renderChord(data, frames: frameCount, freqs: [200, 250], duration: spec.duration)
            case .expansionUnlock:
                renderArpeggio(data, frames: frameCount, freqs: [400, 600, 800, 1000], duration: spec.duration)
            case .milestone:
                renderChord(data, frames: frameCount, freqs: [523, 659, 784], duration: spec.duration)
            case .uiTap:
                renderClick(data, frames: frameCount, freq: 1000, duration: spec.duration)
            case .sell:
                renderSweep(data, frames: frameCount, startFreq: 600, endFreq: 400, duration: spec.duration)
            }

            buffers[sound] = buffer
        }
    }

    private func soundSpec(for sound: GameSound) -> (duration: Double, Void) {
        switch sound {
        case .build:           return (0.25, ())
        case .incidentAlert:   return (0.4, ())
        case .resolve:         return (0.3, ())
        case .upgrade:         return (0.4, ())
        case .coinCollect:     return (0.15, ())
        case .coinEarned:      return (0.1, ())
        case .toolDrag:        return (0.08, ())
        case .toolDropSuccess: return (0.2, ())
        case .toolDropMiss:    return (0.2, ())
        case .expansionUnlock: return (0.5, ())
        case .milestone:       return (0.5, ())
        case .uiTap:           return (0.05, ())
        case .sell:            return (0.2, ())
        }
    }

    // MARK: - Waveform Generators

    /// Frequency sweep (rising or falling sine)
    private func renderSweep(_ data: UnsafeMutablePointer<Float>, frames: AVAudioFrameCount, startFreq: Double, endFreq: Double, duration: Double) {
        let count = Int(frames)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let progress = t / duration
            let freq = startFreq + (endFreq - startFreq) * progress
            let envelope = ampEnvelope(progress: progress, attack: 0.05, decay: 0.3)
            data[i] = Float(sin(2.0 * .pi * freq * t) * envelope)
        }
    }

    /// Two-tone alternating alarm
    private func renderTwoToneAlarm(_ data: UnsafeMutablePointer<Float>, frames: AVAudioFrameCount, freq1: Double, freq2: Double, duration: Double) {
        let count = Int(frames)
        let toggleRate = 8.0 // switches per second
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let progress = t / duration
            let freq = Int(t * toggleRate) % 2 == 0 ? freq1 : freq2
            let envelope = ampEnvelope(progress: progress, attack: 0.02, decay: 0.2)
            data[i] = Float(sin(2.0 * .pi * freq * t) * envelope * 0.7)
        }
    }

    /// Rising arpeggio (sequential tones)
    private func renderArpeggio(_ data: UnsafeMutablePointer<Float>, frames: AVAudioFrameCount, freqs: [Double], duration: Double) {
        let count = Int(frames)
        let noteCount = freqs.count
        let noteDuration = duration / Double(noteCount)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let noteIndex = min(Int(t / noteDuration), noteCount - 1)
            let noteT = t - Double(noteIndex) * noteDuration
            let noteProgress = noteT / noteDuration
            let envelope = ampEnvelope(progress: noteProgress, attack: 0.05, decay: 0.4)
            data[i] = Float(sin(2.0 * .pi * freqs[noteIndex] * t) * envelope * 0.6)
        }
    }

    /// High-frequency ping with fast decay
    private func renderPing(_ data: UnsafeMutablePointer<Float>, frames: AVAudioFrameCount, freq: Double, duration: Double) {
        let count = Int(frames)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let progress = t / duration
            // Fast exponential decay
            let envelope = max(0, 1.0 - progress * progress * 4)
            data[i] = Float(sin(2.0 * .pi * freq * t) * envelope * 0.5)
        }
    }

    /// Very short click sound
    private func renderClick(_ data: UnsafeMutablePointer<Float>, frames: AVAudioFrameCount, freq: Double, duration: Double) {
        let count = Int(frames)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let progress = t / duration
            // Instant attack, immediate decay
            let envelope = max(0, 1.0 - progress * 6)
            data[i] = Float(sin(2.0 * .pi * freq * t) * envelope * 0.4)
        }
    }

    /// Chord (multiple frequencies simultaneously)
    private func renderChord(_ data: UnsafeMutablePointer<Float>, frames: AVAudioFrameCount, freqs: [Double], duration: Double) {
        let count = Int(frames)
        let amp = 0.5 / Double(freqs.count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let progress = t / duration
            let envelope = ampEnvelope(progress: progress, attack: 0.03, decay: 0.3)
            var sample = 0.0
            for freq in freqs {
                sample += sin(2.0 * .pi * freq * t)
            }
            data[i] = Float(sample * amp * envelope)
        }
    }

    // MARK: - Envelope

    /// Simple amplitude envelope: linear attack, sustain, then decay
    private func ampEnvelope(progress: Double, attack: Double, decay: Double) -> Double {
        if progress < attack {
            return progress / attack
        }
        let decayStart = 1.0 - decay
        if progress > decayStart {
            return max(0, (1.0 - progress) / decay)
        }
        return 1.0
    }
}
