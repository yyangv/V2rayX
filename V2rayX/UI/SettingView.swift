//
//  SettingView.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/6.
//

import SwiftUI

struct SettingContentView: View {
    @State private var viewModel = SettingViewModel()
    
    private let pages = [
        Page(name: "General", icon: "gear") { AnyView(GeneralPage()) },
        Page(name: "Inbound", icon: "airplane.arrival") { AnyView(InboundPage()) },
        Page(name: "Outbound", icon: "airplane.departure") { AnyView(OutboundPage()) },
        Page(name: "Route", icon: "arrow.trianglehead.branch") { AnyView(RoutePage()) },
//        Page(name: "Core", icon: "engine.combustion.fill") { AnyView(CorePage()) },
        Page(name: "Log", icon: "chart.line.text.clipboard.fill") { AnyView(LogPage()) },
        Page(name: "Stats", icon: "waveform.path.ecg.rectangle.fill") { AnyView(StatsPage()) },
    ]
    
    @State private var selected: Page
    
    init() {
        selected = pages[0]
    }
    
    var body: some View {
        NavigationSplitView {
            List(pages, id: \.self, selection: $selected) { it in
                NavigationLink(value: it.name) {
                    Label(it.name, systemImage: it.icon)
                }
            }
        } detail: {
            selected.makeView()
        }
        .environment(viewModel)
    }
}

fileprivate struct Page: Hashable {
    let name: String
    let icon: String
    let makeView: () -> AnyView
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    static func == (lhs: Page, rhs: Page) -> Bool {
        return lhs.name == rhs.name
    }
}

#Preview("SettingContentView") {
    SettingContentView()
}

// MARK: - GeneralPage
fileprivate struct GeneralPage: View {
    @Environment(SettingViewModel.self) private var vm
    
    @AppStorage(STULaunchLogin) var autoLaunch: Bool = false
    @AppStorage(STUHomePath) var homePath: String = ""
    @AppStorage(STUActiveCore) var activeCore: String = ""

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $autoLaunch) {
                    Text("Auto Launch")
                }
                .onChange(of: autoLaunch) { _, enabled in
                    vm.enableAutoLaunch(enabled)
                }
            }
           
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Select Core Home Path").font(.headline)
                    Text(homePath).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Select") {
                    if let path = vm.openToGetDir() {
                        homePath = path
                    }
                }.buttonStyle(.bordered)
            }
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Select Core Binary").font(.headline)
                    Text(activeCore).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Select") {
                    if let path = vm.openToGetFile() {
                        activeCore = path
                    }
                }.buttonStyle(.bordered)
            }
        }.formStyle(.grouped)
    }
}

// MARK: - InboundPage
fileprivate struct InboundPage: View {
    @Environment(SettingViewModel.self) private var vm
    
    @AppStorage(STCInboundPortHTTP) var portHTTP: String = ""
    @AppStorage(STCInboundPortSOCKS) var portSOCKS: String = ""
    @AppStorage(STCInboundAllowLAN) var allowLAN: Bool = false

    @AppStorage(STCDNSHosts) var hosts: String = "" // parse using [Host]
    @AppStorage(STCDNSDirectIp) var dnsDirectIp: String = ""
    @AppStorage(STCDNSProxyIp) var dnsProxyIp: String = ""
    @AppStorage(STCDNSEnableFakeDNS) var dnsEnableFakeDNS: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Inbound")) {
                    TextField(text: $portHTTP, prompt: Text(portHTTP)) {
                        Text("HTTP Port")
                    }
                    TextField(text: $portSOCKS, prompt: Text(portSOCKS)) {
                        Text("SOCKS5 Port")
                    }
                    
                    Toggle(isOn: $allowLAN) {
                        Text("Allow LAN")
                    }
                }
                
                Section(header: Text("DNS")) {
                    NavigationLink {
                        HostTable(saved: into(hosts), onClose: onHostTableClose)
                    } label: {
                        Text("Hosts Editor")
                    }
                    TextField(text: $dnsDirectIp, prompt: Text(dnsDirectIp)) {
                        Text("Direct IP")
                    }
                    TextField(text: $dnsProxyIp, prompt: Text(dnsProxyIp)) {
                        Text("Proxy IP")
                    }
                    Toggle(isOn: $dnsEnableFakeDNS) {
                        Text("Enable Fake DNS")
                    }
                }
            }.formStyle(.grouped)
        }
    }
    
    private func onHostTableClose(newHosts: [HostTable.Item]) {
        let hosts = newHosts.map { h in
            DNSItem(host: h.host, address: h.address)
        }
        self.hosts = DNSItem.strings(hosts)
    }
    
    private func into(_ raws: String) -> [HostTable.Item] {
        return DNSItem.from(raws: raws).map { host in
            return HostTable.Item(host: host.host, address: host.address)
        }
    }
}

