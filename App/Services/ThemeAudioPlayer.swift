import AVFoundation
import Observation

@MainActor @Observable final class ThemeAudioPlayer {
    private(set) var isPlaying = false
    private var player: AVAudioPlayer?
    private var activeThemeID: String?

    func toggle(theme: Theme) async {
        guard let scene = theme.remoteScene,
              let assetName = scene.ambientAudioAsset,
              let source = theme.remoteAssetURLs[assetName],
              let version = theme.remoteContentVersion else { return }

        if isPlaying, activeThemeID == theme.id {
            stop()
            return
        }
        stop()
        guard let file = await RemoteAssetCache.shared.audioURL(
            source: source, contentVersion: version, itemID: theme.id, assetName: assetName
        ) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let audioPlayer = try AVAudioPlayer(contentsOf: file)
            audioPlayer.numberOfLoops = -1
            audioPlayer.volume = 0.72
            guard audioPlayer.prepareToPlay(), audioPlayer.play() else {
                stop()
                return
            }
            player = audioPlayer
            activeThemeID = theme.id
            isPlaying = true
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        activeThemeID = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
