import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewMediaToolbarItems() -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "media-play",
                title: media.isPlaying ? L10n.Preview.Toolbar.pause : L10n.Preview.Toolbar.play,
                systemImage: media.isPlaying ? "pause.fill" : "play.fill",
                action: { [self] in media.controlAction = .togglePlayPause }
            ),
            previewToolbarIconItem(
                id: "media-mute",
                title: media.isMuted ? L10n.Preview.Toolbar.unmute : L10n.Preview.Toolbar.mute,
                systemImage: media.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                action: { [self] in media.controlAction = .toggleMute }
            ),
        ]
    }
}