struct DNSItem {
    let host: String
    let address: String
    
    func string() -> String {
        return host + "<>" + address
    }
    
    static func from(raw: String) -> Self? {
        if raw.isEmpty { return nil }
        let components = raw.components(separatedBy: "<>")
        return Self(host: components[0], address: components[1])
    }
    
    static func from(raws: String) -> [Self] {
        if raws.isEmpty { return [] }
        return raws.split(separator: "\n").compactMap { from(raw: String($0)) }
    }
    
    static func strings(_ dns: [Self]) -> String {
        return dns.map { $0.string() }.joined(separator: "\n")
    }
}

fileprivate struct HostTable: View {
    @State private var rows: [Self.Item]
    @State private var editingRowId: UUID? = nil
    
    var onClose: (_ hosts: [Self.Item]) -> Void
    
    init(saved: [Self.Item], onClose: @escaping (_: [Self.Item]) -> Void) {
        let newSaved = saved + [Self.Item(host: "", address: "")]
        self.rows = newSaved
        self.onClose = onClose
    }
    
    var body: some View {
        Table(rows) {
            TableColumn("Domain") { row in
                if editingRowId == row.id {
                    TextField("Domain", text: Binding(
                        get: { row.host },
                        set: { newData in
                            if let index = rows.firstIndex(where: { $0.id == row.id }) {
                                rows[index].host = newData
                            }
                        }
                    ))
                    .textFieldStyle(SquareBorderTextFieldStyle())
                } else {
                    Text(row.host)
                }
            }
            TableColumn("Domain/IP") { row in
                if editingRowId == row.id {
                    TextField("Domain/IP", text: Binding(
                        get: { row.address },
                        set: { newData in
                            if let index = rows.firstIndex(where: { $0.id == row.id }) {
                                rows[index].address = newData
                            }
                        }
                    ))
                    .textFieldStyle(SquareBorderTextFieldStyle())
                } else {
                    Text(row.address)
                }
            }
            TableColumn("Operate") { row in
                HStack {
                    // 1. edit
                    if row.host != "" && row.id != editingRowId {
                        Button {
                            editingRowId = row.id
                            refresh()
                        } label: {
                            Image(systemName: "pencil.tiC.croC.circle")
                                .imageScale(.large)
                        }
                    }
                    
                    // 2. create
                    if row.host == "" {
                        Button {
                            let newRow = Self.Item(host: "-", address: "-")
                            rows.insert(newRow, at: rows.count - 1)
                            editingRowId = newRow.id
                        } label: {
                            Image(systemName: "pencil.tip.crop.circle.badge.plus")
                                .imageScale(.large)
                        }
                    }
                    
                    // 3. check
                    if row.id == editingRowId {
                        Button {
                            editingRowId = nil
                            refresh()
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .imageScale(.large)
                        }
                    }
                    
                    // 4. delete
                    if row.host != "" && row.id != editingRowId {
                        Button {
                            rows.removeAll(where: { $0.id == row.id })
                        } label: {
                            Image(systemName: "trash")
                                .imageScale(.large)
                        }
                    }
                }
            }
        }
        .onDisappear {
            onClose(rows.filter { $0.host != "" || $0.host != "-" })
        }
    }
    
    /// Refresh table.
    private func refresh() {
        rows = rows.map { $0 }
    }
    
    struct Item: Identifiable {
        let id = UUID()
        var host: String
        var address: String
        
        func toString() -> String {
            return "\(host):\(address)"
        }
    }
}


