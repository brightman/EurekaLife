import Foundation
import AVFoundation
import ScreenCaptureKit

/// All writer state is confined to queue. System and microphone retain their timestamps;
/// final export mixes both audio tracks. No screen sample is registered or written.
final class MeetingAudioOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    let queue = DispatchQueue(label: "cloud.karama.meeting.audio", qos: .userInitiated)
    private struct Track { let url: URL; let writer: AVAssetWriter; let input: AVAssetWriterInput; let start: CMTime }
    private let directory: URL
    private var tracks: [Int: Track] = [:]
    private var failure: Error?
    private var finishing = false
    private let onFailure: (@Sendable (String) -> Void)?
    init(directory: URL, onFailure: (@Sendable (String) -> Void)? = nil) {
        self.directory = directory; self.onFailure = onFailure
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        append(buffer, type: type)
    }
    func append(_ buffer: CMSampleBuffer, type: SCStreamOutputType) {
        guard !finishing, failure == nil, CMSampleBufferDataIsReady(buffer),
              type == .audio || type == .microphone,
              let format = CMSampleBufferGetFormatDescription(buffer),
              let description = CMAudioFormatDescriptionGetStreamBasicDescription(format) else { return }
        do {
            let key = type.rawValue
            if tracks[key] == nil {
                let url = directory.appendingPathComponent(type == .audio ? "system-source.m4a" : "microphone-source.m4a")
                let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
                let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: description.pointee.mSampleRate, AVNumberOfChannelsKey: Int(description.pointee.mChannelsPerFrame), AVEncoderBitRateKey: 128000]
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings, sourceFormatHint: format)
                input.expectsMediaDataInRealTime = true
                guard writer.canAdd(input) else { throw MeetingFailure.message("无法创建音轨。") }
                writer.add(input)
                guard writer.startWriting() else { throw writer.error ?? MeetingFailure.message("音轨无法写入。") }
                let start = CMSampleBufferGetPresentationTimeStamp(buffer)
                writer.startSession(atSourceTime: start)
                tracks[key] = Track(url: url, writer: writer, input: input, start: start)
            }
            guard let track = tracks[key] else { return }
            guard track.input.isReadyForMoreMediaData else { throw MeetingFailure.message("音频写入跟不上采集速度，已停止并保留原始音轨。") }
            guard track.input.append(buffer) else { throw track.writer.error ?? MeetingFailure.message("音频写入失败。") }
        } catch { failure = error; onFailure?("音频录制失败：\(error.localizedDescription)") }
    }
    func finish(to destination: URL) async throws {
        let snapshot: ([Track], Error?) = await withCheckedContinuation { continuation in
            queue.async {
                self.finishing = true
                self.tracks.values.forEach { $0.input.markAsFinished() }
                continuation.resume(returning: (Array(self.tracks.values), self.failure))
            }
        }
        for track in snapshot.0 {
            await track.writer.finishWriting()
            if let error = track.writer.error { throw error }
        }
        if let error = snapshot.1 { throw error }
        guard let origin = snapshot.0.map(\.start).min(by: { CMTimeCompare($0, $1) < 0 }) else {
            throw MeetingFailure.message("未收到音频。请检查声音来源与系统权限。")
        }
        let composition = AVMutableComposition()
        for track in snapshot.0 {
            let asset = AVURLAsset(url: track.url)
            guard let source = try await asset.loadTracks(withMediaType: .audio).first,
                  let target = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
            let range = try await source.load(.timeRange)
            try target.insertTimeRange(range, of: source, at: CMTimeSubtract(track.start, origin))
        }
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else { throw MeetingFailure.message("无法合成音频，源音轨已保留。") }
        try await export.export(to: destination, as: .m4a)
    }
}
