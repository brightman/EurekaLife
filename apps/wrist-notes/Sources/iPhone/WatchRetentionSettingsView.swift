import SwiftUI

struct WatchRetentionSettingsView: View {
    @ObservedObject var model: NotesModel
    @State private var selectedDays = 7
    @State private var confirmation: Confirmation?
    @State private var errorMessage: String?
    private struct Confirmation: Identifiable {
        let id = UUID()
        let deviceID: UUID
        let days: Int
        let estimate: WatchRetentionEstimate
    }
    private var status: PhoneWatchStatus { model.watchStatus }
    private var report: WatchRetentionReport? { status.retentionReport }
    private var desired: WatchRetentionPolicy? { status.requestedRetention ?? report?.policy }
    private var pending: Bool { status.requestedRetention != nil && status.requestedRetention != report?.policy }
    private var canSave: Bool {
        status.hasPairedWatch && status.isInstalled && report != nil &&
        (desired == nil || desired?.days != selectedDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("已同步录音保留时间").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(desired != nil && desired?.days != selectedDays ? "未保存" : pending ? "待同步到手表" : report?.policy == nil ? "未开启" : "已生效")
                    .font(.system(size: 11)).foregroundStyle(pending ? DaybookStyle.accent : DaybookStyle.secondary)
                    .accessibilityIdentifier("watch-retention-status")
            }
            Picker("已同步录音保留时间", selection: $selectedDays) {
                Text("7 天").tag(7)
                Text("14 天").tag(14)
            }.pickerStyle(.segmented).accessibilityIdentifier("watch-retention-days")
            Text("从手表收到 iPhone 的保存确认起算。到期仅清理手表副本，iPhone 中的录音和记录不受影响。未同步录音会自动保留。")
                .font(.system(size: 11)).foregroundStyle(DaybookStyle.secondary).lineSpacing(4)
            if let report {
                let estimate = report.estimate(days: selectedDays)
                Text("预计清理 \(estimate.count) 个文件，释放 \(ByteCountFormatter.string(fromByteCount: estimate.bytes, countStyle: .file))")
                    .font(.system(size: 12)).accessibilityIdentifier("watch-retention-estimate")
                if let date = status.reportedAt {
                    Text("手表统计于 \(date.formatted(date: .abbreviated, time: .shortened))，执行时会重新检查。")
                        .font(.system(size: 10)).foregroundStyle(DaybookStyle.secondary)
                }
                if report.awaitingReceiptCount > 0 {
                    Text("\(report.awaitingReceiptCount) 个文件待确认保存，会继续保留。")
                        .font(.system(size: 11)).foregroundStyle(DaybookStyle.secondary)
                }
                if report.cleanupFailed {
                    Text("手表清理未完成，将在下次运行时重试。")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                }
            } else {
                Text("请更新并打开手表上的 EurekaLife，等待手表返回存储统计后设置。")
                    .font(.system(size: 11)).foregroundStyle(DaybookStyle.secondary)
            }
            if let errorMessage { Text(errorMessage).font(.system(size: 11)).foregroundStyle(.red) }
            Button {
                guard let report else { return }
                confirmation = Confirmation(deviceID: report.deviceID, days: selectedDays,
                                            estimate: report.estimate(days: selectedDays))
            } label: {
                Text(desired == nil ? "开启自动清理" : "保存保留时间").frame(maxWidth: .infinity)
            }.buttonStyle(.bordered).disabled(!canSave).accessibilityIdentifier("watch-retention-save")
            Text("手表在下次运行时应用设置并检查到期文件，后台清理时间由系统安排。")
                .font(.system(size: 10)).foregroundStyle(DaybookStyle.secondary)
        }
        .padding(16).background(DaybookStyle.white, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(DaybookStyle.line)).padding(.top, 16)
        .onAppear { selectedDays = desired?.days ?? 7 }
        .onChange(of: desired?.id) { _, _ in selectedDays = desired?.days ?? 7 }
        .alert("确认手表录音保留时间", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), presenting: confirmation) { value in
            Button("取消", role: .cancel) { confirmation = nil }
            Button("确认并同步") {
                do {
                    try model.setWatchRetention(days: value.days, expectedDeviceID: value.deviceID)
                    errorMessage = nil
                } catch { errorMessage = error.localizedDescription }
                confirmation = nil
            }
        } message: { value in
            Text("已保存到 iPhone 的录音，在手表上保留 \(value.days) 天。按最近统计，预计清理 \(value.estimate.count) 个文件，释放 \(ByteCountFormatter.string(fromByteCount: value.estimate.bytes, countStyle: .file))。未同步录音会保留，iPhone 数据不受影响。")
        }
    }
}
