import AVFoundation
import UIKit

// MARK: - Audio & Haptic Manager
final class AudioManager {
    static let shared = AudioManager()

    // Haptic generators (reused for performance)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    // TODO: Load actual sound files here via AVAudioPlayer
    // private var buildPlayer: AVAudioPlayer?
    // private var bgMusicPlayer: AVAudioPlayer?

    private init() {
        // Pre-warm haptic engines for lower latency
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationFeedback.prepare()
    }

    // MARK: - Game Event Sounds

    /// Equipment placed on the grid - medium haptic tap
    func playBuildSound() {
        // TODO: Play build.wav when available
        mediumImpact.impactOccurred()
    }

    /// Incident spawned - heavy impact + warning notification
    func playIncidentAlert() {
        // TODO: Play alert.wav when available
        heavyImpact.impactOccurred()
        notificationFeedback.notificationOccurred(.warning)
    }

    /// Incident resolved successfully - success notification
    func playResolveSound() {
        // TODO: Play resolve.wav when available
        notificationFeedback.notificationOccurred(.success)
    }

    /// Equipment upgraded - success notification + medium tap
    func playUpgradeSound() {
        // TODO: Play upgrade.wav when available
        notificationFeedback.notificationOccurred(.success)
        mediumImpact.impactOccurred()
    }

    /// Revenue collected - light haptic tap
    func playCoinCollect() {
        // TODO: Play coin.wav when available
        lightImpact.impactOccurred()
    }

    /// Start ambient background music loop
    func playBackgroundMusic() {
        // TODO: Load and loop background_music.m4a
        // guard let url = Bundle.main.url(forResource: "background_music", withExtension: "m4a") else { return }
        // bgMusicPlayer = try? AVAudioPlayer(contentsOf: url)
        // bgMusicPlayer?.numberOfLoops = -1
        // bgMusicPlayer?.volume = 0.3
        // bgMusicPlayer?.play()
    }

    /// Stop background music
    func stopBackgroundMusic() {
        // TODO: Stop and reset bgMusicPlayer
        // bgMusicPlayer?.stop()
        // bgMusicPlayer?.currentTime = 0
    }

    // MARK: - Drag-to-Fix Haptics

    /// Selection feedback while dragging a tool
    func playToolDrag() {
        lightImpact.impactOccurred(intensity: 0.5)
    }

    /// Success notification on correct tool drop
    func playToolDrop() {
        notificationFeedback.notificationOccurred(.success)
    }

    /// Error notification on wrong tool drop
    func playToolMiss() {
        notificationFeedback.notificationOccurred(.error)
    }

    // MARK: - Expansion & Progression Haptics

    /// Heavy impact + success for expansion unlock
    func playExpansionUnlock() {
        heavyImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.notificationFeedback.notificationOccurred(.success)
        }
    }

    /// Light impact for periodic coin earning
    func playCoinEarned() {
        lightImpact.impactOccurred(intensity: 0.3)
    }

    /// Triple haptic pattern for milestone achievements
    func playMilestone() {
        let delay: TimeInterval = 0.12
        mediumImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.mediumImpact.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay * 2) { [weak self] in
            self?.heavyImpact.impactOccurred()
        }
    }
}
