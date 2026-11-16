import AppKit
import SwiftUI
import AVKit

/// Native runtime smoke test: typechecking alone cannot detect missing AVKit linkage.
@main struct MeetingPlaybackSmoke {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        let url = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
        let player = url.map { AVPlayer(url: $0) }
        player?.isMuted = true
        let host = NSHostingView(rootView: VideoPlayer(player: nil))
        window.contentView = host
        window.orderFront(nil)
        Task { @MainActor in
            do {
                // Exercise the nil -> player -> nil -> player lifecycle used by the detail page.
                for value in [player, nil, player] {
                    host.rootView = VideoPlayer(player: value)
                    host.layoutSubtreeIfNeeded()
                    try await Task.sleep(for: .milliseconds(250))
                }
                if let player {
                    for _ in 0..<100 where player.currentItem?.status != .readyToPlay {
                        if let error = player.currentItem?.error { throw error }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    guard player.currentItem?.status == .readyToPlay else { throw SmokeFailure.notReady }
                    player.play()
                    try await Task.sleep(for: .seconds(1))
                    guard player.currentTime().seconds > 0 else { throw SmokeFailure.didNotAdvance }
                    player.pause()
                    print("PLAYBACK_MEDIA_ADVANCED")
                }
                print("PLAYBACK_VIEW_OK")
                window.orderOut(nil)
                app.terminate(nil)
            } catch {
                fputs("Playback smoke failed: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }
    enum SmokeFailure: Error { case notReady, didNotAdvance }
}
