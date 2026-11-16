import SwiftUI
import AVKit
import MeetingKit

struct MeetingView: View {
    @ObservedObject var model: MeetingModel
    @ObservedObject var intelligence: MeetingIntelligenceModel
    var openModels: () -> Void
    @State private var seekTime: Double = 0
    @State private var seekRequest = UUID()
    @State private var confirmStop = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 13)).foregroundStyle(Theme.warning)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Theme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            if let notice = model.notice { Text(notice).font(.system(size: 13)).foregroundStyle(Theme.green) }
            if let record = model.selected { detail(record) } else { library }
        }
        .sheet(isPresented: $model.showSetup) { settings }
        .alert("结束这场会议？", isPresented: $confirmStop) {
            Button("继续会议", role: .cancel) { }
            Button("结束并保存") { Task { await model.stop() } }
        } message: { Text("停止采集后完成文件写入，再进入可回放状态。") }
    }
    private var library: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("专注讨论，留住每个好想法。").font(.system(size: 24, weight: .medium))
            Text("录制保存在这台 Mac，结束后可随时回放。").font(.system(size: 14)).foregroundStyle(Theme.muted)
            HStack(spacing: 16) {
                entry("即时录音", subtitle: "用麦克风记录当下", icon: "mic") { model.prepare(quick: true) }
                entry("录制会议", subtitle: "先设置，再选择屏幕或窗口", icon: "rectangle.on.rectangle") { model.prepare() }
                VStack(alignment: .leading, spacing: 12) { Image(systemName: "square.and.arrow.up").font(.title2); Text("上传文件").font(.headline); Text("暂未开放").font(.caption).foregroundStyle(Theme.muted) }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(22).background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            if model.busy {
                HStack { ProgressView().controlSize(.small); Text(phaseText).font(.system(size: 13)); Spacer(); if let id = model.activeID { Button("返回录制") { model.selectedID = id } } }
            }
            HStack { Text("我的会议").font(.system(size: 19, weight: .semibold)); Spacer(); TextField("搜索会议", text: $model.query).textFieldStyle(.roundedBorder).frame(width: 240) }
            if model.records.isEmpty { Text(model.loaded ? "还没有会议。点击录制会议，开始第一场录制。" : "正在读取本地会议…").foregroundStyle(Theme.muted).padding(.vertical, 36) }
            ForEach(model.records.filter { model.query.isEmpty || $0.title.localizedCaseInsensitiveContains(model.query) }) { record in
                Button { model.selectedID = record.id } label: {
                    HStack(spacing: 16) {
                        Image(systemName: record.options.mode == .screen ? "video" : "waveform").font(.title3).frame(width: 26)
                        VStack(alignment: .leading, spacing: 6) { Text(record.title).font(.system(size: 15, weight: .medium)); Text(record.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundStyle(Theme.muted) }
                        Spacer(); Text(duration(record.duration)).font(.system(size: 13)).monospacedDigit(); status(record)
                    }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
        }
    }
    private func entry(_ title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(alignment: .leading, spacing: 12) { Image(systemName: icon).font(.title2); Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(Theme.muted) }.frame(maxWidth: .infinity, alignment: .leading).padding(22).background(.white, in: RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain).disabled(!model.loaded || (model.busy && model.activeID == nil))
    }
    private func detail(_ record: MeetingRecord) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Button { model.selectedID = nil } label: { Label("我的会议", systemImage: "chevron.left") }.buttonStyle(.plain).foregroundStyle(Theme.accent)
            HStack { Text(record.title).font(.system(size: 24, weight: .medium)); Spacer(); status(record) }
            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened) + " · " + record.source).font(.system(size: 13)).foregroundStyle(Theme.muted)
            if record.id == model.activeID {
                VStack(spacing: 18) {
                    Image(systemName: record.options.mode == .screen ? "record.circle" : "waveform").font(.system(size: 44)).foregroundStyle(Theme.accent)
                    Text(phaseText).font(.system(size: 20, weight: .medium))
                    TimelineView(.periodic(from: .now, by: 1)) { context in Text(duration(model.startedAt.map { max(0, context.date.timeIntervalSince($0)) } ?? 0)).font(.system(size: 34, design: .monospaced)) }
                    Text("切换页面或关闭主窗口后仍会录制。请使用结束录制按钮停止。").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    Button("结束录制") { confirmStop = true }.buttonStyle(CompanionPrimaryButtonStyle()).disabled(model.phase != .recording)
                }.frame(maxWidth: .infinity).padding(44).background(.white, in: RoundedRectangle(cornerRadius: 8))
            } else if record.state == .saved, let store = model.store {
                MeetingPlayback(record: record, store: store, seekTime: seekTime, seekRequest: seekRequest).id(record.id)
                HStack { Label(duration(record.duration), systemImage: "clock"); Text(ByteCountFormatter.string(fromByteCount: record.bytes, countStyle: .file)); Spacer(); Button("在 Finder 中显示") { Task { await model.reveal(record) } } }.font(.system(size: 13)).foregroundStyle(Theme.muted)
            } else {
                Text(record.failure ?? "录制未完成，文件已保留。").foregroundStyle(Theme.warning)
                HStack { Button("尝试恢复回放") { Task { await model.recover(record) } }.disabled(model.busy); Button("查看本地文件") { Task { await model.reveal(record) } } }
            }
            if record.state == .saved && record.id != model.activeID {
                MeetingAnalysisView(record: record, intelligence: intelligence, speakers: intelligence.speakers, separateSpeakers: { model.separateSpeakers(record, force: $0) },
                    process: { model.process(record, summaryOnly: $0) },
                    seek: { seekTime = $0; seekRequest = UUID() }, openModels: openModels)
            }
            HStack(spacing: 18) { Label(record.options.systemAudio ? "系统声音开启" : "系统声音关闭", systemImage: "speaker.wave.2"); Label(record.options.microphone ? "麦克风开启" : "麦克风关闭", systemImage: "mic") }.font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("录制一场会议").font(.system(size: 22, weight: .semibold))
            Text(model.options.mode == .audio ? "仅录音：完成设置后直接开始，无需选择画面。" : "第 1 步 / 录制设置 · 下一步使用 macOS 选择屏幕或应用窗口。").font(.system(size: 13)).foregroundStyle(Theme.muted)
            if let error = model.error { Text(error).font(.system(size: 12)).foregroundStyle(Theme.warning) }
            TextField("会议名称", text: $model.title).textFieldStyle(.roundedBorder).accessibilityIdentifier("meeting-title")
            Picker("录制方式", selection: $model.options.mode) { Text("仅录音").tag(MeetingMode.audio); Text("屏幕与音频").tag(MeetingMode.screen) }.pickerStyle(.segmented)
            Toggle("系统声音", isOn: $model.options.systemAudio)
            Text("录制应用播放的声音，EurekaLife 自身的回放声音不采集。").font(.system(size: 12)).foregroundStyle(Theme.muted)
            Toggle("我的麦克风", isOn: $model.options.microphone)
            Text("录制前请告知参会人。文件仅保存在本机，不自动上传。系统首次可能请求麦克风或屏幕与系统音频权限。").font(.system(size: 12)).foregroundStyle(Theme.muted)
            if !model.options.microphone && !model.options.systemAudio { Text("至少开启一个音源。").foregroundStyle(Theme.warning).font(.system(size: 12)) }
            HStack { Button("取消") { model.showSetup = false }.keyboardShortcut(.cancelAction); Spacer(); if model.busy { ProgressView().controlSize(.small) }; Button(model.options.mode == .screen ? "下一步：选择画面" : "开始录制") { model.begin() }.buttonStyle(CompanionPrimaryButtonStyle()).disabled(!model.canStart) }
        }.padding(30).frame(width: 530).interactiveDismissDisabled(model.busy)
    }
    private var phaseText: String { switch model.phase { case .idle: "已停止"; case .choosing: "请选择录制画面"; case .starting: "正在启动录制…"; case .recording: "录制中"; case .stopping: "正在完成文件写入…" } }
    private func status(_ record: MeetingRecord) -> some View {
        let text: String
        if record.id == model.activeID { text = phaseText } else { text = switch record.state { case .saved: "已保存"; case .interrupted: "待恢复"; case .failed: "录制失败"; case .recording: "录制中"; case .finalizing: "保存中" } }
        return Text(text).font(.system(size: 12)).foregroundStyle(record.state == .saved ? Theme.green : Theme.muted).padding(.horizontal, 8).padding(.vertical, 5).background((record.state == .saved ? Theme.green : Theme.muted).opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
    }
    private func duration(_ value: Double) -> String { let seconds = max(0, Int(value)); return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
}

private struct MeetingPlayback: View {
    let record: MeetingRecord
    let store: MeetingStore
    let seekTime: Double
    let seekRequest: UUID
    @State private var player: AVPlayer?
    var body: some View {
        VideoPlayer(player: player).frame(minHeight: record.options.mode == .screen ? 340 : 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .task { player = AVPlayer(url: await store.mediaURL(for: record)) }
            .onChange(of: seekRequest) { _, _ in player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero); player?.play() }
            .onDisappear { player?.pause(); player = nil }
    }
}
