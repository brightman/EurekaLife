import SwiftUI
import AppKit

@MainActor final class CompanionDelegate: NSObject, NSApplicationDelegate {
    weak var model: CompanionModel?
    weak var meetings: MeetingModel?
    private var terminating = false
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        guard let model else { return .terminateNow }
        terminating = true
        Task { await meetings?.shutdown(); await model.shutdown(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

@main struct WiseLifeCompanionApp: App {
    @NSApplicationDelegateAdaptor(CompanionDelegate.self) private var delegate
    @StateObject private var model: CompanionModel
    @StateObject private var meetings: MeetingModel
    @Environment(\.openWindow) private var openWindow
    init() {
        #if DEBUG
        let localTest = CommandLine.arguments.contains("--meeting-local-test")
        let preview = !localTest && (CommandLine.arguments.contains("--preview") || CommandLine.arguments.contains("--snapshot") || CommandLine.arguments.contains("--meeting-test"))
        #else
        let preview = false
        let localTest = false
        #endif
        _model = StateObject(wrappedValue: CompanionModel(preview: preview, localOnly: localTest))
        _meetings = StateObject(wrappedValue: MeetingModel(isolated: preview || localTest))
    }
    var body: some Scene {
        Window("EurekaLife Mac Companion", id: "main") {
            CompanionView(model: model, meetings: meetings).task {
                delegate.model = model; delegate.meetings = meetings
                meetings.intelligence.connect(model)
                await snapshotIfRequested()
            }
        }.windowStyle(.hiddenTitleBar).defaultSize(width: 1120, height: 850)
            .commands {
                CommandGroup(replacing: .appSettings) { Button("模型库…") { show(); model.page = .models }.keyboardShortcut(",") }
                CommandMenu("本地 AI") {
                    Button("配对 iPhone…") { show(); model.openPairing() }
                    Button(model.available ? "暂停本地 AI 服务" : "开启本地 AI 服务") { model.changeAvailability(!model.available) }
                    Button("卸载模型") { model.unload() }.disabled(!model.ready)
                }
            }
        MenuBarExtra("EurekaLife 本地 AI", systemImage: "sparkles") {
            if meetings.busy {
                Button("返回会议录制") { show(); model.page = .meetings; meetings.selectedID = meetings.activeID }
                Button("结束会议录制") { Task { await meetings.stop() } }.disabled(meetings.phase != .recording)
                Divider()
            }
            Text(model.state.title)
            Text(model.serviceMessage)
            Divider()
            Button("打开 EurekaLife Mac Companion") { show() }
            Button("配对 iPhone…") { show(); model.openPairing() }
            Button(model.available ? "暂停本地 AI 服务" : "开启本地 AI 服务") { model.changeAvailability(!model.available) }
            Button("卸载模型") { model.unload() }.disabled(!model.ready)
            Divider()
            Button("退出 EurekaLife Mac Companion") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
    private func show() { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
    @MainActor private func snapshotIfRequested() async {
        #if DEBUG
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--page"), arguments.count > index + 1,
           let page = CompanionModel.Page.allCases.first(where: { $0.rawValue == arguments[index + 1] }) { model.page = page }
        if let index = arguments.firstIndex(of: "--meeting"), arguments.count > index + 1,
           let id = UUID(uuidString: arguments[index + 1]) { model.page = .meetings; meetings.selectedID = id }
        if arguments.contains("--meeting-local-test") {
            for _ in 0..<100 where !model.initialized || !meetings.loaded { try? await Task.sleep(for: .milliseconds(100)) }
            if arguments.contains("--download-speaker-models") {
                meetings.intelligence.speakers.download()
                while meetings.intelligence.speakers.downloadProgress != nil { try? await Task.sleep(for: .milliseconds(200)) }
                print("SPEAKER_MODELS_INSTALLED \(meetings.intelligence.speakers.installed) \(meetings.intelligence.speakers.error ?? "")")
            }
            if arguments.contains("--separate-speakers"), let record = meetings.selected, let store = meetings.store {
                meetings.intelligence.separateSpeakers(record, url: await store.mediaURL(for: record), force: arguments.contains("--reprocess-speakers"))
                while meetings.intelligence.speakers.processingID != nil { try? await Task.sleep(for: .milliseconds(200)) }
                let document = meetings.intelligence.speakers.documents[record.id]
                print("SPEAKER_ANALYSIS_RESULT \(document?.state.rawValue ?? "missing") ASSIGNED \(document?.result?.assignments.count ?? 0) \(document?.failure ?? "")")
            }
            if let index = arguments.firstIndex(of: "--rename-speaker"), arguments.count > index + 2,
               let record = meetings.selected, let result = meetings.intelligence.speakers.snapshot(for: record.id) {
                let saved = await meetings.intelligence.speakers.rename(id: record.id, speakerID: arguments[index + 1], name: arguments[index + 2], revision: result.revision)
                print("SPEAKER_RENAME_SAVED \(saved)")
            }
        }
        if arguments.contains("--meeting-local-test"), arguments.contains("--process-meeting") {
            for _ in 0..<100 where !model.initialized || !meetings.loaded { try? await Task.sleep(for: .milliseconds(100)) }
            await meetings.intelligence.refreshASR()
            if let record = meetings.selected, let store = meetings.store {
                meetings.intelligence.enqueue(record, url: await store.mediaURL(for: record), summaryOnly: arguments.contains("--regenerate-summary"))
                while meetings.intelligence.processingID != nil { try? await Task.sleep(for: .milliseconds(200)) }
                if let index = arguments.firstIndex(of: "--ask-meeting"), arguments.count > index + 1 {
                    meetings.intelligence.chatDrafts[record.id] = arguments[index + 1]
                    meetings.intelligence.ask(id: record.id)
                    while meetings.intelligence.chatPendingID != nil { try? await Task.sleep(for: .milliseconds(200)) }
                    print("MEETING_CHAT_RESULT \(meetings.intelligence.chatError ?? "ok")")
                }
                print("MEETING_ANALYSIS_RESULT \(meetings.intelligence.analysis[record.id]?.state.rawValue ?? "missing")")
            }
        }
        guard let index = arguments.firstIndex(of: "--snapshot"), arguments.count > index + 1 else { return }
        try? await Task.sleep(for: .seconds(1))
        guard let window = NSApp.windows.first(where: { $0.contentView != nil && $0.title == "EurekaLife Mac Companion" }),
              let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        if let data = bitmap.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: arguments[index + 1])) }
        // Snapshot runs own isolated meeting data; avoid terminateLater nesting in a SwiftUI task.
        await meetings.shutdown(); await model.shutdown()
        exit(0)
        #endif
    }
}