// MARK: - OutboundPage
fileprivate struct OutboundPage: View {
    @Environment(SettingViewModel.self) private var vm
    
    @AppStorage(STCOutboundEnableMux) var enableMux: Bool = false
    @AppStorage(STCOutboundMuxConcurrency) var muxConcurrency: String = ""
    @AppStorage(STCOutboundMuxXudpConcurrency) var muxXudpConcurrency: String = ""
    @AppStorage(STCOutboundMuxXudpProxyUDP443) var muxXudpProxyUDP443: String = ""
    
    @AppStorage(STUSubscriptionURL) var subscriptionURL: String = ""
    
    var body: some View {
        Form {
            Section("Subscription") {
                TextField(text: $subscriptionURL) {
                    Text("Subscription URL")
                }
            }
            
            Section(header: Text("Mux")) {
                Toggle(isOn: $enableMux) {
                    Text("Open Mux")
                }
                TextField(text: $muxConcurrency, prompt: Text("8")) {
                    Text("Concurrency")
                }
                TextField(text: $muxXudpConcurrency, prompt: Text("16")) {
                    Text("XUDP Concurrency")
                }
                TextField(text: $muxXudpProxyUDP443, prompt: Text("reject")) {
                    Text("XUDP 443")
                }
            }
        }.formStyle(.grouped)
    }
}


