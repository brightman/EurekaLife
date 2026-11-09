import SwiftUI

struct NotebookPlacesView:View {
    let onOpenSource:(UUID)->Void
    @State private var places:[NotebookPlace]=[]
    @State private var selected:NotebookPlace?
    @State private var loading=false
    @State private var more=false
    @State private var generation=UUID()
    @State private var error:String?
    init(onOpenSource:@escaping(UUID)->Void) { self.onOpenSource=onOpenSource }
    var body:some View {
        List {
            Section {
                Text("近 30 天 · 同一地点每天计 1 次").font(.subheadline)
                Text("按记录中的位置归组，附近地点可能归为同一区域。").font(.caption).foregroundStyle(DaybookStyle.secondary)
                Button("刷新") { Task { await load(reset:true) } }.disabled(loading)
            }
            if let error { Text(error).foregroundStyle(DaybookStyle.red) }
            if places.isEmpty && !loading { Text("暂无含原始拍摄或录制位置的记录。").foregroundStyle(DaybookStyle.secondary) }
            ForEach(places) { place in
                Button { selected=place } label: {
                    HStack {
                        Image(systemName:"mappin.circle").foregroundStyle(DaybookStyle.accent)
                        VStack(alignment:.leading,spacing:6) {
                            Text(place.name).font(.system(size:16,weight:.medium))
                            if let address=place.address,address != place.name { Text(address).font(.system(size:12)).foregroundStyle(DaybookStyle.secondary).lineLimit(2) }
                            ProgressView(value:Double(place.days),total:Double(max(1,places.first?.days ?? 1))).tint(DaybookStyle.accent).padding(.vertical,3)
                            Text(place.type ?? "标记这个地点").font(.system(size:12)).foregroundStyle(place.type == nil ? DaybookStyle.accent : DaybookStyle.secondary)
                        }
                        Spacer();Text("\(place.days) 次").font(.headline).foregroundStyle(DaybookStyle.accent)
                    }.padding(.vertical,6)
                }.foregroundStyle(DaybookStyle.ink)
            }
            if loading { ProgressView("正在整理地点…") }
            if more { Button("加载更多") { Task { await load(reset:false) } }.disabled(loading) }
        }.scrollContentBackground(.hidden).background(DaybookStyle.paper).tint(DaybookStyle.accent)
            .task { await load(reset:true) }
            .sheet(item:$selected,onDismiss:{ Task { await load(reset:true) } }) { place in
                NotebookPlaceDetail(place:place,onOpenSource:onOpenSource)
            }
    }
    @MainActor private func load(reset:Bool) async {
        if loading && !reset { return }
        let token=UUID();generation=token;loading=true
        if reset { places=[];more=false }
        let offset=reset ? 0 : places.count
        do {
            let result=try await Task.detached {
                let repo=try NotebookPlacesRepository(database:DaybookDatabase())
                if reset { try repo.rebuild() }
                return try repo.page(offset:offset)
            }.value
            guard generation==token,!Task.isCancelled else { return }
            places=reset ? result : places+result;more=result.count==40;error=nil
        } catch {
            guard generation==token,!Task.isCancelled else { return }
            self.error=error.localizedDescription
        }
        guard generation==token else { return };loading=false
    }
}

