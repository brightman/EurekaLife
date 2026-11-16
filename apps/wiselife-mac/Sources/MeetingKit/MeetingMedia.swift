import Foundation
import AVFoundation

public enum MeetingMedia {
    public struct Info: Sendable { public let duration: Double; public let bytes: Int64; public let videoTracks: Int; public let audioTracks: Int }
    public static func inspect(_ url: URL, requireVideo: Bool) async throws -> Info {
        let bytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        guard bytes > 0 else { throw MeetingFailure.message("录制文件为空，未标记为已保存。请检查权限后重试。") }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let videos = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        guard duration.isFinite, duration > 0, requireVideo ? !videos.isEmpty : !audio.isEmpty,
              try await asset.load(.isPlayable) else { throw MeetingFailure.message("文件尚未完成或无法回放，原始文件已保留。") }
        return Info(duration: duration, bytes: bytes, videoTracks: videos.count, audioTracks: audio.count)
    }
}