// MARK: - RoutePage
fileprivate struct RoutePage: View {
    @Environment(SettingViewModel.self) private var vm
    
    @AppStorage(STCRoutingDomainStrategy) var domainStrategy: String = ""
    @AppStorage(STURoutingRules) var raws: String = "" // include disabled. [UserRoutingRule]
    
    @State private var rules: [RuleItem.Data] = []

    @State private var editingRuleOpen = false // sheet
    @State private var editingRule: RuleItem.Data?
    
    var body: some View {
        Form {
            Section("Preference") {
                Picker("Domain Strategy", selection: $domainStrategy) {
                    Text("AsIs").tag("AsIs")
                    Text("IPIfNonMatch").tag("IPIfNonMatch")
                    Text("IPOnDemand").tag("IPOnDemand")
                }
            }
            Section("Rule List") {
                List {
                    ForEach($rules, id: \.key) { it in
                        RuleItem( rule: it ) { _ in
                            editingRule = it.wrappedValue
                            editingRuleOpen = true
                        } onEnabled: { _, _ in
                            saveRules()
                        } onDelete: { key in
                            rules.removeAll(where: { $0.key == key })
                            saveRules()
                        }
                    }
                    .onMove(perform: moveItem)
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    editingRule = nil
                    editingRuleOpen = true
                }) {
                    Label("Add New Rule", systemImage: "document.badge.plus.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .onAppear {
            loadRules()
        }
        .sheet(isPresented: $editingRuleOpen) {
            RuleEditor(
                data: editorData(),
                outboundTagOptions: [
                    RuleEditor.Option(id: "1", title: OutboundProxyTag, value: OutboundProxyTag),
                    RuleEditor.Option(id: "2", title: OutboundDirectTag, value: OutboundDirectTag),
                    RuleEditor.Option(id: "3", title: OutboundRejectTag, value: OutboundRejectTag)
                ]
            ) { data in
                onRuleEditorConfirm(data)
            } onDismiss: {
                editingRuleOpen = false
                editingRule = nil
            }
        }
    }
    
    private func loadRules() {
        let userRules: [UserRoutingRule] = jsonDecode(raws) ?? []
        rules = userRules.map { RuleItem.Data(
            key: $0.key,
            name: $0.name,
            domain: $0.domain,
            ip: $0.ip,
            port: $0.port,
            network: $0.network,
            protocol: $0.protocol,
            outboundTag: $0.outboundTag,
            enabled: $0.enabled
        ) }
    }
    
    private func onRuleEditorConfirm(_ data: RuleEditor.Data) {
        if editingRule == nil { // creat new
            let a = editor2Item(data)
            rules.append(a)
        } else { // modify
            let a = editingRule
            let idx = rules.firstIndex(where: { $0.key == a!.key })
            rules[idx!] = editor2Item(data)
        }
        saveRules()
    }
    
    private func editor2Item(_ a: RuleEditor.Data) -> RuleItem.Data {
        return RuleItem.Data(
            key: UUID().uuidString,
            name: a.name,
            domain: a.domain != "" ? a.domain : nil,
            ip: a.ip != "" ? a.ip : nil,
            port: a.port != "" ? a.port : nil,
            network: a.network != "" ? a.network : nil,
            protocol: a.protocol != "" ? a.protocol : nil,
            outboundTag: a.outboundTag,
            enabled: true
        )
    }
    
    private func editorData() -> RuleEditor.Data {
        if editingRule == nil {
            return RuleEditor.Data(
                name: "",
                domain: "",
                ip: "",
                port: "",
                network: "",
                protocol: "",
                outboundTag: OutboundProxyTag
            )
        } else {
            return RuleEditor.Data(
                name: editingRule!.name,
                domain: editingRule!.domain ?? "",
                ip: editingRule!.ip ?? "",
                port: editingRule!.port ?? "",
                network: editingRule!.network ?? "",
                protocol: editingRule!.protocol ?? "",
                outboundTag: editingRule!.outboundTag
            )
        }
    }
    
    private func saveRules() {
        let userRules = rules.map { a in
            return UserRoutingRule(
                key: a.key,
                name: a.name,
                outboundTag: a.outboundTag,
                enabled: a.enabled,
                domain: a.domain,
                ip: a.ip,
                port: a.port,
                network: a.network,
                protocol: a.protocol
            )
        }
        self.raws = jsonEncode(userRules, formatting: .withoutEscapingSlashes)
    }
    
    private func moveItem(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        saveRules()
    }
    
    private struct RuleItem: View {
        @Binding var rule: Data
        
        let onEdited: (_ key: String) -> Void
        let onEnabled: (_ key: String, _ enabled: Bool) -> Void
        let onDelete: (_ key: String) -> Void
        
        @State private var showSheet: Bool = false

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(rule.name).font(.headline).foregroundColor(.primary)
                    Text(makeDescription()).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    showSheet = true
                }) {
                    Image(systemName: "square.and.pencil")
                }
                Button(action: {
                    onDelete(rule.key)
                }) {
                    Image(systemName: "trash.fill")
                }
                Divider()
                Toggle("", isOn: $rule.enabled).toggleStyle(.switch).labelsHidden()
            }
            .buttonStyle(.accessoryBar)
            .onChange(of: rule.enabled) { _, newValue in  onEnabled(rule.key, newValue)}
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
            var domain: String?
            var ip: String?
            var port: String?
            var network: String?
            var `protocol`: String?
            var outboundTag: String
            
            var enabled: Bool
        }
    }
    
    private struct RuleEditor: View {
        @State var data: Data
        let outboundTagOptions: [Option]
        let onConfirm: (_ data: Data) -> Void
        let onDismiss: () -> Void
        
        var body: some View {
            VStack(alignment: .center) {
                Form {
                    TextField("Rule Name", text: $data.name, prompt: Text("Google"))
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
                            return
                        }
                        onConfirm(data)
                        onDismiss()
                    } label: {
                        Text("Confirm")
                    }
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
            var name: String
            var domain: String
            var ip: String
            var port: String
            var network: String
            var `protocol`: String
            var outboundTag: String
        }
        
        struct Option: Identifiable {
            let id: String
            let title: String
            let value: String
        }
    }
}

struct UserRoutingRule: Codable {
    let key: String
    let name: String
    let domain: String?
    let ip: String?
    let port: String?
    let network: String?
    let `protocol`: String?
    let outboundTag: String
    let enabled: Bool
    
