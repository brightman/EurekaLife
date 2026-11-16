import AppKit
import AVFoundation
import Combine
import MeetingKit

@MainActor final class MeetingModel: ObservableObject {
    enum Phase: String { case idle, choosing, starting, recording, stopping }
    @Published var records: [MeetingRecord] = []
    @Published var selectedID: UUID?
    @Published var phase: Phase = .idle
    @Published var showSetup = false
    @Published var title = ""
    @Published var options = MeetingOptions()
    @Published var error: String?
    @Published var notice: String?
    @Published var query = ""
    @Published var activeID: UUID?
    @Published var startedAt: Date?
    @Published var loaded = false
    let intelligence: MeetingIntelligenceModel
    private(set) var store: MeetingStore?
    private let picker = MeetingPicker()
    private var capture: MeetingCapture?
    private var operation: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    private var sleepObserver: NSObjectProtocol?
    var selected: MeetingRecord? { records.first { $0.id == selectedID } }
    var active: MeetingRecord? { records.first { $0.id == activeID } }
    var busy: Bool { phase != .idle }
    var canStart: Bool { loaded && !busy && (options.microphone || options.systemAudio) }
    init(isolated: Bool = false) {
        let root: URL
        if isolated { root = FileManager.default.temporaryDirectory.appendingPathComponent("EurekaLifeMeetingAcceptance", isDirectory: true) }
        else { root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WiseLifeMacCompanion/Meetings", isDirectory: true) }
        intelligence = MeetingIntelligenceModel(root: root)
        do { store = try MeetingStore(root: root) } catch { self.error = "会议目录无法创建：\(error.localizedDescription)" }
        Task { await reload(recover: true); loaded = store != nil }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.stop(reason: "Mac 即将休眠，录制已停止。") }
        }
    }
    func reload(recover: Bool = false) async {
        guard let store else { return }
        do { records = try await store.load(recoverInterrupted: recover); await intelligence.load(records, mediaStore: store, recover: recover) }
        catch { self.error = "会议记录读取失败：\(error.localizedDescription)" }
    }
    func prepare(quick: Bool = false) {
        if let activeID { selectedID = activeID; return }
        guard !busy else { return }
        if quick { options.mode = .audio; options.microphone = true; options.systemAudio = false }
        showSetup = true; error = nil
    }
    func begin() {
        guard canStart, let store else { return }
        let chosenOptions = options, chosenTitle = title
        phase = .starting; error = nil; notice = nil
        operation = Task { [self] in
            var created: MeetingRecord?
            do {
                try await MeetingCapture.authorizeMicrophone(chosenOptions.microphone)
                try Task.checkCancellation()
                var record = MeetingRecord(title: chosenTitle, options: chosenOptions)
                let filter: ScreenCaptureKit.SCContentFilter?
                if chosenOptions.mode == .screen {
                    showSetup = false; phase = .choosing
                    filter = try await picker.choose()
                    try Task.checkCancellation()
                    guard let filter else { phase = .idle; showSetup = true; return }
                    record.source = filter.style == .display ? "Entire Screen · 整个屏幕" : "Application Window · 应用窗口"
                } else { filter = nil; showSetup = false; record.source = chosenOptions.systemAudio ? "系统声音" + (chosenOptions.microphone ? " + 麦克风" : "") : "麦克风" }
                phase = .starting
                try await store.save(record); created = record
                records.insert(record, at: 0); selectedID = record.id; activeID = record.id
                let capture = MeetingCapture(); self.capture = capture
                capture.onInterruption = { [weak self] message in Task { @MainActor in await self?.stop(reason: message) } }
                try await capture.start(options: chosenOptions, filter: filter, url: await store.mediaURL(for: record))
                try Task.checkCancellation()
                guard phase == .starting else { return }
                startedAt = Date(); phase = .recording
            } catch {
                if let capture { try? await capture.stop() }
                picker.deactivate(); capture = nil; activeID = nil; phase = .idle; startedAt = nil
                if var created {
                    created.state = .failed; created.failure = error.localizedDescription
                    do { try await store.save(created); await reload() } catch { self.error = "录制失败，且状态保存失败：\(error.localizedDescription)" }
                } else { showSetup = true }
                self.error = "无法开始录制：\(error.localizedDescription)"
            }
        }
    }
    func stop(reason: String? = nil) async {
        if let stopTask { await stopTask.value; return }
        let pending = Task { await finishRecording(reason: reason) }
        stopTask = pending
        await pending.value
        stopTask = nil
    }
    private func finishRecording(reason: String?) async {
        guard [.recording, .starting].contains(phase), var record = active, let capture, let store else { return }
        phase = .stopping; record.state = .finalizing
        do { try await store.save(record) } catch { self.error = "无法更新保存状态：\(error.localizedDescription)" }
        do {
            try await capture.stop()
            let info = try await MeetingMedia.inspect(await store.mediaURL(for: record), requireVideo: record.options.mode == .screen)
            record.state = .saved; record.duration = info.duration; record.bytes = info.bytes
            record.failure = nil
            notice = reason ?? "录制已保存到这台 Mac，可在下方回放。"
            if (record.options.microphone || record.options.systemAudio) && info.audioTracks == 0 {
                notice = "画面已保存，但未检测到音轨。请检查音源与权限后重试。"
            }
        } catch {
            record.state = .interrupted; record.failure = "\(reason.map { $0 + "\n" } ?? "")\(error.localizedDescription)"
            self.error = record.failure
        }
        do { try await store.save(record) } catch { self.error = "录制文件已保留，但会议状态未能保存：\(error.localizedDescription)" }
        self.capture = nil; picker.deactivate(); phase = .idle; activeID = nil; startedAt = nil
        await reload()
        if record.state == .saved { intelligence.enqueue(record, url: await store.mediaURL(for: record)) }
    }
    func recover(_ record: MeetingRecord) async {
        guard !busy, let store else { return }
        do {
            let info = try await MeetingMedia.inspect(await store.mediaURL(for: record), requireVideo: record.options.mode == .screen)
            var recovered = record; recovered.state = .saved; recovered.duration = info.duration; recovered.bytes = info.bytes; recovered.failure = nil
            try await store.save(recovered); await reload(); notice = "已恢复可播放的录制文件。"
        } catch { self.error = "暂时无法恢复回放，原始文件继续保留：\(error.localizedDescription)" }
    }
    func reveal(_ record: MeetingRecord) async {
        guard let store else { return }
        NSWorkspace.shared.activateFileViewerSelecting([await store.directory(for: record)])
    }
    func shutdown() async {
        if phase == .choosing { picker.dismiss() }
        if phase == .starting || phase == .choosing { operation?.cancel(); await operation?.value }
        await stop(reason: "退出应用前已停止并保存录制。")
        picker.deactivate()
        await intelligence.shutdown()
    }
    func separateSpeakers(_ record: MeetingRecord, force: Bool = false) {
        guard let store else { return }
        Task { intelligence.separateSpeakers(record, url: await store.mediaURL(for: record), force: force) }
    }
    func process(_ record: MeetingRecord, summaryOnly: Bool = false) {
        guard let store else { return }
        Task { intelligence.enqueue(record, url: await store.mediaURL(for: record), summaryOnly: summaryOnly) }
    }
}
import ScreenCaptureKit
