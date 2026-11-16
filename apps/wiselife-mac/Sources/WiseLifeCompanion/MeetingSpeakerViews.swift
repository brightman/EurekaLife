import SwiftUI
import MeetingKit
import CompanionSpeakers

struct MeetingSpeakerControls: View {
    let recordID: UUID
    let hasTranscript: Bool
    @ObservedObject var intelligence: MeetingIntelligenceModel
    @ObservedObject var speakers: MeetingSpeakerModel
    let start: (Bool) -> Void
    let openModels: () -> Void
    @State private var editing: SpeakerNameEdit?
    private var document: MeetingSpeakerDocument? { speakers.documents[recordID] }
    private var result: MeetingSpeakerSnapshot? { speakers.snapshot(for: recordID) }
    private var active: Bool { speakers.processingID == recordID }
    private var blocked: Bool { speakers.busy || intelligence.processingID != nil || intelligence.chatPendingID != nil || intelligence.downloadingSize != nil }
    private var title: String {
        if active { return "正在区分说话人" }
        if speakers.sourceChanged(recordID) { return "原文或录制已变化" }
        switch document?.state ?? .idle {
        case .ready: return "说话人已分析"
        case .interrupted: return "说话人分析已暂停"
        case .failed: return "说话人分析未完成"
        case .waitingForModel: return "等待说话人模型"
        default: return "说话人"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.wave.2").foregroundStyle(Theme.muted)
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                if active {
                    Text("\(Int(speakers.progress * 100))%").font(.system(size: 12)).monospacedDigit().foregroundStyle(Theme.muted)
                    Button("停止") {
                        if intelligence.processingID == recordID { intelligence.cancelProcessing() } else { speakers.cancel() }
                    }
                } else if !speakers.installed {
                    Button("下载模型", action: openModels)
                } else {
                    Button(document?.checkpoint == nil ? (result == nil ? "区分说话人" : "重新分析") : "继续分析") { start(result != nil && document?.checkpoint == nil) }
                        .disabled(!hasTranscript || blocked)
                }
            }
            if active { ProgressView(value: speakers.progress) }
            if let failure = document?.failure { Text(failure).font(.system(size: 12)).foregroundStyle(Theme.warning).textSelection(.enabled) }
            if let error = speakers.error { Text(error).font(.system(size: 12)).foregroundStyle(Theme.warning).textSelection(.enabled) }
            if speakers.sourceChanged(recordID) { Text("已有标签暂不应用到新的原文，请重新分析。").font(.system(size: 12)).foregroundStyle(Theme.muted) }
            if let result {
                let total = intelligence.analysis[recordID]?.segments.count ?? 0
                Text("已标注 \(result.assignments.count) / \(total) 段 · \(max(0, total - result.assignments.count)) 段未确定")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                Text("自动标签需回放核对；不同编号不代表已确认的联系人。").font(.system(size: 12)).foregroundStyle(Theme.muted)
                let identifiers = Array(Set(result.assignments.values)).sorted { speakerNumber($0) < speakerNumber($1) }
                if identifiers.isEmpty { Text("暂时无法可靠归属发言，原文标记为未确定。").font(.system(size: 12)).foregroundStyle(Theme.muted) }
                else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: 8) {
                        ForEach(identifiers, id: \.self) { id in
                            Button { editing = .init(id: id, revision: result.revision, name: result.names[id] ?? "") } label: {
                                HStack(spacing: 6) { Circle().fill(speakerColor(id)).frame(width: 6, height: 6); Text(result.displayName(id)).lineLimit(1); Image(systemName: "pencil").font(.system(size: 10)).foregroundStyle(Theme.muted) }
                                    .font(.system(size: 12)).padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain).disabled(blocked).help("重命名当前会议的说话人")
                        }
                    }
                }
                if !result.previousNames.isEmpty {
                    Text("上次名称（需重新确认）：" + result.previousNames.joined(separator: "、")).font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            } else if !active { Text("仅区分当前会议中的发言者；已有原文无需重新转写。").font(.system(size: 12)).foregroundStyle(Theme.muted) }
        }.padding(14).background(Theme.field.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .sheet(item: $editing) { edit in
            SpeakerNameSheet(initial: edit.name, fallback: "说话人\(speakerNumber(edit.id))") { name in
                await speakers.rename(id: recordID, speakerID: edit.id, name: name, revision: edit.revision)
            }
        }
    }
}
private struct SpeakerNameEdit: Identifiable { let id: String; let revision: UUID; let name: String }
private struct SpeakerNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var saving = false
    @State private var saveFailed = false
    let fallback: String
    let save: (String) async -> Bool
    init(initial: String, fallback: String, save: @escaping (String) async -> Bool) {
        _name = State(initialValue: initial); self.fallback = fallback; self.save = save
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("重命名说话人").font(.system(size: 20, weight: .medium))
            TextField(fallback, text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("说话人名称")
            Text("只用于当前会议，留空恢复默认名称。最多60个字。").font(.system(size: 12)).foregroundStyle(Theme.muted)
            if saveFailed { Text("名称未保存，结果可能已变化。请关闭后查看错误并重试。").font(.system(size: 12)).foregroundStyle(Theme.warning) }
            HStack { Spacer(); Button("取消") { dismiss() }.disabled(saving); Button("保存") { saving = true; saveFailed = false; Task { if await save(name) { dismiss() } else { saveFailed = true }; saving = false } }.disabled(saving || name.count > 60).keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 360)
    }
}

