import SwiftUI

/// Typed citations reuse native notebook details; reports preserve exact filters and SQL counts.
struct AskAIReferenceView: View {
    let reference: AgentEvidenceRef
    let permissions: AgentNotebookPermissions
    let scope: AgentQueryScope
    let readOriginal: (UUID, Int) async throws -> AskAIRuntimeStore.OriginalTurnPage?
    let onOpenRecord: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notebook = NotebookIdeasModel()
    @State private var asset: FlashAsset?
    @State private var person: NotebookPerson?
    @State private var place: NotebookPlace?
    @State private var selectedAsset: FlashAsset?
    @State private var page: AskAINotebookReader.Page?
    @State private var items: [AskAINotebookReader.Item] = []
    @State private var groups: [AskAINotebookReader.LedgerGroup] = []
    @State private var originals: [AskAIRuntimeStore.OriginalTurnPage] = []
    @State private var nextOffset: Int? = 0
    @State private var error: String?
    @State private var loading = false
    private var query: [String:Any] {
        guard let spec=reference.querySpecification else { return [:] }
        return (try? JSONSerialization.jsonObject(with:Data(spec.utf8))) as? [String:Any] ?? [:]
    }
    private var isAggregate: Bool { query["name"] as? String == "aggregateLedger" }
    private var isEntity: Bool {
        [.ideas,.ledger,.people,.places].contains(reference.domain) &&
        !["aggregateLedger","listPersonSegments","listPlaceVisits"].contains(query["name"] as? String ?? "")
    }
    private var title: String {
        if isAggregate { return "记账统计" }
        if reference.domain == .conversation { return "历史对话" }
        return reference.domain == .places ? "到访记录" : "关联录音"
    }
    var body: some View {
        Group {
            if let asset { NotebookAssetDetail(model:notebook,opening:asset,onOpenSource:openRecord) }
            else if let person { NotebookPersonDetail(person:person,onOpenSource:openRecord,onUpdated:{ self.person=$0 }) }
            else if let place { NotebookPlaceDetail(place:place,onOpenSource:openRecord) }
            else { report }
        }.task(id:reference.id) { await load() }
            .onChange(of:permissions) { _,_ in dismiss() }
            .onChange(of:scope) { _,_ in dismiss() }
            .sheet(item:$selectedAsset) { item in NotebookAssetDetail(model:notebook,opening:item,onOpenSource:openRecord) }
    }
    private var report: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    if let error { Text(error).font(.subheadline).foregroundStyle(DaybookStyle.secondary) }
                    if !filterDescription.isEmpty { Text(filterDescription).font(.subheadline).foregroundStyle(DaybookStyle.secondary) }
                    ForEach(originals.indices,id:\.self) { index in
                        let turn=originals[index]
                        if index == 0 {
                            Text((turn.createdAt ?? turn.day).formatted()).font(.caption).foregroundStyle(DaybookStyle.secondary)
                            Text(turn.question).font(.headline)
                        }
                        Text(turn.answer).textSelection(.enabled).lineSpacing(6)
                    }
                    if let page { reportHeader(page) }
                    ForEach(items.indices,id:\.self) { index in itemRow(items[index]) }
                    if loading { ProgressView("正在读取来源…").frame(maxWidth:.infinity) }
                    else if nextOffset != nil { Button(items.isEmpty && originals.isEmpty ? "重试" : "加载更多") { Task { await load() } }.buttonStyle(DaybookSettingsButtonStyle()) }
                }.padding(24)
            }.background(DaybookStyle.paper).foregroundStyle(DaybookStyle.ink)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("完成") { dismiss() } } }
        }.tint(DaybookStyle.accent)
    }
    @ViewBuilder private func reportHeader(_ page: AskAINotebookReader.Page) -> some View {
        if isAggregate {
            Text("已确认 \(page.matchedCount) 笔账目").font(.headline)
            if page.pendingCount>0 { Text("该范围内另有 \(page.pendingCount) 笔待补充，未计入合计。").font(.caption) }
            if page.undatedCount>0 { Text("另有 \(page.undatedCount) 笔缺少日期，暂不能归入本次时间范围。").font(.caption) }
            if page.unclassifiedCount>0 { Text("已确认账目中，\(page.unclassifiedCount) 笔尚未分类。").font(.caption) }
            ForEach(groups.indices,id:\.self) { index in
                let group=groups[index]
                VStack(alignment:.leading,spacing:8) {
                    Text([group.direction == "income" ? "收入" : "支出",group.group == "unclassified" ? "未分类" : group.group].filter{!$0.isEmpty}.joined(separator:" · ")).font(.subheadline)
                    Text("\(group.currency) \(FlashMoney.decimalString(group.amountMinor,currency:group.currency))").font(.title2).monospacedDigit()
                    Text("\(group.count) 笔").font(.caption).foregroundStyle(DaybookStyle.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading).daybookRecordingCard(padding:18)
            }
            Text("账目明细").font(.headline)
        } else if reference.domain == .places {
            Text(page.coverage.contains("detail matchedCount") ? "\(page.matchedCount) 条已保存的位置依据" : "\(page.matchedCount) 个自然日 · 同一天只计一次").font(.headline)
            if page.availableRange.count == 2 { Text("位置资料覆盖 \(page.availableRange[0]) 至 \(page.availableRange[1])；不代表完整行程或停留时长。").font(.caption).foregroundStyle(DaybookStyle.secondary) }
        }
        if page.restrictedCount>0 { Text("部分资料仅限本机处理，未包含在这次结果中。").font(.caption).foregroundStyle(DaybookStyle.secondary) }
        if page.status == "empty" { Text("这个范围内没有可用记录。").foregroundStyle(DaybookStyle.secondary) }
    }
    private var filterDescription: String {
        var values:[String]=[]
        if let start=query["start"] as? String { values.append("从 \(String(start.prefix(10)))") }
        if let end=query["end"] as? String { values.append("至 \(String(end.prefix(10)))（不含当天）") }
        if let currency=query["currency"] as? String { values.append(currency) }
        if let category=query["category"] as? String { values.append(category) }
        if let direction=query["direction"] as? String { values.append(direction == "income" ? "收入" : "支出") }
        return values.joined(separator:" · ")
    }
    @ViewBuilder private func itemRow(_ item: AskAINotebookReader.Item) -> some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(alignment:.top) {
                Text(item.title).font(.headline);Spacer()
                if let raw=item.fields["amountMinor"],let amount=Int64(raw),let currency=item.fields["currency"] {
                    Text("\(item.fields["direction"] == "income" ? "+" : "−")\(currency) \(FlashMoney.decimalString(amount,currency:currency))").font(.subheadline).monospacedDigit()
                }
            }
            if let day=item.fields["day"] { Text(day).font(.caption).foregroundStyle(DaybookStyle.secondary) }
            if reference.domain == .places {
                Text(item.fields["source_kind"] == "image" ? "来自照片的位置记录" : "来自录音的位置记录")
                    .foregroundStyle(DaybookStyle.secondary)
                if let count=item.fields["sourceCount"] { Text("当天 \(count) 条来源记录").font(.caption) }
            } else { Text(item.text).lineSpacing(5).textSelection(.enabled) }
            if item.fields["identityNeedsReview"] == "true" { Text("说话人关联需要复核；这段发言不代表现实见面记录。").font(.caption).foregroundStyle(DaybookStyle.secondary) }
            if isAggregate { Button("查看账目") { Task { await openAsset(item.id) } } }
            else if let id=(item.fields["segmentID"] ?? item.fields["sourceID"]).flatMap(UUID.init(uuidString:)) {
                Button(item.fields["segmentID"] == nil ? "查看来源记录" : "查看录音片段") { openRecord(id) }
            }
        }.font(.subheadline).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,12)
            .overlay(alignment:.bottom) { DaybookStyle.line.frame(height:0.5) }
    }
    private func openRecord(_ id:UUID) { dismiss(); onOpenRecord(id) }
    @MainActor private func openAsset(_ id:String) async {
        guard let uuid=UUID(uuidString:id) else { return }
        do {
            selectedAsset=try await Task.detached { try FlashCaptureRepository(database:DaybookDatabase()).asset(uuid).flatMap{$0.revoked ? nil : $0} }.value
            if selectedAsset == nil { error="这笔账目已删除。" }
        } catch { self.error="暂时无法读取账目，请稍后重试。" }
    }
    @MainActor private func load() async {
        guard !loading,let offset=nextOffset else { return }
        loading=true;error=nil;defer { loading=false }
        do {
            if reference.domain == .conversation,let id=UUID(uuidString:reference.entityID) {
                guard let turn=try await readOriginal(id,offset) else { error="原始问答已删除或不在当前读取范围。";nextOffset=nil;return }
                originals.append(turn);nextOffset=turn.nextOffset;return
            }
            let reader=AskAINotebookReader(permissions:permissions,scope:scope)
            if isEntity {
                let args=try JSONSerialization.data(withJSONObject:["type":reference.domain.rawValue,"id":reference.entityID])
                let current=try await reader.execute(name:"readNotebookItem",arguments:args)
                guard current.matchedCount>0,!current.items.isEmpty,!(["restricted","unavailable"].contains(current.status)) else { error="来源已删除、不可用或读取权限已关闭。";nextOffset=nil;return }
                let id=reference.entityID,domain=reference.domain
                if domain == .ideas || domain == .ledger,let uuid=UUID(uuidString:id) {
                    asset=try await Task.detached { try FlashCaptureRepository(database:DaybookDatabase()).asset(uuid).flatMap{$0.revoked ? nil : $0} }.value
                } else if domain == .people {
                    person=try await Task.detached { try NotebookPeopleRepository(database:DaybookDatabase()).lookup(id) }.value
                } else if domain == .places {
                    place=try await Task.detached { try NotebookPlacesRepository(database:DaybookDatabase()).lookup(id) }.value
                }
                guard !Task.isCancelled else { return }
                if asset == nil && person == nil && place == nil { error="来源已删除或不再可用。" }
                nextOffset=nil;return
            }
            let result=try await reader.detail(for:reference,offset:offset)
            guard !Task.isCancelled else { return }
            if ["unavailable","restricted"].contains(result.status) { error="资料已更新、删除或权限已关闭，请重新提问以获取最新结果。";nextOffset=nil;return }
            page=result
            items += result.items.filter { value in !items.contains{$0.id == value.id} }
            groups += result.groups.filter { value in !groups.contains{$0.currency == value.currency && $0.direction == value.direction && $0.group == value.group} }
            nextOffset=[result.nextOffset,result.nextCursor.flatMap(Int.init),result.nextGroupCursor.flatMap(Int.init)].compactMap{$0}.max()
        } catch { self.error="暂时无法读取来源，请稍后重试。" }
    }
}
