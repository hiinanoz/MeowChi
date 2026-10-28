import AVFoundation
import os

/// Central audio. Uses the `.ambient` session: respects the silent switch and mixes with other apps' audio.
/// Missing files are skipped silently, so audio can never crash the game.
@MainActor
final class AudioManager {
    static let shared = AudioManager()

    enum Sound: String, CaseIterable {
        case tap, meow, purr, eat, coin, buy, levelUp = "levelup", splash, laserCatch = "catch", find

        var fileName: String { "sfx_" + rawValue }
        /// Minimum time between two plays of the same sound, to avoid machine-gun repeats.
        var minInterval: TimeInterval {
            switch self {
            case .purr, .meow, .splash: 0.9
            case .eat: 0.5
            default: 0.06
            }
        }
    }

    private var effects: [Sound: AVAudioPlayer] = [:]
    private var music: AVAudioPlayer?
    private var lastPlayed: [Sound: Date] = [:]
    private var settings = GameSettings()
    private let log = Logger(subsystem: "Meowchi", category: "Audio")

    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        } catch {
            log.error("Audio session: \(error.localizedDescription, privacy: .public)")
        }
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: "caf"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            effects[sound] = player
        }
        if let url = Bundle.main.url(forResource: "music_home", withExtension: "caf") {
            music = try? AVAudioPlayer(contentsOf: url)
            music?.numberOfLoops = -1
            music?.prepareToPlay()
        }
    }

    func apply(_ settings: GameSettings) {
        self.settings = settings
        music?.volume = Float(settings.musicVolume)
        for player in effects.values { player.volume = Float(settings.sfxVolume) }
        if settings.musicEnabled { resumeMusic() } else { music?.pause() }
    }

    func resumeMusic() {
        guard settings.musicEnabled, let music, !music.isPlaying else { return }
        music.play()
    }

    func pauseMusic() { music?.pause() }

    func play(_ sound: Sound) {
        guard settings.soundEnabled, let player = effects[sound] else { return }
        let now = Date()
        if let last = lastPlayed[sound], now.timeIntervalSince(last) < sound.minInterval { return }
        lastPlayed[sound] = now
        player.currentTime = 0
        player.play()
    }
}
