import Foundation
import AVFoundation

public enum MeetingAudioReader {
    public static func duration(_ url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let seconds = try await asset.load(.duration).seconds
        guard seconds.isFinite, seconds > 0, !(try await asset.loadTracks(withMediaType: .audio)).isEmpty else {
            throw MeetingFailure.message("录制中没有可用音轨，无法转写。")
        }
        return seconds
    }
    /// Reader materializes only the selected bounded window, including all audio tracks.
    public static func samples(_ url: URL, start: Double, duration: Double) async throws -> [Float] {
        var result = try MeetingAudioWindowBuffer(start: start, duration: duration)
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw MeetingFailure.message("录制中没有音轨。") }
        let assetDuration = try await asset.load(.duration).seconds
        guard assetDuration.isFinite, assetDuration > 0, start < assetDuration,
              start + duration <= assetDuration + 1.0 / 16_000 else {
            throw MeetingFailure.message("音频窗口超出录制时长。")
        }
        var hasRealAudioRange = false
        for track in tracks {
            let range = try await track.load(.timeRange)
            if range.start.seconds.isFinite, range.duration.seconds.isFinite, range.duration.seconds > 0 {
                hasRealAudioRange = true
            }
        }
        guard hasRealAudioRange else { throw MeetingFailure.message("录制音轨为空。") }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false])
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 16000), duration: CMTime(seconds: duration, preferredTimescale: 16000))
        guard reader.canAdd(output) else { throw MeetingFailure.message("无法读取会议音频。") }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? MeetingFailure.message("音轨读取失败。") }
        defer { reader.cancelReading() }
        let maximum = Int(ceil(duration * 16000)) + 4096
        var decodedCount = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let block = CMSampleBufferGetDataBuffer(sample) else {
                guard CMSampleBufferGetNumSamples(sample) == 0 else {
                    throw MeetingFailure.message("音频缓冲区缺少采样数据。")
                }
                continue
            }
            let length = CMBlockBufferGetDataLength(block)
            if length == 0 { continue }
            guard length % MemoryLayout<Float>.size == 0, decodedCount + length / 4 <= maximum else {
                throw MeetingFailure.message("音频解码超过窗口限制。")
            }
            var values = [Float](repeating: 0, count: length / 4)
            let status = values.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
            guard status == noErr else { throw MeetingFailure.message("音频采样读取失败。") }
            decodedCount += values.count
            try result.append(values, presentationTime: CMSampleBufferGetPresentationTimeStamp(sample).seconds)
        }
        guard reader.status == .completed else { throw reader.error ?? MeetingFailure.message("音轨未完整读取。") }
        // A valid file can have an empty audio interval or a shorter audio track
        // than its video. Keep those gaps on the media timeline as silence.
        return result.samples
    }
}

/// A fixed-size timeline, rather than concatenated packets. Decoder rounding
/// can return several samples before/after a boundary; PTS preserves the location
/// of speech while genuine leading, interior and trailing gaps remain silence.
struct MeetingAudioWindowBuffer {
    private let start: Double
    private let duration: Double
    private var previousTime: Double?
    private(set) var samples: [Float]

    init(start: Double, duration: Double) throws {
        guard start.isFinite, start >= 0, start < Double(Int64.max) / 16_000,
              duration.isFinite, duration > 0, duration <= 60 else {
            throw MeetingFailure.message("每次转写窗口必须在 0–60 秒内。")
        }
        self.start = start; self.duration = duration
        samples = [Float](repeating: 0, count: Int(ceil(duration * 16_000)))
    }

    mutating func append(_ values: [Float], presentationTime: Double) throws {
        guard presentationTime.isFinite, presentationTime >= 0,
              presentationTime >= start - 1, presentationTime <= start + duration + 1,
              previousTime.map({ presentationTime >= $0 }) ?? true,
              values.count <= samples.count + 4096, values.allSatisfy(\.isFinite) else {
            throw MeetingFailure.message("音频采样或时间戳无效。")
        }
        previousTime = presentationTime
        let offset = Int(((presentationTime - start) * 16_000).rounded())
        let destination = max(0, offset), source = max(0, -offset)
        let count = min(samples.count - destination, values.count - source)
        guard count > 0 else { return }
        samples.replaceSubrange(destination..<(destination + count), with: values[source..<(source + count)])
    }
}
