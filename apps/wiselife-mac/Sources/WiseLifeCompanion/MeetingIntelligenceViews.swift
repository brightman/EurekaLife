import SwiftUI
import MeetingKit
import CompanionASR

struct MeetingAnalysisView: View {
    let record: MeetingRecord
    @ObservedObject var intelligence: MeetingIntelligenceModel
    @ObservedObject var speakers: MeetingSpeakerModel
    let separateSpeakers: (Bool) -> Void
    let process: (Bool) -> Void
    let seek: (Double) -> Void
    let openModels: () -> Void
    @State private var tab: String = {
        #if DEBUG
        if CommandLine.arguments.contains("--summary-tab") { return "summary" }
        #endif
        return "transcript"
    }()
    private var document: MeetingAnalysis { intelligence.analysis[record.id] ?? MeetingAnalysis() }
    private var processing: Bool { intelligence.processingID == record.id }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Text(document.state.title).font(.system(size: 12)).foregroundStyle(processing ? Theme.accent : Theme.muted)
                    .padding(.horizontal, 8).padding(.vertical, 5).background(Theme.field, in: RoundedRectangle(cornerRadius: 5))
                if processing { ProgressView(value: intelligence.progress).frame(maxWidth: 180); Button("停止整理") { intelligence.cancelProcessing() } }
                Spacer()
                if !processing {
                    if document.summary != nil { Button("重新总结") { process(true) }.disabled(intelligence.processingID != nil || speakers.busy) }
                    else { Button(document.segments.isEmpty ? "生成原文与总结" : "继续整理") { process(false) }.disabled(intelligence.processingID != nil || speakers.busy) }
                }
            }.font(.system(size: 12))
            if let failure = document.failure {
                HStack(alignment: .top) {
                    Text(failure).font(.system(size: 13)).foregroundStyle(Theme.warning).textSelection(.enabled)
                    Spacer()
                    if document.state == .waitingForModel { Button("模型库", action: openModels) }
                }
            }
            HStack(spacing: 24) {
                tabButton("原文", value: "transcript")
                tabButton("总结", value: "summary")
                Spacer()
            }.overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            if tab == "transcript" {
                if document.segments.isEmpty {
                    empty(title: processing ? "正在识别会议原文…" : "还没有会议原文", detail: "由本地 Whisper 转写，时间戳可跳转回放。")
                } else {
                    HStack { Text("\(document.segments.count) 段原文"); Spacer(); Text("Whisper \(document.asrModel?.capitalized ?? "") · 本机处理") }.font(.system(size: 12)).foregroundStyle(Theme.muted)
                    MeetingSpeakerControls(recordID: record.id, hasTranscript: true, intelligence: intelligence, speakers: speakers, start: separateSpeakers, openModels: openModels)
                    MeetingSpeakerTranscript(segments: document.segments, result: speakers.snapshot(for: record.id), seek: seek)
                }
            } else if let summary = document.summary {
                Text(document.llmModel ?? "本地 LLM").font(.system(size: 12)).foregroundStyle(Theme.muted)
                ForEach(Array(summary.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    if line.hasPrefix("#") {
                        Text(line.trimmingCharacters(in: CharacterSet(charactersIn: "# "))).font(.system(size: 17, weight: .medium)).padding(.top, 10)
                    } else { Text(.init(line)).font(.system(size: 14)).lineSpacing(7).textSelection(.enabled) }
                }
                Text("由本地模型依据原文生成，请核对关键决定与待办。结果已保存在这台 Mac。").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 12)
            } else { empty(title: processing ? "正在整理会议…" : "还没有会议总结", detail: "原文完成后使用本地 LLM 生成，重开会议不会重复生成。") }
        }
    }
    private func tabButton(_ title: String, value: String) -> some View {
        Button { tab = value } label: {
            Text(title).font(.system(size: 14, weight: tab == value ? .medium : .regular)).foregroundStyle(tab == value ? Theme.ink : Theme.muted)
                .padding(.vertical, 12).overlay(alignment: .bottom) { if tab == value { Rectangle().fill(Theme.ink).frame(height: 2) } }
        }.buttonStyle(.plain)
    }
    private func empty(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.system(size: 16, weight: .medium)); Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted) }.padding(.vertical, 24)
    }
}