struct NotebookPlaceDetail:View {
    let place:NotebookPlace
    let onOpenSource:(UUID)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var name:String
    @State private var type:String?
    @State private var revision:Int
    @State private var days:[NotebookPlaceDay]=[]
    @State private var editing=false
    @State private var loading=false
    @State private var error:String?
    init(place:NotebookPlace,onOpenSource:@escaping(UUID)->Void) {
        self.place=place;self.onOpenSource=onOpenSource
        _name=State(initialValue:place.name);_type=State(initialValue:place.type);_revision=State(initialValue:place.revision)
    }
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    HStack(spacing:16) {
                        Image(systemName:"mappin.and.ellipse").font(.system(size:26)).foregroundStyle(DaybookStyle.accent)
                            .frame(width:60,height:60).background(DaybookStyle.accent.opacity(0.10),in:RoundedRectangle(cornerRadius:18))
                        VStack(alignment:.leading,spacing:8) {
                            Text(name).font(.system(size:23,weight:.semibold))
                            if let type { Text(type).font(.system(size:13)).foregroundStyle(DaybookStyle.accent) }
                            if let hint=place.address ?? place.coordinateHint { Text(hint).font(.system(size:12)).foregroundStyle(DaybookStyle.secondary) }
                        }
                    }
                    Button { editing=true } label: { Label(type == nil ? "标记这个地点" : "修改名称与类型",systemImage:"pencil") }
                        .font(.system(size:14,weight:.medium)).accessibilityIdentifier("notebook.place.edit")
                    VStack(alignment:.leading,spacing:10) {
                        Text("\(place.days) 次").font(.system(size:32,weight:.semibold)).monospacedDigit()
                        Text("近 30 天出现 · 同一天只记 1 次").font(.system(size:13)).foregroundStyle(DaybookStyle.secondary)
                    }.frame(maxWidth:.infinity,alignment:.leading).daybookRecordingCard(padding:20)
                    Text("出现日期").font(.system(size:15,weight:.semibold))
                    LazyVStack(spacing:0) {
                        ForEach(days) { day in
                            NavigationLink {
                                NotebookPlaceDayView(placeID:place.id,name:name,day:day,onOpenSource:{ id in dismiss();onOpenSource(id) })
                            } label: {
                                HStack {
                                    VStack(alignment:.leading,spacing:6) {
                                        Text(day.day).font(.system(size:16))
                                        Text("\(day.sourceCount) 条来源记录 · 计 1 次").font(.system(size:12)).foregroundStyle(DaybookStyle.secondary)
                                    }
                                    Spacer();Image(systemName:"chevron.right").font(.system(size:12))
                                }.foregroundStyle(DaybookStyle.ink).padding(.vertical,16)
                            }.accessibilityIdentifier("notebook.place.day.\(day.day)")
                            Divider()
                        }
                    }
                    if loading { ProgressView() }
                    if let error { Text(error).foregroundStyle(DaybookStyle.red);Button("重试") { Task { await load() } } }
                }.padding(24)
            }.background(DaybookStyle.paper).foregroundStyle(DaybookStyle.ink)
                .navigationTitle("地点").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("完成") { dismiss() } } }
                .sheet(isPresented:$editing) {
                    NotebookPlaceEditor(placeID:place.id,revision:revision,name:name == "未命名区域" ? "" : name,type:type) { savedName,savedType in
                        name=savedName;type=savedType;revision+=1;editing=false
                    }
                }
        }.tint(DaybookStyle.accent).task { await load() }
    }
    @MainActor private func load() async {
        guard !loading else { return };loading=true;defer { loading=false }
        let id=place.id
        do { days=try await Task.detached { try NotebookPlacesRepository(database:DaybookDatabase()).visitDays(placeID:id) }.value;error=nil }
        catch { self.error=error.localizedDescription }
    }
}

