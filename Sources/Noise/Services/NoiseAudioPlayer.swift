import AVFoundation
import Foundation

protocol NoiseAudioPlayback: AnyObject {
    var isPlaying: Bool { get }
    var numberOfLoops: Int { get set }
    var volume: Float { get set }
    @discardableResult func prepareToPlay() -> Bool
    @discardableResult func play() -> Bool
    func stop()
    func setVolume(_ volume: Float, fadeDuration: TimeInterval)
}

extension AVAudioPlayer: NoiseAudioPlayback {}

final class NoiseAudioPlayer {
    private let makePlayer: (URL) throws -> NoiseAudioPlayback
    private var pendingStop: DispatchWorkItem?
    private var player: NoiseAudioPlayback?
    private var playingSound: NoiseSound = .none

    init(makePlayer: @escaping (URL) throws -> NoiseAudioPlayback = { try AVAudioPlayer(contentsOf: $0) }) {
        self.makePlayer = makePlayer
    }

    deinit {
        pendingStop?.cancel()
        player?.stop()
    }

    func play(_ sound: NoiseSound, volume: Double, fadeIn: Double) {
        cancelPendingStop()
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
            let next = try makePlayer(url)
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
        cancelPendingStop()
        guard let current = player else {
            playingSound = .none
            return
        }

        let fadeOut = max(fadeOut, 0)
        if fadeOut > 0, current.isPlaying {
            current.setVolume(0, fadeDuration: fadeOut)
            let workItem = DispatchWorkItem { [weak self, weak current] in
                guard let self, self.player === current else { return }
                current?.stop()
                self.player = nil
                self.playingSound = .none
                self.pendingStop = nil
            }
            pendingStop = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut, execute: workItem)
        } else {
            current.stop()
            player = nil
            playingSound = .none
        }
    }

    private func cancelPendingStop() {
        pendingStop?.cancel()
        pendingStop = nil
    }
}
