import XCTest
@preconcurrency import AVFoundation
@testable import MeetingKit

final class MeetingAudioReaderTests: XCTestCase {
    func testTimestampPlacementPreservesLeadingInteriorAndTrailingGaps() throws {
        var buffer = try MeetingAudioWindowBuffer(start: 10, duration: 1)
        try buffer.append([Float](repeating: 0.25, count: 4_000), presentationTime: 10.25)
        try buffer.append([Float](repeating: 0.5, count: 2_000), presentationTime: 10.75)
        XCTAssertEqual(buffer.samples.count, 16_000)
        XCTAssertTrue(buffer.samples[0..<4_000].allSatisfy { $0 == 0 })
        XCTAssertTrue(buffer.samples[4_000..<8_000].allSatisfy { $0 == 0.25 })
        XCTAssertTrue(buffer.samples[8_000..<12_000].allSatisfy { $0 == 0 })
        XCTAssertTrue(buffer.samples[12_000..<14_000].allSatisfy { $0 == 0.5 })
        XCTAssertTrue(buffer.samples[14_000..<16_000].allSatisfy { $0 == 0 })
    }

    func testFractionalShortfallAndCodecOverhangKeepRequestedLength() throws {
        var short = try MeetingAudioWindowBuffer(start: 300, duration: 2)
        try short.append([Float](repeating: 0.25, count: 31_994), presentationTime: 300)
        XCTAssertEqual(short.samples.count, 32_000)
        XCTAssertEqual(Array(short.samples.suffix(7)), [0.25, 0, 0, 0, 0, 0, 0])
        var fractional = try MeetingAudioWindowBuffer(start: 4500, duration: 30.729999999999563)
        try fractional.append([Float](repeating: 0.25, count: 491_630), presentationTime: 4500)
        XCTAssertEqual(fractional.samples.count, 491_680)
        XCTAssertTrue(fractional.samples.suffix(50).allSatisfy { $0 == 0 })
        var overhang = try MeetingAudioWindowBuffer(start: 120, duration: 60)
        try overhang.append([Float](repeating: 0.25, count: 960_006), presentationTime: 120)
        XCTAssertEqual(overhang.samples.count, 960_000)
        XCTAssertTrue(overhang.samples.allSatisfy { $0 == 0.25 })
    }

    func testInvalidTimestampsAndNonfiniteSamplesFailClosed() throws {
        var buffer = try MeetingAudioWindowBuffer(start: 0, duration: 1)
        for time in [Double.nan, .infinity, -1, 1000] {
            XCTAssertThrowsError(try buffer.append([0.1], presentationTime: time))
        }
        XCTAssertThrowsError(try buffer.append([.nan], presentationTime: 0))
        XCTAssertThrowsError(try buffer.append([.infinity], presentationTime: 0))
        XCTAssertThrowsError(try MeetingAudioWindowBuffer(start: 0, duration: 61))
    }

    func testRealDelayedAudioAndTrailingEmptyRangeRetainTimeline() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("delayed.mov")
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64_000])
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 16, AVVideoHeightKey: 16])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 16, kCVPixelBufferHeightKey as String: 16])
        writer.add(audio); writer.add(video)
        XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        for timestamp in [0.0, 1.5] {
            while !video.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var pixel: CVPixelBuffer?
            XCTAssertEqual(CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixel), kCVReturnSuccess)
            let image = try XCTUnwrap(pixel)
            CVPixelBufferLockBaseAddress(image, [])
            memset(CVPixelBufferGetBaseAddress(image)!, 0, CVPixelBufferGetBytesPerRow(image) * 16)
            CVPixelBufferUnlockBaseAddress(image, [])
            XCTAssertTrue(adaptor.append(image, withPresentationTime: CMTime(seconds: timestamp, preferredTimescale: 48_000)))
        }
        var description = AudioStreamBasicDescription(mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked, mBytesPerPacket: 4, mFramesPerPacket: 1,
            mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        var format: CMAudioFormatDescription?
        XCTAssertEqual(CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &description, layoutSize: 0,
            layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format), noErr)
        var block: CMBlockBuffer?
        XCTAssertEqual(CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: 24_000 * 4,
            blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0, dataLength: 24_000 * 4, flags: 0, blockBufferOut: &block), noErr)
        let radiansPerSample = 2.0 * Double.pi * 440.0 / 48_000.0
        let values: [Float] = (0..<24_000).map { Float(sin(Double($0) * radiansPerSample) * 0.1) }
        values.withUnsafeBytes { bytes in
            XCTAssertEqual(CMBlockBufferReplaceDataBytes(with: bytes.baseAddress!, blockBuffer: block!, offsetIntoDestination: 0, dataLength: bytes.count), noErr)
        }
        var sample: CMSampleBuffer?
        XCTAssertEqual(CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: block!,
            formatDescription: format!, sampleCount: 24_000, presentationTimeStamp: CMTime(seconds: 0.5, preferredTimescale: 48_000),
            packetDescriptions: nil, sampleBufferOut: &sample), noErr)
        while !audio.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertTrue(audio.append(try XCTUnwrap(sample)))
        audio.markAsFinished(); video.markAsFinished(); await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
        let duration = try await MeetingAudioReader.duration(destination)
        XCTAssertGreaterThan(duration, 1.4)
        let samples = try await MeetingAudioReader.samples(destination, start: 0, duration: duration)
        XCTAssertEqual(samples.count, Int(ceil(duration * 16_000)))
        XCTAssertLessThan(samples.prefix(6_400).map { abs($0) }.max() ?? 1, 0.001)
        XCTAssertGreaterThan(samples[9_600..<14_400].map { abs($0) }.max() ?? 0, 0.05)
        XCTAssertLessThan(samples.suffix(6_400).map { abs($0) }.max() ?? 1, 0.001)
        let gap = try await MeetingAudioReader.samples(destination, start: 1.1, duration: 0.3)
        XCTAssertEqual(gap.count, 4_800)
        XCTAssertTrue(gap.allSatisfy { abs($0) < 0.001 })
    }
}