    init(
        key: String,
        name: String,
        outboundTag: String,
        enabled: Bool,
        domain: String? = nil,
        ip: String? = nil,
        port: String? = nil,
        network: String? = nil,
        `protocol`: String? = nil
    ) {
        self.key = key
        self.name = name
        self.domain = domain
        self.ip = ip
        self.port = port
        self.network = network
        self.`protocol` = `protocol`
        self.outboundTag = outboundTag
        self.enabled = enabled
    }
    
    func into() -> RoutingRule {
        let a = self
        return RoutingRule(
            ruleTag: a.name,
            outboundTag: a.outboundTag,
            domain: a.domain != nil ? a.domain?.components(separatedBy: ",") : nil,
            ip: a.ip != nil ? a.ip?.components(separatedBy: ",") : nil,
            port: a.port,
            sourcePort: nil,
            network: a.network,
            source: nil,
            inboundTag: nil,
            attrs: nil,
            balancerTag: nil,
            protocol: a.protocol != nil ? a.protocol?.components(separatedBy: ",") : nil
        )
    }
}


// MARK: - CorePage

fileprivate struct CorePage: View {
    private let kFileGroup = "Core"
    
    @Environment(SettingViewModel.self) private var vm
    
    @AppStorage(STUActiveCore) var coreSelect: String = "" // include disabled rules. string

    @State private var files: [FileItem.Info] = [] // cores
    
    @State private var sheetNewCore = false
    @State private var sheetCoreName = ""
    @State private var sheetCoreLink = ""
    
    var body: some View {
        Form {
            Picker("Select Core", selection: $coreSelect) {
                ForEach(files, id: \.self.key) { f in
                    Text(f.name).tag(f.path)
                }
            }
            
            ForEach($files, id: \.key) { file in
                FileItem(
                    file: file) { info in // delete
                        vm.deleteFile(info.key)
                    } onDownload: { info in
                        self.download(info)
                    } onDownloadCancel: { info in
                        vm.cancelDownload(info.key)
                    }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    sheetNewCore = true
                }) {
                    Label("Add New Core", systemImage: "document.badge.plus.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    sheetNewCore = true
                }) {
                    Label("Add New Core", systemImage: "document.badge.plus.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .sheet(isPresented: $sheetNewCore) {
            NewCoreSheet { name, link in
                self.addNewCore(name: name, link: link)
            }
        }
        
        .onAppear {
            load()
        }
    }
    
    private func load() {
        let files = vm.listFiles(group: kFileGroup)
        self.files = files.map { f in
            return FileItem.Info(
                key: f.id,
                name: f.name,
                group: f.group,
                link: f.link,
                path: f.path,
                error: f.error != nil ? V2Error(f.error!) : nil,
                updated_at: f.updated_at,
                created_at: f.created_at,
                progress: nil
            )
        }
    }
    
    private func addNewCore(name: String, link: String) {
        let file = FileItem.Info(
            key: UUID().uuidString,
            name: name,
            group: kFileGroup,
            link: link
        )
        self.files.append(file)
    }

    private func download(_ file: FileItem.Info) {
        _ =  vm.downloadFile(
            group: kFileGroup,
            link: file.link!
        ) { progress in
            let idx = self.findFileIndex(file.key)
            self.files[idx].progress = progress
        } onSaved: { url in
            let idx = self.findFileIndex(file.key)
            self.files[idx].progress = 1.0
            self.files[idx].path = url.path
            let ts = Date().timeIntervalSince1970
            self.files[idx].created_at = ts
            self.files[idx].updated_at = ts
        } onError: { e in
            let idx = self.findFileIndex(file.key)
            self.files[idx].error = e
        }
    }
    
    private func findFileIndex(_ key: String) -> Int {
        return files.firstIndex { $0.key == key }!
    }
    
    
    private struct NewCoreSheet: View {
        @State private var name: String = ""
        @State private var link: String = ""
        
        let onConfirm: (_ name: String, _ link: String) -> Void
        
        var body: some View {
            VStack(alignment: .center, spacing: 10) {
                TextField("Core Name", text: $name)
                TextField("Core Download Link", text: $link)
                Button {
                    onConfirm(name, link)
                } label: {
                    Text("Confirm")
                }
            }.padding(16)
        }
    }
    
    private struct NewCoreGithubSheet: View {
        @State private var filename: String = ""
        @State private var owner: String = ""
        @State private var repo: String = ""
        
        let onConfirm: (_ owner: String, _ repo: String, _ filename: String) -> Void
        
        var body: some View {
            VStack(alignment: .center, spacing: 10) {
                Form {
                    TextField("Github Owner", text: $owner)
                    TextField("Github Repo", text: $repo)
                    TextField("Filename", text: $filename)
                }
                Spacer()
                Button {
                    onConfirm(owner, repo, filename)
                } label: {
                    Text("Confirm")
                }
            }
        }
    }
}

fileprivate struct FileItem: View {
    @Binding var file: FileItem.Info
    
    let onDelete: (_ file: FileItem.Info) -> Void
    let onDownload: (_ file: FileItem.Info) -> Void
    let onDownloadCancel: (_ file: FileItem.Info) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(file.name).font(.headline).lineLimit(1).truncationMode(.tail)
                
                if checkOK() {
                    if file.error != nil {
                        Text("Error: \(file.error?.localizedDescription ?? "")")
                            .font(.subheadline).lineLimit(1).truncationMode(.tail)
                    } else {
                        VStack {
                            Text(file.path!).font(.subheadline).lineLimit(1).truncationMode(.tail)
                            Text(toDateString(file.updated_at!))
                                .font(.subheadline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                } else {
                    ProgressView(value: file.progress)
                }
            }
            
            Spacer()

            Divider()
            
            if checkOK() {
                Button {
                    onDownload(file)
                } label: {
                    Image(systemName: "icloud.and.arrow.down.fill") // update file
                }
                Button {
                    onDelete(file)
                } label: {
                    Image(systemName: "trash.fill") // delete it
                }
            } else if file.error != nil {
                Button {
                    onDownload(file)
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill") // try again
                }
            } else {
                Button {
                    onDownloadCancel(file)
                } label: {
                    Image(systemName: "xmark.circle.fill") // cancel download
                }
            }
        }
        .onAppear {
            if file.path == nil && file.link != nil {
                onDownload(file)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func reUpdate() {
        file.progress = 1.0
        file.error = nil
        file.path = nil
        onDownload(file)
    }
    
    private func checkOK() -> Bool {
        return file.path != nil
    }
    
    private func toDateString(_ ts: Double) -> String {
        let date = Date(timeIntervalSince1970: ts)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    struct Info {
        let key: String
        let name: String
        let group: String
        
        var link: String?
        var path: String?
        var error: Error?
        var updated_at: Double?
        var created_at: Double?
        var progress: Double?
    }
}


// MARK: - LogPage

fileprivate struct LogPage: View {
    @Environment(SettingViewModel.self) private var vm
    
    @AppStorage(STCLogEnableAccess) var enableAccess: Bool = false
    @AppStorage(STCLogEnableError) var enableError: Bool = false
    @AppStorage(STCLogLevel) var level: String = ""
    @AppStorage(STCLogEnableDNS) var enableDNS: Bool = false
    @AppStorage(STCLogEnableMaskAddress) var enableMaskAddress: Bool = false

    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enableAccess) {
                    Text("Enable Access Log")
                }
                Toggle(isOn: $enableError) {
                    Text("Enable Error Log")
                }
                Toggle(isOn: $enableDNS) {
                    Text("Enable DNS Log")
                }
            }
            
            Section {
                Picker("Log Level", selection: $level) {
                    Text("Info").tag("info")
                    Text("Debug").tag("debug")
                    Text("Warning").tag("warning")
                    Text("Error").tag("error")
                    Text("None").tag("none")
                }
                Toggle(isOn: $enableMaskAddress) {
                    Text("Enable Mask Address")
                }
            }
        }.formStyle(.grouped)
    }
}

// MARK: - StatsPage

fileprivate struct StatsPage: View {
    @Environment(SettingViewModel.self) private var vm
    
    @AppStorage(STCStatsEnable) var enableStats: Bool = false
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enableStats) {
                    Text("Enable Stats")
                }
            }
        }.formStyle(.grouped)
    }
}
