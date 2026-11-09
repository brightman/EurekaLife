import SwiftUI

/// Shared by Notebook add/edit and the recording speaker's add-contact sheet.
struct NotebookContactFields: View {
    @Binding var name:String
    @Binding var organization:String
    @Binding var email:String
    @Binding var phone:String
    @Binding var relationships:[String]
    var hasAdditionalEmails=false
    var hasAdditionalPhones=false
    @State private var availableRelationships:[String]=[]
    @State private var relationshipLoadFailed=false

    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            NotebookContactField(title:"姓名",required:true) {
                TextField("怎么称呼这个人",text:$name).textContentType(.name).accessibilityLabel("姓名")
            }
            NotebookContactField(title:"公司") {
                TextField("公司或组织名称",text:$organization).textContentType(.organizationName).accessibilityLabel("公司")
            }
            NotebookContactField(title:"邮箱") {
                TextField("name@example.com",text:$email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityLabel("邮箱")
            }
            if hasAdditionalEmails {
                Text("此处编辑第一个邮箱，其余邮箱保留；清空后将显示下一项。")
                    .font(.caption).foregroundStyle(DaybookStyle.secondary)
            }
            NotebookContactField(title:"手机号") {
                TextField("手机号，可含国家或地区代码",text:$phone)
                    .textContentType(.telephoneNumber).keyboardType(.phonePad).accessibilityLabel("手机号")
            }
            if hasAdditionalPhones {
                Text("此处编辑第一个号码，其余号码保留；清空后将显示下一项。")
                    .font(.caption).foregroundStyle(DaybookStyle.secondary)
            }
            NotebookRelationshipEditor(selection:$relationships,available:availableRelationships)
            if relationshipLoadFailed {
                Text("已有自定义关系暂未载入，你仍可选择或添加关系。")
                    .font(.caption).foregroundStyle(DaybookStyle.secondary)
            }
        }
        .task {
            do {
                let values=try await Task.detached {
                    try NotebookPeopleRepository(database:DaybookDatabase()).relationships()
                }.value
                guard !Task.isCancelled else { return }
                availableRelationships=values;relationshipLoadFailed=false
            } catch {
                guard !Task.isCancelled else { return }
                relationshipLoadFailed=true
            }
        }
    }
}

private struct NotebookContactField<Content:View>:View {
    let title:LocalizedStringKey
    var required=false
    @ViewBuilder var content:Content
    @ScaledMetric(relativeTo:.body) private var inputSize=16.0
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text(title).font(.footnote)
                Spacer()
                if required { Text("必填").font(.caption).foregroundStyle(DaybookStyle.secondary) }
            }
            content.font(.system(size:inputSize)).padding(.horizontal,13).padding(.vertical,12)
                .frame(minHeight:49).background(DaybookStyle.white,in:RoundedRectangle(cornerRadius:11))
                .overlay(RoundedRectangle(cornerRadius:11).stroke(DaybookStyle.line,lineWidth:1))
        }.foregroundStyle(DaybookStyle.ink)
    }
}

