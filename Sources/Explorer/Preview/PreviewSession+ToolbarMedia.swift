import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewMediaToolbarItems() -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "media-play",
                title: media.isPlaying ? "暂停" : "播放",
                systemImage: media.isPlaying ? "pause.fill" : "play.fill",
                action: { [self] in media.controlAction = .togglePlayPause }
            ),
            previewToolbarIconItem(
                id: "media-mute",
                title: media.isMuted ? "取消静音" : "静音",
                systemImage: media.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                action: { [self] in media.controlAction = .toggleMute }
            ),
        ]
    }
}