private struct NotebookPlaceEditor:View {
    let placeID:String
    let revision:Int
    @State var name:String
    @State var type:String?
    let onSaved:(String,String)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var saving=false
    @State private var error:String?
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    VStack(alignment:.leading,spacing:10) {
                        Text("地点名称").font(.system(size:13)).foregroundStyle(DaybookStyle.secondary)
                        TextField("例如：家、公司、梧桐咖啡",text:$name).font(.system(size:16)).accessibilityIdentifier("notebook.place.name")
                    }.daybookRecordingCard(padding:18)
                    Text("地点类型").font(.system(size:13)).foregroundStyle(DaybookStyle.secondary)
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:88))],spacing:12) {
                        ForEach(NotebookPlaceGrid.types,id:\.self) { value in
                            Button { type=value } label: {
                                Text(value).font(.system(size:14,weight:type == value ? .semibold : .regular))
                                    .frame(maxWidth:.infinity,minHeight:44)
                                    .background(type == value ? DaybookStyle.accent.opacity(0.14) : DaybookStyle.line.opacity(0.25),in:RoundedRectangle(cornerRadius:12))
                            }.accessibilityAddTraits(type == value ? .isSelected : [])
                        }
                    }
                    Text("已有记录会沿用这个名称，出现次数不变。").font(.system(size:13)).foregroundStyle(DaybookStyle.secondary)
                    if let error { Text(error).font(.system(size:13)).foregroundStyle(DaybookStyle.red) }
                }.padding(24).disabled(saving)
            }.background(DaybookStyle.paper).scrollDismissesKeyboard(.interactively)
                .navigationTitle("标记地点").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) { Button("取消") { dismiss() }.disabled(saving) }
                    ToolbarItem(placement:.confirmationAction) { Button(saving ? "保存中…" : "保存") { save() }
                        .disabled(saving || name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || name.count > 40 || type == nil) }
                }
        }.tint(DaybookStyle.accent).interactiveDismissDisabled(saving)
    }
    private func save() {
        guard let type else { return };saving=true
        let id=placeID,name=name.trimmingCharacters(in:.whitespacesAndNewlines),revision=revision
        Task {
            do {
                try await Task.detached { try NotebookPlacesRepository(database:DaybookDatabase()).saveLabel(id:id,name:name,type:type,expectedRevision:revision) }.value
                onSaved(name,type)
            } catch { self.error=error.localizedDescription }
            saving=false
        }
    }
}

private struct NotebookPlaceDayView:View {
    let placeID:String
    let name:String
    let day:NotebookPlaceDay
    let onOpenSource:(UUID)->Void
    @State private var visits:[NotebookPlaceVisit]=[]
    @State private var loading=false
    @State private var more=true
    @State private var error:String?
    var body:some View {
        List {
            Section {
                Text(name).font(.headline)
                Text("\(day.day) · 当天共计 1 次出现").font(.subheadline).foregroundStyle(DaybookStyle.secondary)
            }
            ForEach(visits) { visit in
                Button { onOpenSource(visit.sourceID) } label: {
                    VStack(alignment:.leading,spacing:6) {
                        Label("\(visit.sourceKind) · \(time(visit))",systemImage:visit.sourceKind == "照片" ? "photo" : "waveform")
                        if visit.dateBasis.contains("未知") { Text(visit.dateBasis).font(.caption).foregroundStyle(DaybookStyle.secondary) }
                    }.padding(.vertical,8)
                }
            }
            if let error { Text(error).foregroundStyle(DaybookStyle.red) }
            if loading { ProgressView() }
            else if more { Button(error == nil ? "加载更多来源" : "重试") { Task { await load() } } }
        }.scrollContentBackground(.hidden).background(DaybookStyle.paper)
            .navigationTitle("当天的地点记录").navigationBarTitleDisplayMode(.inline).task { if visits.isEmpty { await load() } }
    }
    private func time(_ visit:NotebookPlaceVisit)->String {
        let formatter=DateFormatter();formatter.dateFormat="HH:mm:ss";formatter.timeZone=TimeZone(identifier:visit.timeZoneIdentifier) ?? TimeZone(secondsFromGMT:0)!
        return formatter.string(from:visit.capturedAt)
    }
    @MainActor private func load() async {
        guard !loading else { return };loading=true;defer { loading=false }
        let id=placeID,date=day.day,offset=visits.count
        do {
            let result=try await Task.detached { try NotebookPlacesRepository(database:DaybookDatabase()).visits(placeID:id,day:date,offset:offset) }.value
            guard !Task.isCancelled else { return };visits+=result;more=result.count==50;error=nil
        } catch { self.error=error.localizedDescription }
    }
}