struct NotebookRelationshipEditor: View {
    @Binding var selection:[String]
    var available:[String]=[]
    @State private var custom=""
    @State private var added:[String]=[]
    @State private var expanded=false
    @State private var feedback=""
    private var choices:[String] { NotebookRelationships.normalized(NotebookRelationships.presets+available+added+selection) }
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text("关系").font(.footnote)
                Spacer()
                Text("可多选").font(.caption).foregroundStyle(DaybookStyle.secondary)
            }
            VStack(spacing:0) {
                Button { withAnimation(.easeInOut(duration:0.18)) { expanded.toggle() } } label: {
                    HStack(spacing:12) {
                        if selection.isEmpty {
                            Text("选择与我的关系").foregroundStyle(DaybookStyle.secondary)
                        } else {
                            ViewThatFits(in:.horizontal) {
                                HStack(spacing:6) {
                                    ForEach(selection,id:\.self) { value in
                                        Text(value).font(.caption).padding(.horizontal,8).padding(.vertical,5)
                                            .background(DaybookStyle.blueSoft,in:RoundedRectangle(cornerRadius:6))
                                    }
                                }.fixedSize(horizontal:true,vertical:false)
                                Text(selection.joined(separator:"、"))
                            }.foregroundStyle(DaybookStyle.accent)
                        }
                        Spacer(minLength:0)
                        Image(systemName:expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(DaybookStyle.secondary)
                    }.font(.subheadline).multilineTextAlignment(.leading)
                        .padding(13).frame(maxWidth:.infinity,minHeight:49,alignment:.leading).contentShape(Rectangle())
                }.accessibilityLabel("关系")
                    .accessibilityValue(selection.isEmpty ? "未选择" : selection.joined(separator:"、"))
                    .accessibilityHint(expanded ? "收起关系选项" : "展开关系选项")
                if expanded {
                    Divider().overlay(DaybookStyle.line)
                    VStack(alignment:.leading,spacing:13) {
                        LazyVGrid(columns:[GridItem(.adaptive(minimum:72),spacing:8)],alignment:.leading,spacing:8) {
                            ForEach(choices,id:\.self) { value in
                                Button {
                                    if selection.contains(value) { selection.removeAll{$0==value} }
                                    else { selection.append(value) }
                                    feedback=""
                                } label: {
                                    Text(value).font(.subheadline).multilineTextAlignment(.center)
                                        .frame(maxWidth:.infinity,minHeight:40).padding(.horizontal,4)
                                        .foregroundStyle(selection.contains(value) ? DaybookStyle.accent : DaybookStyle.ink)
                                        .background(selection.contains(value) ? DaybookStyle.blueSoft : DaybookStyle.white,in:RoundedRectangle(cornerRadius:9))
                                        .overlay(RoundedRectangle(cornerRadius:9).stroke(selection.contains(value) ? DaybookStyle.accent : DaybookStyle.line,lineWidth:1))
                                }.accessibilityAddTraits(selection.contains(value) ? [.isSelected] : [])
                            }
                        }
                        HStack(spacing:8) {
                            TextField("添加关系选项，如：跑友",text:$custom)
                                .font(.subheadline).padding(11)
                                .background(DaybookStyle.paper,in:RoundedRectangle(cornerRadius:9))
                                .overlay(RoundedRectangle(cornerRadius:9).stroke(DaybookStyle.line,lineWidth:1))
                                .accessibilityLabel("新的关系选项").submitLabel(.done).onSubmit(addCustom)
                            Button("添加",action:addCustom).font(.subheadline)
                                .padding(.horizontal,12).frame(minHeight:44)
                                .foregroundStyle(DaybookStyle.accent)
                                .background(DaybookStyle.blueSoft,in:RoundedRectangle(cornerRadius:9))
                                .disabled(custom.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                        }
                        Text(feedback.isEmpty ? "可同时选择多个关系，也可以添加新选项。" : feedback)
                            .font(.caption).foregroundStyle(DaybookStyle.secondary)
                    }.padding(13)
                }
            }.background(DaybookStyle.white,in:RoundedRectangle(cornerRadius:11))
                .overlay(RoundedRectangle(cornerRadius:11).stroke(DaybookStyle.line,lineWidth:1))
        }.buttonStyle(.plain).foregroundStyle(DaybookStyle.ink)
    }
    private func addCustom() {
        let value=custom.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let exists=choices.contains(value)
        added=NotebookRelationships.normalized(added+[value])
        selection=NotebookRelationships.normalized(selection+[value])
        custom=""
        feedback=exists ? "已选择“\(value)”" : "已添加并选择“\(value)”"
    }
}

