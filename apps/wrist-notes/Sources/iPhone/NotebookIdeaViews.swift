import SwiftUI

struct NotebookAssetEditor: View {
    @ObservedObject var model: NotebookIdeasModel
    @State var item: FlashAsset
    let isNew: Bool
    var mergeSeeds:[FlashAsset]=[]
    var onSaved:()->Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var amount=""
    @State private var currency=""
    @State private var date=""
    @State private var saving=false
    @State private var error:String?
    var body: some View {
        DaybookSheetLayout(title:!mergeSeeds.isEmpty ? "合并灵感" : isNew ? (item.kind == .idea ? "新建灵感" : "记一笔") : "编辑",onClose:{ dismiss() }) {
            VStack(alignment:.leading,spacing:20) {
                DaybookSettingsField("标题") { TextField("简短标题",text:$item.title).accessibilityIdentifier("notebook.editor.title") }
                DaybookSettingsField("内容") { TextField(item.kind == .idea ? "写下你的想法" : "这笔收支的用途或备注",text:$item.text,axis:.vertical).lineLimit(4...12).accessibilityIdentifier("notebook.editor.text") }
                if !mergeSeeds.isEmpty {
                    Text("合并结果另存为新灵感；原条目和来源会保留。无需调用 AI。").font(.system(size:13)).foregroundStyle(DaybookStyle.secondary)
                    ForEach(mergeSeeds) { seed in DisclosureGroup(seed.title) { Text(seed.text).font(.system(size:14)) } }
                    Text("\(item.text.count) / 4000 字").font(.system(size:12)).foregroundStyle(item.text.count > 4000 ? DaybookStyle.red : DaybookStyle.secondary)
                }
                if item.kind == .expense {
                    DaybookSettingsField("收支") { Picker("收支",selection:$item.direction) {
                        Text("待补充").tag(Optional<FlashAsset.Direction>.none); Text("支出").tag(Optional(FlashAsset.Direction.expense)); Text("收入").tag(Optional(FlashAsset.Direction.income))
                    }.pickerStyle(.segmented) }
                    DaybookSettingsField("金额") { TextField("待补充",text:$amount).keyboardType(.decimalPad) }
                    DaybookSettingsField("币种") { TextField("CNY / USD / JPY",text:$currency).textInputAutocapitalization(.characters).autocorrectionDisabled() }
                    DaybookSettingsField("日期") { TextField("yyyy-MM-dd",text:$date).keyboardType(.numbersAndPunctuation) }
                    DaybookSettingsField("分类") { TextField("未分类",text:Binding(get:{ item.category ?? "" },set:{ item.category=$0 })) }
                }
                if let error { Text(error).font(.system(size:13)).foregroundStyle(DaybookStyle.red) }
                Button(saving ? "正在保存…" : "保存") { Task { await save() } }
                    .buttonStyle(DaybookPrimaryButtonStyle(wide:true)).disabled(saving || item.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("notebook.editor.save")
            }.padding(.top,14)
        }.interactiveDismissDisabled(saving).onAppear {
            currency=item.currency ?? ""; date=item.date ?? ""
            amount=item.amountMinor.map { FlashMoney.decimalString($0,currency:currency) } ?? ""
        }
    }
    private func save() async {
        saving=true; defer { saving=false }
        do {
            var value=item; value.title=value.title.trimmingCharacters(in:.whitespacesAndNewlines); value.text=value.text.trimmingCharacters(in:.whitespacesAndNewlines)
            if value.title.isEmpty { value.title=String(value.text.prefix(40)) }
            if isNew { value.source.quote=value.text; value.source.title=value.title }
            if value.kind == .expense {
                let code=currency.trimmingCharacters(in:.whitespacesAndNewlines).uppercased(), amount=amount.trimmingCharacters(in:.whitespacesAndNewlines)
                value.currency=code.isEmpty ? nil : code
                value.amountMinor=amount.isEmpty || code.isEmpty ? nil : try FlashMoney.minorUnits(amount,currency:code)
                value.date=date.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? nil : date
            }
            let saved:Bool
            if mergeSeeds.isEmpty { saved=await model.save(value) }
            else { saved=await model.merge(value,seeds:mergeSeeds) }
            if saved {
                onSaved(); NotificationCenter.default.post(name:.notebookAssetSaved,object:nil); dismiss()
            } else { error=model.error }
        } catch { self.error=error.localizedDescription }
    }
}

struct NotebookAssetDetail: View {
    @ObservedObject var model: NotebookIdeasModel
    let opening: FlashAsset
    let onOpenSource:(UUID)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var editing:FlashAsset?
    @State private var busy=false
    @State private var confirmingDelete=false
    private var item:FlashAsset {
        [opening,model.latestSaved,model.rows.first { $0.id == opening.id }]
            .compactMap{$0}.filter{$0.id == opening.id}.max(by:{$0.revision < $1.revision}) ?? opening
    }
    var body:some View {
        DaybookSheetLayout(title:item.kind == .idea ? "灵感" : "账目",onClose:{ dismiss() }) {
            VStack(alignment:.leading,spacing:20) {
                Text(item.title).font(.system(size:24,weight:.semibold))
                if item.kind == .expense { Text(item.amountText).font(.system(size:28,weight:.medium)).monospacedDigit() }
                Text(item.text).font(.system(size:16)).lineSpacing(7).textSelection(.enabled)
                Text("\(item.kind == .expense ? (item.date ?? "日期待补充") : RecordingFormat.date(item.source.capturedAt)) · \(item.revoked ? "已删除" : item.statusTitle)").font(.system(size:12)).foregroundStyle(DaybookStyle.secondary)
                HStack(spacing:28) {
                    Button("编辑") { editing=item }.accessibilityIdentifier("notebook.detail.edit")
                    if item.revoked {
                        Button("恢复") { setDeleted(false) }.disabled(busy)
                    } else {
                        Button(item.kind == .idea ? "删除灵感" : "删除账目",role:.destructive) { confirmingDelete=true }
                            .disabled(busy).accessibilityIdentifier("notebook.detail.delete")
                    }
                }.font(.system(size:14,weight:.medium)).disabled(busy)
                if let parents=item.parentIdeas,!parents.isEmpty {
                    VStack(alignment:.leading,spacing:14) {
                        Text("来自这些灵感").font(.system(size:13,weight:.medium))
                        ForEach(parents) { source in
                            DisclosureGroup(source.title) { Text(source.text).font(.system(size:14)).lineSpacing(5).padding(.top,8) }
                        }
                        Text("保留保存时的原灵感快照，后续编辑不会改变此出处。").font(.system(size:12)).foregroundStyle(DaybookStyle.secondary)
                    }.daybookRecordingCard(padding:16)
                } else {
                    VStack(alignment:.leading,spacing:10) {
                        Text(item.origin == .manual ? "初次记录" : "原话").font(.system(size:13,weight:.medium))
                        Text(item.source.quote).font(.system(size:14)).lineSpacing(6)
                        if item.origin == nil {
                            Button("查看来源录音") { onOpenSource(item.source.id) }.font(.system(size:13))
                        }
                    }.daybookRecordingCard(padding:16)
                }
                if let error=model.error { Text(error).font(.system(size:13)).foregroundStyle(DaybookStyle.red) }
            }.padding(.top,12)
        }.sheet(item:$editing) { NotebookAssetEditor(model:model,item:$0,isNew:false) }
            .confirmationDialog(item.kind == .idea ? "删除这条灵感？" : "删除这笔账目？",isPresented:$confirmingDelete,titleVisibility:.visible) {
                Button("删除",role:.destructive) { setDeleted(true) }
                Button("取消",role:.cancel) {}
            } message: {
                Text(item.kind == .idea ? "原始录音和其他灵感保留。可在“显示已删除”中恢复。" : "删除后更新月度收支，原始录音保留。可在“显示已删除”中恢复。")
            }.interactiveDismissDisabled(busy)
    }
    private func setDeleted(_ deleted:Bool) {
        busy=true
        Task {
            var value=item;value.revoked=deleted
            if await model.save(value) { NotificationCenter.default.post(name:.notebookAssetSaved,object:nil); dismiss() }
            busy=false
        }
    }
}

struct NotebookGenerateView: View {
    @ObservedObject var model:NotebookIdeasModel
    let seeds:[FlashAsset]
    @EnvironmentObject private var settings:AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var direction=""
    @State private var confirming=false
    @State private var approvedConfiguration:AIConfiguration?
    @State private var approvedRevision:Int?
    var body:some View {
        if let draft=model.result { NotebookCandidateView(model:model,draft:draft) }
        else {
            DaybookSheetLayout(title:"AI 再创作",onClose:{ model.cancelGeneration(); dismiss() }) {
                VStack(alignment:.leading,spacing:20) {
                    Text("只使用选中的 \(seeds.count) 条灵感，原内容保持不变。").font(.system(size:14)).foregroundStyle(DaybookStyle.secondary)
                    ForEach(seeds) { seed in DisclosureGroup(seed.title) { Text(seed.text).font(.system(size:14)).lineSpacing(5).padding(.top,8) } }
                    DaybookSettingsField("创作方向（可选）") { TextField("比如：组合成一个可实践的新想法",text:$direction,axis:.vertical).lineLimit(3...5).disabled(model.generating) }
                    Text("当前模型：\(model.configuration(seeds:seeds,settings:settings).label)").font(.system(size:12)).foregroundStyle(DaybookStyle.secondary)
                    if model.generating {
                        ProgressView("正在联系这些想法…")
                        Button("停止生成") { model.cancelGeneration() }
                    } else {
                        Button(model.error == nil ? "生成新灵感" : "重新生成") { requestGeneration() }.buttonStyle(DaybookPrimaryButtonStyle(wide:true))
                    }
                    if let error=model.error { Text(error).font(.system(size:13)).foregroundStyle(DaybookStyle.red) }
                }.padding(.top,12)
            }.alert("发送所选灵感到 AI 模型？",isPresented:$confirming) {
                Button("取消",role:.cancel) {}
                Button("发送并生成") { model.generate(seeds:seeds,direction:direction,settings:settings,approvedConfiguration:approvedConfiguration,approvedRevision:approvedRevision) }
            } message: { Text("将发送上方 \(seeds.count) 条灵感的标题、内容和创作方向到 \(approvedConfiguration?.destinationDescription ?? "当前模型")。生成结果会保存为本机候选，采纳后才加入灵感。") }
        }
    }
    private func requestGeneration() {
        let config=model.configuration(seeds:seeds,settings:settings)
        if config.isRemote && settings.requiresRemoteAIConfirmation {
            approvedConfiguration=config; approvedRevision=settings.aiRevision; confirming=true
        } else { model.generate(seeds:seeds,direction:direction,settings:settings,approvedConfiguration:nil,approvedRevision:nil) }
    }
}

struct NotebookCandidateView: View {
    @ObservedObject var model:NotebookIdeasModel
    let draft:NotebookIdeaDraft
    @Environment(\.dismiss) private var dismiss
    @State private var selected=Set<UUID>()
    @State private var saving=false
    @State private var discard=false
    var body:some View {
        DaybookSheetLayout(title:"新的灵感",onClose:{ model.result=nil; dismiss() }) {
            VStack(alignment:.leading,spacing:20) {
                Text("候选已保存在本机，选择喜欢的另存为新灵感。").font(.system(size:14)).foregroundStyle(DaybookStyle.secondary)
                ForEach(draft.candidates) { candidate in
                    Button {
                        if selected.contains(candidate.id) { selected.remove(candidate.id) } else { selected.insert(candidate.id) }
                    } label: {
                        VStack(alignment:.leading,spacing:12) {
                            HStack { Text(candidate.title).font(.system(size:17,weight:.medium)); Spacer(); Image(systemName:selected.contains(candidate.id) || draft.savedCandidateIDs.contains(candidate.id) ? "checkmark.circle.fill" : "circle") }
                            Text(candidate.text).font(.system(size:15)).lineSpacing(6)
                            if draft.savedCandidateIDs.contains(candidate.id) { Text("已保存").font(.system(size:12)).foregroundStyle(DaybookStyle.secondary) }
                        }.frame(maxWidth:.infinity,alignment:.leading).daybookRecordingCard(padding:18)
                    }.buttonStyle(.plain).disabled(draft.savedCandidateIDs.contains(candidate.id) || saving)
                }
                Button(saving ? "正在保存…" : "保存所选灵感") { Task {
                    saving=true
                    if await model.accept(draft,ids:selected) { NotificationCenter.default.post(name:.notebookAssetSaved,object:nil); dismiss() }
                    saving=false
                } }.buttonStyle(DaybookPrimaryButtonStyle(wide:true)).disabled(selected.isEmpty || saving)
                Button("丢弃这份草稿",role:.destructive) { discard=true }.font(.system(size:13)).disabled(saving)
                if let error=model.error { Text(error).font(.system(size:13)).foregroundStyle(DaybookStyle.red) }
            }.padding(.top,12)
        }.interactiveDismissDisabled(saving).confirmationDialog("丢弃未保存候选？",isPresented:$discard,titleVisibility:.visible) {
            Button("丢弃草稿",role:.destructive) { Task { if await model.discard(draft) { dismiss() } } }
        } message: { Text("已保存的灵感和原始灵感都会保留。") }
    }
}
