import AudioToolbox
import AVFoundation

final class SoundManager {
    static let shared = SoundManager()
    private var audioPlayer: AVAudioPlayer?

    private init() {}

    /// Soft satisfying click when completing a task (AudioToolbox system sound — zero latency)
    func playCompletion() {
        // 1104 = "Tock" — the cleanest short click in the iOS sound library
        AudioServicesPlaySystemSound(1104)
    }

    /// Gentle whoosh when rescheduling / "too busy today"
    func playReschedule() {
        AudioServicesPlaySystemSound(1057)
    }

    /// Subtle confirmation for adding a new task
    func playAdd() {
        AudioServicesPlaySystemSound(1113)
    }

    // MARK: - Custom audio support (post-MVP)
    // Drop a "completion_chime.wav" into the bundle and call this instead of playCompletion()
    private func playCustomChime(named name: String, extension ext: String = "wav") {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.volume = 0.5
        audioPlayer?.play()
    }
}
