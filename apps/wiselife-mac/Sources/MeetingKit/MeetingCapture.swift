import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreGraphics

@MainActor public final class MeetingCapture: NSObject, SCStreamDelegate, SCRecordingOutputDelegate, AVAudioRecorderDelegate {
    public var onInterruption: ((String) -> Void)?
    private var stream: SCStream?
    private var recording: SCRecordingOutput?
    private var audio: MeetingAudioOutput?
    private var microphone: AVAudioRecorder?
    private var started = false
    private var finished = false
    private var stopping = false
    private var reportedInterruption = false
    private var failure: Error?
    private var outputURL: URL?

    public static func authorizeMicrophone(_ enabled: Bool) async throws {
        guard enabled else { return }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw MeetingFailure.message("麦克风未授权。请在系统设置 → 隐私与安全性 → 麦克风中允许 EurekaLife，或关闭麦克风后重试。")
        }
    }
    public func start(options: MeetingOptions, filter selectedFilter: SCContentFilter?, url: URL) async throws {
        guard stream == nil, microphone == nil else { throw MeetingFailure.message("已有录制正在进行。") }
        guard options.microphone || options.systemAudio else { throw MeetingFailure.message("请至少选择一个音源。") }
        started = false; finished = false; stopping = false; reportedInterruption = false; failure = nil
        outputURL = url
        if options.mode == .audio && !options.systemAudio {
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128000])
            recorder.delegate = self
            guard recorder.record() else { throw MeetingFailure.message("无法开始麦克风录音，请检查输入设备。") }
            microphone = recorder; started = true; return
        }
        let filter: SCContentFilter
        if options.mode == .screen {
            guard let selectedFilter else { throw MeetingFailure.message("请先选择录制画面。") }
            filter = selectedFilter
        } else {
            // Audio-only has no screen selection step and never registers screen output.
            // macOS may still require screen/system-audio permission for SCStream audio.
            let content: SCShareableContent
            do { content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) }
            catch { throw MeetingFailure.message("系统声音访问被拒绝或不可用。请在系统设置 → 隐私与安全性 → 屏幕与系统音频录制中允许 EurekaLife。\n\(error.localizedDescription)") }
            guard let display = content.displays.first else { throw MeetingFailure.message("未找到可用显示设备，无法采集系统声音。") }
            filter = SCContentFilter(display: display, excludingWindows: [])
        }
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = options.systemAudio
        configuration.captureMicrophone = options.microphone
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48000; configuration.channelCount = 2
        configuration.showsCursor = true
        let dimensions = CaptureGeometry.dimensions(width: filter.contentRect.width * Double(filter.pointPixelScale), height: filter.contentRect.height * Double(filter.pointPixelScale))
        configuration.width = options.mode == .screen ? dimensions.width : 2
        configuration.height = options.mode == .screen ? dimensions.height : 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: options.mode == .screen ? 30 : 1)
        configuration.queueDepth = 5
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        self.stream = stream
        if options.mode == .screen {
            let config = SCRecordingOutputConfiguration()
            config.outputURL = url; config.videoCodecType = .h264; config.outputFileType = .mp4
            let output = SCRecordingOutput(configuration: config, delegate: self)
            recording = output
            try stream.addRecordingOutput(output)
        } else {
            let output = MeetingAudioOutput(directory: url.deletingLastPathComponent()) { [weak self] message in
                Task { @MainActor in self?.interrupt(message) }
            }
            audio = output
            if options.systemAudio { try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: output.queue) }
            if options.microphone { try stream.addStreamOutput(output, type: .microphone, sampleHandlerQueue: output.queue) }
        }
        try await stream.startCapture()
        if options.mode == .audio { started = true; return }
        for _ in 0..<100 {
            if let failure { throw failure }
            if started { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw MeetingFailure.message("录制启动超时。请重新选择窗口，并检查屏幕录制权限。")
    }
    public func stop() async throws {
        stopping = true
        guard stream != nil || microphone != nil else { return }
        if let microphone { microphone.stop(); self.microphone = nil; finished = true; return }
        if let stream { do { try await stream.stopCapture() } catch { if !finished && failure == nil { failure = error } } }
        if let audio, let outputURL { try await audio.finish(to: outputURL); self.audio = nil; self.stream = nil; return }
        for _ in 0..<150 {
            if finished { self.stream = nil; return }
            if let failure { throw failure }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw MeetingFailure.message("录制文件尚未完成写入，原始文件已保留。稍后可尝试恢复回放。")
    }
    private func interrupt(_ text: String) {
        guard !stopping, !reportedInterruption else { return }
        reportedInterruption = true; onInterruption?(text)
    }
    nonisolated public func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in self.interrupt("录制被系统中断：\(error.localizedDescription)") }
    }
    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in self.interrupt(flag ? "麦克风录音已结束。" : "麦克风录音被中断，原始文件已保留。") }
    }
    nonisolated public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let message = error?.localizedDescription ?? "音频编码失败"
        Task { @MainActor in self.interrupt("麦克风录音失败：\(message)") }
    }
    nonisolated public func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.started = true }
    }
    nonisolated public func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.finished = true; self.interrupt("系统已结束屏幕共享，已停止录制。") }
    }
    nonisolated public func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in self.failure = error; self.interrupt("录制文件写入失败：\(error.localizedDescription)") }
    }
}
