import SwiftUI
import AVKit

struct MediaPreview: NSViewRepresentable {
    let player: AVPlayer
    @Binding var controlAction: MediaControlAction?
    var onStateChanged: (_ isPlaying: Bool, _ isMuted: Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        context.coordinator.onStateChanged = onStateChanged
        context.coordinator.emitState(from: player)
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        context.coordinator.onStateChanged = onStateChanged

        if nsView.player !== player {
            nsView.player = player
        }

        if let action = controlAction {
            switch action {
            case .togglePlayPause:
                if player.timeControlStatus == .playing {
                    player.pause()
                } else {
                    player.play()
                }
            case .toggleMute:
                player.isMuted.toggle()
            }
            DispatchQueue.main.async { controlAction = nil }
        }
        context.coordinator.emitState(from: player)
    }

    final class Coordinator {
        var onStateChanged: ((_ isPlaying: Bool, _ isMuted: Bool) -> Void)?
        private var lastIsPlaying: Bool?
        private var lastIsMuted: Bool?

        func emitState(from player: AVPlayer) {
            let isPlaying = player.timeControlStatus == .playing
            let isMuted = player.isMuted
            guard isPlaying != lastIsPlaying || isMuted != lastIsMuted else { return }
            lastIsPlaying = isPlaying
            lastIsMuted = isMuted
            onStateChanged?(isPlaying, isMuted)
        }
    }
}