struct MeetingSpeakerTranscript: View {
    let segments: [MeetingTranscriptSegment]
    let result: MeetingSpeakerSnapshot?
    let seek: (Double) -> Void
    private struct Row: Identifiable { let id: String; var start: Double; var end: Double; var text: String; var speaker: String? }
    private var rows: [Row] {
        var rows: [Row] = []
        for segment in segments {
            let speaker = result?.assignments[segment.id]
            if let last = rows.last, speaker != nil, last.speaker == speaker,
               segment.start >= last.start, segment.start - last.end <= 1,
               segment.end - last.start <= 30, last.text.count + segment.text.count <= 400 {
                rows[rows.count - 1].end = max(last.end, segment.end)
                rows[rows.count - 1].text += "\n" + segment.text
            } else { rows.append(.init(id: segment.id, start: segment.start, end: segment.end, text: segment.text, speaker: speaker)) }
        }
        return rows
    }
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        if let result {
                            Circle().fill(row.speaker.map(speakerColor) ?? Theme.muted).frame(width: 6, height: 6)
                            Text(row.speaker.map { result.displayName($0) } ?? "未确定").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                        }
                        Button { seek(row.start) } label: { Text(MeetingAnalysis.timestamp(row.start)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.accent) }.buttonStyle(.plain)
                    }
                    Text(row.text).font(.system(size: 14)).lineSpacing(7).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.vertical, 14)
            }
        }
    }
}
private func speakerNumber(_ id: String) -> Int { Int(id.split(separator: "-").last ?? "") ?? 0 }
private func speakerColor(_ id: String) -> Color {
    let colors: [Color] = [.blue, .purple, .teal, .orange, .indigo, .brown]
    return colors[max(0, speakerNumber(id) - 1) % colors.count].opacity(0.75)
}

struct MeetingSpeakerLibrary: View {
    @ObservedObject var speakers: MeetingSpeakerModel
    @ObservedObject var intelligence: MeetingIntelligenceModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("说话人分离").font(.system(size: 20, weight: .medium))
            HStack { Text("Pyannote + WeSpeaker").font(.system(size: 16, weight: .medium)); Spacer(); Text(ByteCountFormatter.string(fromByteCount: MeetingSpeakerEngine.modelBytes, countStyle: .file)).font(.system(size: 12)).foregroundStyle(Theme.muted) }
            Text("在这台 Mac 上区分同一场会议里的发言者。仅下载模型时联网，不上传录音。").font(.system(size: 13)).foregroundStyle(Theme.muted)
            if let error = speakers.error { Text(error).font(.system(size: 12)).foregroundStyle(Theme.warning) }
            if let progress = speakers.downloadProgress {
                ProgressView(value: progress)
                HStack { Text("正在下载与校验").font(.system(size: 12)); Spacer(); Button("取消") { speakers.cancelDownload() } }
            } else if speakers.installed {
                Label("本地模型已就绪", systemImage: "checkmark.circle").font(.system(size: 13)).foregroundStyle(Theme.muted)
            } else {
                Button("下载说话人模型") { speakers.download() }.buttonStyle(CompanionPrimaryButtonStyle())
                    .disabled(speakers.busy || intelligence.processingID != nil || intelligence.chatPendingID != nil || intelligence.downloadingSize != nil)
            }
        }.padding(20).background(Theme.card, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
    }
}
