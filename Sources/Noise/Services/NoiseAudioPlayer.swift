import AVFoundation
import Foundation

final class NoiseAudioPlayer {
    private var player: AVAudioPlayer?
    private var playingSound: NoiseSound = .none

    func play(_ sound: NoiseSound, volume: Double, fadeIn: Double) {
        guard !sound.isNone else {
            stop(fadeOut: 0)
            return
        }

        if playingSound == sound, player?.isPlaying == true {
            player?.setVolume(Float(min(max(volume, 0), 1)), fadeDuration: max(fadeIn, 0))
            return
        }

        guard let url = NoiseSoundLibrary.url(for: sound) else {
            NSLog("Noise sound missing: \(sound.id)")
            stop(fadeOut: 0)
            return
        }

        do {
            let next = try AVAudioPlayer(contentsOf: url)
            next.numberOfLoops = -1
            next.volume = fadeIn > 0 ? 0 : Float(min(max(volume, 0), 1))
            next.prepareToPlay()
            player?.stop()
            player = next
            playingSound = sound
            next.play()
            if fadeIn > 0 {
                next.setVolume(Float(min(max(volume, 0), 1)), fadeDuration: fadeIn)
            }
        } catch {
            NSLog("Noise sound failed to play: \(sound.id), \(error.localizedDescription)")
            stop(fadeOut: 0)
        }
    }

    func updateVolume(_ volume: Double) {
        player?.volume = Float(min(max(volume, 0), 1))
    }

    func stop(fadeOut: Double) {
        guard let current = player else {
            playingSound = .none
            return
        }

        let fadeOut = max(fadeOut, 0)
        if fadeOut > 0, current.isPlaying {
            current.setVolume(0, fadeDuration: fadeOut)
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) { [weak self, weak current] in
                guard self?.player === current else { return }
                current?.stop()
                self?.player = nil
                self?.playingSound = .none
            }
        } else {
            current.stop()
            player = nil
            playingSound = .none
        }
    }
}
