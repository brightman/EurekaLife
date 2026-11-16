import XCTest
@preconcurrency import AVFoundation
import ScreenCaptureKit
@testable import MeetingKit

final class MeetingMediaTests: XCTestCase {
    func testRealMP4HasPlayableVideoAndExtractableFrame() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("synthetic.mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 180])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180])
        writer.add(input); XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var pixel: CVPixelBuffer?
            XCTAssertEqual(CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixel), kCVReturnSuccess)
            let buffer = try XCTUnwrap(pixel)
            CVPixelBufferLockBaseAddress(buffer, [])
            let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(buffer)
            for y in 0..<180 { for x in 0..<320 { let i = y * stride + x * 4; base[i] = 35; base[i+1] = UInt8(frame * 6); base[i+2] = 180; base[i+3] = 255 } }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            XCTAssertTrue(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished(); await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
        let info = try await MeetingMedia.inspect(url, requireVideo: true)
        XCTAssertEqual(info.videoTracks, 1); XCTAssertGreaterThan(info.duration, 0.9); XCTAssertGreaterThan(info.bytes, 0)
        let asset = AVURLAsset(url: url)
        let frame = try await AVAssetImageGenerator(asset: asset).image(at: CMTime(value: 15, timescale: 30))
        XCTAssertEqual(frame.image.width, 320); XCTAssertEqual(frame.image.height, 180)
        do { _ = try await MeetingMedia.inspect(url, requireVideo: false); XCTFail("Silent video accepted as audio") } catch { }
    }
    @MainActor func testCaptureRejectsMissingScopeAndNoSourcesWithoutDeviceAccess() async throws {
        let capture = MeetingCapture()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        do { try await capture.start(options: .init(mode: .screen, microphone: false, systemAudio: false), filter: nil, url: url); XCTFail() } catch { }
        do { try await capture.start(options: .init(mode: .screen, microphone: false, systemAudio: true), filter: nil, url: url); XCTFail() } catch { }
        try await capture.stop()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    func testAudioOnlyMixProducesNoVideo() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = MeetingAudioOutput(directory: directory)
        for index in 0..<20 {
            let system = try sample(time: Double(index) * 0.02, frequency: 440)
            let microphone = try sample(time: 0.1 + Double(index) * 0.02, frequency: 660)
            output.queue.sync { output.append(system, type: .audio); output.append(microphone, type: .microphone) }
            try await Task.sleep(for: .milliseconds(20))
        }
        let url = directory.appendingPathComponent("recording.m4a")
        try await output.finish(to: url)
        let info = try await MeetingMedia.inspect(url, requireVideo: false)
        XCTAssertEqual(info.videoTracks, 0); XCTAssertGreaterThan(info.audioTracks, 0); XCTAssertGreaterThan(info.duration, 0.4)
    }
    private func sample(time: Double, frequency: Double) throws -> CMSampleBuffer {
        var description = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked, mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        var format: CMAudioFormatDescription?
        XCTAssertEqual(CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format), noErr)
        var block: CMBlockBuffer?
        XCTAssertEqual(CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: 960 * 4, blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0, dataLength: 960 * 4, flags: 0, blockBufferOut: &block), noErr)
        let values = (0..<960).map { Float(sin((time + Double($0) / 48000) * 2 * .pi * frequency) * 0.1) }
        values.withUnsafeBytes { bytes in XCTAssertEqual(CMBlockBufferReplaceDataBytes(with: bytes.baseAddress!, blockBuffer: block!, offsetIntoDestination: 0, dataLength: bytes.count), noErr) }
        var buffer: CMSampleBuffer?
        XCTAssertEqual(CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: block!, formatDescription: format!, sampleCount: 960, presentationTimeStamp: CMTime(seconds: time, preferredTimescale: 48000), packetDescriptions: nil, sampleBufferOut: &buffer), noErr)
        return try XCTUnwrap(buffer)
    }
}