struct NotebookPeopleView: View {
    let onOpenSource:(UUID)->Void
    @State private var people:[NotebookPerson]=[]
    @State private var filters:[String]=NotebookRelationships.presets
    @State private var filter:String?
    @State private var adding=false
    @State private var selected:NotebookPerson?
    @State private var more=true
    @State private var loading=false
    @State private var loadGeneration=UUID()
    @State private var error:String?
    init(onOpenSource:@escaping(UUID)->Void) { self.onOpenSource=onOpenSource }
    var body:some View {
        List {
            Section {
                Button("添加联系人") { adding=true }
                Picker("关系筛选",selection:$filter) {
                    Text("全部关系").tag(String?.none)
                    ForEach(filters,id:\.self) { Text($0).tag(Optional($0)) }
                }
            }
            if let error { Text(error).foregroundStyle(DaybookStyle.red); Button("刷新") { Task { await load(reset:true) } } }
            if people.isEmpty && !loading { Text("暂无联系人，可添加本地联系人。").foregroundStyle(DaybookStyle.secondary) }
            ForEach(people) { person in
                Button { selected=person } label: {
                    HStack(spacing:14) {
                        Text(String(person.name.prefix(1))).font(.system(size:22,weight:.medium))
                            .frame(width:48,height:48).background(DaybookStyle.accent.opacity(0.10),in:RoundedRectangle(cornerRadius:16))
                        VStack(alignment:.leading,spacing:6) {
                            Text(person.name).font(.system(size:16,weight:.medium)).foregroundStyle(DaybookStyle.ink)
                            if let organization=person.organization,!organization.isEmpty { Text(organization).font(.system(size:13)).foregroundStyle(DaybookStyle.secondary) }
                            if !person.relationships.isEmpty { Text(person.relationships.joined(separator:" · ")).font(.system(size:12)).foregroundStyle(DaybookStyle.accent) }
                        }
                        Spacer();Image(systemName:"chevron.right").font(.system(size:12)).foregroundStyle(DaybookStyle.secondary)
                    }.padding(.vertical,8).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("notebook.person.\(person.id)")
            }
            if more { Button(loading ? "读取中…" : "加载更多") { Task { await load(reset:false) } }.disabled(loading) }
        }.scrollContentBackground(.hidden).background(DaybookStyle.paper)
            .tint(DaybookStyle.accent)
            .task(id:filter) { await load(reset:true) }
            .sheet(isPresented:$adding) { NotebookPersonForm(person:nil) { _ in adding=false; Task { await load(reset:true) } } }
            .fullScreenCover(item:$selected) { person in
                NotebookPersonDetail(person:person,onOpenSource:{ id in selected=nil; onOpenSource(id) },onUpdated:{ saved in
                    if let index=people.firstIndex(where:{$0.id == saved.id}) { people[index]=saved }
                    filters=NotebookRelationships.normalized(filters+saved.relationships)
                    if let filter,!saved.relationships.contains(filter) { people.removeAll{$0.id == saved.id} }
                })
            }
    }
    @MainActor private func load(reset:Bool) async {
        if loading && !reset { return }
        let generation=UUID();loadGeneration=generation;loading=true
        if reset { people=[]; more=false }
        let requestedFilter=filter,offset=reset ? 0 : people.count
        do {
            let result=try await Task.detached {
                let repo=try NotebookPeopleRepository(database:DaybookDatabase())
                return (try repo.page(relationship:requestedFilter,offset:offset),try repo.relationships())
            }.value
            guard generation==loadGeneration,requestedFilter==filter,!Task.isCancelled else { return }
            people=reset ? result.0 : people+result.0; more=result.0.count==40
            filters=NotebookRelationships.normalized(NotebookRelationships.presets+result.1); error=nil
        } catch {
            guard generation==loadGeneration,!Task.isCancelled else { return }
            self.error=error.localizedDescription
        }
        guard generation==loadGeneration else { return }
        loading=false
    }
}

private struct NotebookPersonForm:View {
    let person:NotebookPerson?
    let onSaved:(NotebookPerson)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var name:String
    @State private var organization:String
    @State private var email:String
    @State private var phone:String
    @State private var relationships:[String]
    @State private var saving=false
    @State private var error:String?
    init(person:NotebookPerson?,onSaved:@escaping(NotebookPerson)->Void) {
        self.person=person;self.onSaved=onSaved
        _name=State(initialValue:person?.name ?? "");_organization=State(initialValue:person?.organization ?? "")
        _email=State(initialValue:person?.email ?? "");_phone=State(initialValue:person?.phone ?? "")
        _relationships=State(initialValue:person?.relationships ?? [])
    }
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    NotebookContactFields(name:$name,organization:$organization,email:$email,phone:$phone,relationships:$relationships,
                                          hasAdditionalEmails:(person?.emails.count ?? 0)>1,hasAdditionalPhones:(person?.phoneNumbers.count ?? 0)>1)
                        .disabled(saving)
                    Text("仅保存在 EurekaLife，不修改系统通讯录。").font(.caption).foregroundStyle(DaybookStyle.secondary)
                    if let error { Text(error).font(.subheadline).foregroundStyle(DaybookStyle.red) }
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively).background(DaybookStyle.paper)
                .navigationTitle(person == nil ? "添加联系人" : "编辑联系人").navigationBarTitleDisplayMode(.inline)
                .tint(DaybookStyle.accent).interactiveDismissDisabled(saving)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) { Button("取消") { dismiss() }.disabled(saving) }
                    ToolbarItem(placement:.confirmationAction) { Button(saving ? "保存中…" : "保存") {
                        saving=true;error=nil
                        let id=person?.id,revision=person?.revision,name=name,org=organization,email=email,phone=phone,relations=relationships
                        Task {
                            do {
                                let saved = try await Task.detached { try NotebookPeopleRepository(database:DaybookDatabase()).save(id:id,expectedRevision:revision,name:name,organization:org,email:email,phone:phone,relationships:relations) }.value
                                onSaved(saved)
                            } catch { self.error=error.localizedDescription; saving=false }
                        }
                    }.disabled(saving || name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }
                }
        }
    }
}
private struct NotebookPersonDetail:View {
    @State var person:NotebookPerson
    let onOpenSource:(UUID)->Void
    let onUpdated:(NotebookPerson)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var editing=false
    @State private var segments:[NotebookPersonSegment]=[]
    @State private var more=true
    @State private var loading=false
    @State private var error:String?
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    HStack {
                        Text("人物信息").font(.system(size:15,weight:.semibold))
                        Spacer(); Button("编辑") { editing=true }.font(.system(size:14,weight:.medium)).accessibilityIdentifier("notebook.person.edit")
                    }
                    VStack(alignment:.leading,spacing:18) {
                        HStack(alignment:.top,spacing:16) {
                            Text(String(person.name.prefix(1))).font(.system(size:28,weight:.medium))
                                .frame(width:64,height:64).background(DaybookStyle.accent.opacity(0.12),in:RoundedRectangle(cornerRadius:20))
                            VStack(alignment:.leading,spacing:8) {
                                Text(person.name).font(.system(size:24,weight:.semibold))
                                Text(person.organization ?? "未填写公司").font(.system(size:14)).foregroundStyle(DaybookStyle.secondary)
                                Text(person.relationships.isEmpty ? "未标记关系" : person.relationships.joined(separator:" · "))
                                    .font(.system(size:12)).foregroundStyle(DaybookStyle.accent)
                            }
                        }
                        Divider()
                        profileField("邮箱",person.email)
                        profileField("手机号",person.phone)
                    }.daybookRecordingCard(padding:20)
                    HStack {
                        Text("关联的录音片段").font(.system(size:15,weight:.semibold)).accessibilityAddTraits(.isHeader)
                        Spacer()
                        if !loading { Text("\(segments.count)\(more ? "+" : "") 条").font(.system(size:12)).foregroundStyle(DaybookStyle.secondary) }
                    }
                    if segments.isEmpty && !loading && error == nil {
                        Text("还没有关联的录音片段。为录音中的说话人关联此人物后，已完成整理的片段会出现在这里。")
                            .font(.system(size:14)).foregroundStyle(DaybookStyle.secondary).padding(.vertical,20)
                    }
                    LazyVStack(spacing:14) {
                        ForEach(segments) { segment in
                            Button { onOpenSource(segment.id) } label: {
                                VStack(alignment:.leading,spacing:12) {
                                    HStack {
                                        Text(segment.capturedAt,format:.dateTime.month().day().hour().minute().second())
                                        Spacer();Text(duration(segment.duration))
                                    }.font(.system(size:12)).foregroundStyle(DaybookStyle.secondary)
                                    Text(segment.title).font(.system(size:17,weight:.medium)).foregroundStyle(DaybookStyle.ink)
                                    if !segment.summary.isEmpty { Text(segment.summary).font(.system(size:14)).lineSpacing(5).lineLimit(4).foregroundStyle(DaybookStyle.bodyText) }
                                    Label([segment.device,person.name].compactMap{$0}.joined(separator:" · "),systemImage:"waveform").font(.system(size:12)).foregroundStyle(DaybookStyle.accent)
                                    if segment.needsReview { Text("说话人识别已变化，请复核关联").font(.system(size:12)).foregroundStyle(DaybookStyle.red) }
                                }.frame(maxWidth:.infinity,alignment:.leading).daybookRecordingCard(padding:18)
                            }.buttonStyle(.plain).accessibilityIdentifier("notebook.person.segment.\(segment.id)")
                        }
                    }
                    if let error { Text(error).font(.system(size:13)).foregroundStyle(DaybookStyle.red) }
                    if loading { ProgressView("正在读取片段…").frame(maxWidth:.infinity) }
                    else if more { Button(error == nil ? "加载更多" : "重试") { Task { await load() } } }
                }.padding(24)
            }.background(DaybookStyle.paper).foregroundStyle(DaybookStyle.ink)
                .navigationTitle("人物详情").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.cancellationAction) { Button { dismiss() } label: { Label("人物",systemImage:"chevron.left") } } }
                .sheet(isPresented:$editing) { NotebookPersonForm(person:person) { saved in person=saved;onUpdated(saved);editing=false } }
        }.tint(DaybookStyle.accent).task { if segments.isEmpty { await load() } }
    }
    private func profileField(_ title:String,_ value:String)->some View {
        HStack(alignment:.top) {
            Text(title).foregroundStyle(DaybookStyle.secondary).frame(width:56,alignment:.leading)
            Text(value.isEmpty ? "未填写" : value).textSelection(.enabled)
        }.font(.system(size:14))
    }
    private func duration(_ seconds:Double)->String {
        let value=Int(max(0,seconds));return value < 60 ? "\(value) 秒" : "\(value/60) 分 \(value%60) 秒"
    }
    @MainActor private func load() async {
        guard !loading else { return }; loading=true; defer { loading=false }
        let id=person.id,offset=segments.count
        do {
            let result=try await Task.detached { try NotebookPeopleRepository(database:DaybookDatabase()).segments(contactID:id,offset:offset) }.value
            guard !Task.isCancelled else { return }
            segments+=result;more=result.count==30;error=nil
        } catch { self.error=error.localizedDescription }
    }
}
