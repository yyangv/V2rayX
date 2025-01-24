//
//  SRoutePage.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/27.
//

import SwiftUI
import SwiftData

struct SRoutePage: View {
    @Environment(\.modelContext) private var modelContext

    @Environment(CoreModel.self) private var modCore
    @Environment(SettingModel.self) private var modSetting

    var body: some View {
        Form {
            PreferenceSection
            RuleSection
            GeoSection
        }
        .formStyle(.grouped)
    }
    
    private var PreferenceSection: some View {
        Section(header: Text("Preference")) {
            @Bindable var m = modCore
            Picker("Domain Strategy", selection: $m.domainStrategy) {
                Text("AsIs").tag("AsIs")
                Text("IPIfNonMatch").tag("IPIfNonMatch")
                Text("IPOnDemand").tag("IPOnDemand")
            }
        }
    }
    
    @Query(sort: \RouteRuleModel.idx, order: .forward) private var rules: [RouteRuleModel]
    
    @State private var sheetRuleOpen = false
    @State private var sheetRuleData: RuleItem.Data? = nil
    
    private var RuleSection: some View {
        Section {
            List {
                ForEach(rules) { it in
                    let data = RuleItem.Data(
                        key: it.name,
                        name: it.name,
                        outboundTag: it.outboundTag,
                        domain: it.domain,
                        ip: it.ip,
                        port: it.port,
                        network: it.network,
                        protocol: it.protocol0
                    )
                    RuleItem(rule: data, enabled: it.enabled) {
                        sheetRuleData = data
                        sheetRuleOpen = true
                    } onEnabled: { enabled in
                        onRuleEnabled(it, enabled)
                    } onDelete: {
                        onRuleRemoved(it)
                    }
                }
                .onMove(perform: moveItem)
            }
        } header: {
            HStack {
                Text("Rule List")
                Spacer()
                Button {
                    sheetRuleData = nil
                    sheetRuleOpen = true
                } label: {
                    Label("New Rule", systemImage: "document.badge.plus.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .sheet(isPresented: $sheetRuleOpen) {
            let data = intoItemEditor(sheetRuleData)
            let options = options()
            Editor(data: data, outboundTagOptions: options, onConfirm: onEditorConfirm) {
                sheetRuleOpen = false
                sheetRuleData = nil
            }
        }
        .onAppear {
            installRules()
        }
    }
    
    @State private var sheetGeoEditor = false
    @Query(filter: #Predicate<FileModel> { f in f.fileType == "geo" })
    private var geos: [FileModel]
    
    private var GeoSection: some View {
        Section {
            List {
                ForEach(geos) { file in
                    let saveTo = modSetting.homePath!.appendingPathComponent(file.fileName)
                    let data = GeoItem.Data(
                        id: file.id,
                        name: file.fileName,
                        link: file.downloadLink,
                        path: file.filePath,
                        saveTo: saveTo,
                        updateAt: Date(timeIntervalSince1970: file.updatedAt),
                        error: file.downloadError
                    )
                    GeoItem(data: data) { e in
                        file.updatedAt = FileModel.fileTime()
                        if let e = e {
                            file.downloadError = e.message
                        } else {
                            file.filePath = saveTo.path()
                        }
                    } onDelete: {
                        modelContext.delete(file)
                        // TODO: remove file.
                    }
                }
                .onMove(perform: moveItem)
            }
        } header: {
            HStack {
                Text("Geo List")
                Spacer()
                Button {
                    sheetGeoEditor = true
                } label: {
                    Label("New Geo", systemImage: "document.badge.plus.fill")
                        .labelStyle(.titleAndIcon)
                }
                Button {
                    selectLocalGeo()
                } label: {
                    Label("Add Local", systemImage: "externaldrive.fill.badge.plus")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .sheet(isPresented: $sheetGeoEditor) {
            GeoEditor() { data in
                let time = FileModel.fileTime()
                modelContext.insert(
                    FileModel(
                        fileName: data.filename,
                        filePath: nil,
                        fileType: FileModel.kFileTypeGeo,
                        createdAt: time,
                        updatedAt: time
                    )
                )
            } onDismiss: {
                sheetGeoEditor = false
            }
        }
    }
    
    private func selectLocalGeo() {
        self.openGetFiles().forEach { url in
            let name = url.lastPathComponent
            let time = FileModel.fileTime()
            let geo = FileModel(
                fileName: name,
                filePath: url.path(),
                fileType: FileModel.kFileTypeGeo,
                createdAt: time,
                updatedAt: time
            )
            modelContext.insert(geo)
        }
    }
    
    private func installRules() {
        if rules.count > 0 {
            return
        }
        RouteRuleModel.preset.forEach { ru in
            modelContext.insert(ru)
        }
    }
    
    private func onRuleRemoved(_ a: RouteRuleModel) {
        modelContext.delete(a)
    }
    
    private func onRuleEnabled(_ a: RouteRuleModel, _ enabled: Bool) {
        a.enabled = enabled
    }
    
    private func moveItem(from source: IndexSet, to destination: Int) {
        var rules0 = rules
        rules0.move(fromOffsets: source, toOffset: destination)
        handleIdx(rules0)
    }
    
    private func onEditorConfirm(_ a: Editor.Data) {
        if a.id.isEmpty {
            // create
            let mo = intoEditorMo(a)
            modelContext.insert(mo)
            // resort
            var rules = rules
            rules.insert(mo, at: 0)
            handleIdx(rules)
        } else {
            let idx = rules.firstIndex { $0.id == a.id }!
            rules[idx].name = a.name
            rules[idx].outboundTag = a.outboundTag
            rules[idx].enabled = true
            rules[idx].domain = a.domain
            rules[idx].ip = a.ip
            rules[idx].port = a.port
            rules[idx].network = a.network
            rules[idx].protocol0 = a.protocol
        }
    }
    
    private func handleIdx(_ rules: [RouteRuleModel]) {
        for (idx, it) in rules.enumerated() {
            it.idx = idx
        }
    }
    
    private func intoItemEditor(_ a: RuleItem.Data?) -> Editor.Data {
        guard let a = a else {
            return Editor.Data.empty()
        }
        return Editor.Data(
            id: a.key,
            name: a.name,
            domain: a.domain ?? "",
            ip: a.ip ?? "",
            port: a.port ?? "",
            network: a.network ?? "",
            protocol: a.protocol ?? "",
            outboundTag: a.outboundTag
        )
    }
    
    private func intoEditorMo(_ a: Editor.Data) -> RouteRuleModel {
        return RouteRuleModel(
            name: a.name,
            outboundTag: a.outboundTag,
            enabled: true,
            idx: 0,
            domain: a.domain.isEmpty ? nil : a.domain,
            ip: a.ip.isEmpty ? nil : a.ip,
            port: a.port.isEmpty ? nil : a.port,
            network: a.network.isEmpty ? nil : a.network,
            protocol0: a.protocol.isEmpty ? nil : a.protocol
        )
    }
    
    private func options() -> [Editor.Option] {
        return [
            Editor.Option(id: "1", title: "Proxy", value: CoreModel.kProxyTag),
            Editor.Option(id: "2", title: "Direct", value: CoreModel.kDirectTag),
            Editor.Option(id: "3", title: "Reject", value: CoreModel.kRejectTag)
        ]
    }
}

#Preview {
    SRoutePage()
}

fileprivate struct RuleItem: View {
    @State var rule: Data
    @State var enabled: Bool
    
    let onEdited: () -> Void
    let onEnabled: (Bool) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(rule.name).font(.headline).foregroundColor(.primary)
                Text(makeDescription()).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: {
                onEdited()
            }) {
                Image(systemName: "square.and.pencil")
            }
            Button(action: {
                onDelete()
            }) {
                Image(systemName: "trash.fill")
            }
            Divider()
            Toggle("", isOn: $enabled).toggleStyle(.switch).labelsHidden()
        }
        .buttonStyle(.accessoryBar)
        .padding(.all, 5)
        .onChange(of: enabled) { _, newValue in
            onEnabled(newValue)
        }
    }
    
    private func makeDescription() -> String {
        var str = ""
        if rule.domain != nil {
            str += "Domain: \(rule.domain!)\n"
        }
        if rule.ip != nil {
            str += "Ip: \(rule.ip!)\n"
        }
        if rule.port != nil {
            str += "Port: \(rule.port!)\n"
        }
        if rule.network != nil {
            str += "Network: \(rule.network!)\n"
        }
        if rule.`protocol` != nil {
            str += "Protocol: \(rule.`protocol`!)\n"
        }
        str += "OutboundTag: \(rule.outboundTag)"
        return str
    }
    
    struct Data: Codable {
        let key: String
        let name: String
        let outboundTag: String
        let domain: String?
        let ip: String?
        let port: String?
        let network: String?
        let `protocol`: String?
    }
}

fileprivate struct Editor: View {
    @State var data: Data
    
    let outboundTagOptions: [Option]
    
    let onConfirm: (Data) -> Void
    let onDismiss: () -> Void
    
    @State private var alertOpen = false
    @State private var alertError: String? = nil
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Rule Editor").font(.headline)
            Form {
                TextField("Rule Name", text: $data.name, prompt: Text("Example: Google"))
                Section("Rule") {
                    TextField("Domain", text: $data.domain, prompt: Text("domain:baidu.com, qq.com, geosite:cn"))
                    TextField("IP", text: $data.ip, prompt: Text("0.0.0.0/8,fc00::/7, geoip:cn"))
                    TextField("Port", text: $data.port, prompt: Text("53,443,1000-2000"))
                    TextField("Network", text: $data.network, prompt: Text("tcp,udp"))
                    TextField("Protocol", text: $data.protocol, prompt: Text("http, tls, bittorrent"))
                    Picker("Outbound Tag", selection: $data.outboundTag) {
                        ForEach(outboundTagOptions) { opt in
                            Text(opt.title).tag(opt.value)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .disableAutocorrection(true)
            .textFieldStyle(.automatic)
            
            HStack(alignment: .center) {
                Spacer()
                Button {
                    if data.name.isEmpty || data.outboundTag.isEmpty {
                        alertOpen = true
                        alertError = "name or outbound tag is empty"
                        return
                    }
                    onConfirm(data)
                    onDismiss()
                } label: {
                    Text("Confirm")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                }
                Spacer()
            }
            
            Spacer()
        }
        .padding(.all, 10)
        .alert("Error", isPresented: $alertOpen, actions: {
            Button("OK", role: .cancel) {
                alertOpen = false
                alertError = nil
            }
        }, message: {
            Text(alertError ?? "error")
        })
    }
    
    struct Data {
        var id: String
        var name: String
        var domain: String
        var ip: String
        var port: String
        var network: String
        var `protocol`: String
        var outboundTag: String
        
        static func empty() -> Self {
            return Data(id: "", name: "", domain: "", ip: "", port: "", network: "", protocol: "", outboundTag: "")
        }
    }
    
    struct Option: Identifiable {
        let id: String
        let title: String
        let value: String
    }
}

#Preview("Editor") {
    Editor(data: Editor.Data.empty(), outboundTagOptions: [], onConfirm: { _ in }, onDismiss: {})
}

fileprivate struct GeoItem: View {
    let data: Data
    let onDownloaded: (Error?) -> Void
    let onDelete: () -> Void
    
    @State private var progress: Double = 0.0
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text(data.name).font(.headline)
                if let link = data.link {
                    Text("Net Link: \(link)").font(.subheadline)
                }
                if let path = data.path {
                    Text("File Path: \(path)").font(.subheadline)
                }
                if (progress < 1.0) {
                    ProgressView(value: progress)
                }
                if let err = data.error {
                    Text("Error: \(err)").font(.subheadline).foregroundColor(.red)
                }
                Text("Latest: \(data.updateAt.formatted(date: .numeric, time: .standard))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            Divider()
            
            if (progress < 1.0) { // in downloading.
                IconButton(icon: "x.circle.fill") {
                    cancelDownload()
                }
            } else { // downloaded
                if (data.link != nil) { // re-downloading
                    IconButton(icon: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill") {
                        guard let url = URL(string: data.link!) else { return }
                        launchDownload(link: url)
                    }
                }
                IconButton(icon: "trash.fill") { onDelete() }
            }
        }
        .padding(.all, 5)
        .onAppear {
            if data.path != nil {
                progress = 1.0
            }
            launchDownloadIfNeed()
        }
    }
    
    private func launchDownloadIfNeed() {
        if data.link == nil { return }
        if data.path != nil { return }
        if data.error != nil { return }
        progress = data.path == nil ? 0.0 : 1.0
        guard let url = URL(string: data.link!) else { return }
        launchDownload(link: url)
    }
    
    @State private var downloadId = ""
    
    private func launchDownload(link: URL) {
        downloadId = DownloadManager.shared.download(link: link, saveTo: data.saveTo, override: true) { progress in
            self.progress = progress
        } onSaved: {
            self.onDownloaded(nil)
        } onError: { e in
            self.onDownloaded(e)
        }
    }
    
    private func cancelDownload() {
        DownloadManager.shared.cancel(id: downloadId)
    }
    
    struct Data: Identifiable {
        var id: String
        let name: String
        let link: String?
        let path: String?
        let saveTo: URL
        let updateAt: Date
        var error: String? = nil
    }
}

fileprivate struct GeoEditor: View {
    @State private var name: String = ""
    @State private var link: String = ""
    
    let onConfirm: (Data) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .center) {
            Text("New Geo").font(.headline)
            Form {
                TextField("File Name", text: $name, prompt: Text(""))
                TextField("File Link", text: $link, prompt: Text(""))
                    .onChange(of: link) { _, newValue in
                        name = newValue.components(separatedBy: "/").last ?? name
                    }
            }
            .formStyle(.grouped)
            
            Text("You can get it from https://github.com/Loyalsoldier/v2ray-rules-dat").font(.footnote)
            
            HStack(alignment: .center) {
                Spacer()
                Button {
                    if link.isEmpty {
                        return
                    }
                    let data = Data(filename: name, link: link)
                    onConfirm(data)
                    onDismiss()
                } label: {
                    Text("Confirm")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                }
                Spacer()
            }
            
            Spacer()
        }
    }
    
    struct Data {
        let filename: String
        let link: String
    }
}