struct MeetingChatPanel: View {
    @ObservedObject var intelligence: MeetingIntelligenceModel
    @ObservedObject var speakers: MeetingSpeakerModel
    let record: MeetingRecord?
    let close: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack { Image(systemName: "sparkles"); Text("Ask AI").font(.system(size: 14, weight: .medium)); Spacer(); Button(action: close) { Image(systemName: "xmark").frame(width: 28, height: 28) }.buttonStyle(.plain).help("收起 Ask AI") }.padding(.horizontal, 16).frame(height: 56)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text(record.map { "当前会议：" + $0.title } ?? "选择一场会议").font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(2)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            if let record {
                                ForEach(intelligence.analysis[record.id]?.messages ?? []) { message in
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(message.role == "user" ? "你" : "本地 AI").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted)
                                        Text(message.text).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled)
                                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(message.role == "user" ? Theme.field : .clear, in: RoundedRectangle(cornerRadius: 8)).id(message.id)
                                }
                            }
                            Color.clear.frame(height: 1).id("end")
                        }
                    }.onChange(of: record.flatMap { intelligence.analysis[$0.id]?.messages.count }) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
                }
                if let error = intelligence.chatError { Text(error).font(.system(size: 12)).foregroundStyle(Theme.warning) }
                if let record {
                    TextEditor(text: Binding(get: { intelligence.chatDrafts[record.id] ?? "" }, set: { intelligence.chatDrafts[record.id] = $0 }))
                        .font(.system(size: 13)).scrollContentBackground(.hidden).padding(8).frame(height: 88).background(Theme.card, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                        .accessibilityLabel("向 Ask AI 提问")
                    HStack {
                        Text("仅依据当前会议 · 本机处理").font(.system(size: 10)).foregroundStyle(Theme.muted)
                        Spacer()
                        if intelligence.chatPendingID != nil { Button("停止") { intelligence.cancelChat() } }
                        else { Button { intelligence.ask(id: record.id) } label: { Image(systemName: "arrow.up") }.buttonStyle(CompanionPrimaryButtonStyle()).disabled(speakers.busy || intelligence.processingID != nil || intelligence.analysis[record.id]?.segments.isEmpty != false || (intelligence.chatDrafts[record.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                    }
                } else { Text("进入会议详情后，可围绕原文或总结提问。").font(.system(size: 13)).foregroundStyle(Theme.muted) }
            }.padding(16)
        }.frame(width: 300).frame(maxHeight: .infinity).background(Theme.card)
    }
}

struct MeetingASRLibrary: View {
    @ObservedObject var intelligence: MeetingIntelligenceModel
    @ObservedObject var speakers: MeetingSpeakerModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("ASR 语音转写").font(.system(size: 20, weight: .medium)); Spacer(); Picker("会议语言", selection: $intelligence.language) { Text("自动检测").tag("auto"); Text("中文").tag("zh"); Text("English").tag("en"); Text("日本語").tag("ja") }.frame(width: 200) }
            Text("Whisper 在本机处理录制音轨。仅下载模型时联网，不上传会议音频。").font(.system(size: 13)).foregroundStyle(Theme.muted)
            if let error = intelligence.modelError { Text(error).font(.system(size: 13)).foregroundStyle(Theme.warning) }
            ForEach(MeetingASREngine.models) { item in
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text(item.name).font(.system(size: 16, weight: .medium)); Spacer(); Text(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file)).font(.system(size: 12)).foregroundStyle(Theme.muted) }
                    Text(item.id == "tiny" ? "轻量，适合快速验证" : item.id == "base" ? "速度与准确度均衡" : "更高精度，需要更多内存").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    if intelligence.downloadingSize == item.id {
                        ProgressView(value: intelligence.downloadProgress ?? 0)
                        HStack { Text("正在下载与校验").font(.system(size: 12)); Spacer(); Button("取消") { intelligence.cancelDownload() } }
                    } else if intelligence.asrInstalled.contains(item.id) {
                        Button(intelligence.asrSize == item.id ? "当前转写模型" : "用于会议转写") { intelligence.asrSize = item.id }.disabled(intelligence.asrSize == item.id || intelligence.processingID != nil || speakers.busy).buttonStyle(CompanionSecondaryButtonStyle())
                    } else { Button("下载模型") { intelligence.downloadASR(item.id) }.buttonStyle(CompanionPrimaryButtonStyle()).disabled(intelligence.downloadingSize != nil || intelligence.processingID != nil || speakers.busy) }
                }.padding(20).background(Theme.card, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
            }
        }
    }
}
