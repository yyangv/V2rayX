//
//  SRoutePage.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/27.
//

import SwiftUI
import SwiftData

struct SRoutePage: View {
    @Environment(\.modelContext) private var modelCtx
    @Environment(SettingModel.self) private var settingModel
    
    @Query(sort: \RouteRuleModel.idx, order: .forward) private var rules: [RouteRuleModel]
    
    @State private var editingRuleOpen = false // sheet
    @State private var editingRule: Item.Data? = nil
    
    var body: some View {
        @Bindable var m = settingModel
        Form {
            Section("Preference") {
                Picker("Domain Strategy", selection: $m.domainStrategy) {
                    Text("AsIs").tag("AsIs")
                    Text("IPIfNonMatch").tag("IPIfNonMatch")
                    Text("IPOnDemand").tag("IPOnDemand")
                }
            }
            Section("Rule List") {
                List {
                    
                    ForEach(rules) { it in
                        let data = Item.Data(
                            key: it.name,
                            name: it.name,
                            outboundTag: it.outboundTag,
                            domain: it.domain,
                            ip: it.ip,
                            port: it.port,
                            network: it.network,
                            protocol: it.protocol0
                        )
                        Item(rule: data, enabled: it.enabled) {
                            editingRule = data
                            editingRuleOpen = true
                        } onEnabled: { enabled in
                            onRuleEnabled(it, enabled)
                        } onDelete: {
                            onRuleRemoved(it)
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
        .sheet(isPresented: $editingRuleOpen) {
            let data = intoItemEditor(editingRule)
            let options = options()
            Editor(data: data, outboundTagOptions: options, onConfirm: onEditorConfirm) {
                editingRuleOpen = false
                editingRule = nil
            }
        }
        .onAppear {
            installRules()
        }
    }
    
    private func installRules() {
        if rules.count > 0 {
            return
        }
        RouteRuleModel.presetRuleModels.forEach { ru in
            modelCtx.insert(ru)
        }
    }
    
    private func onRuleRemoved(_ a: RouteRuleModel) {
        modelCtx.delete(a)
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
        if a.id.isEmpty { // create
            let mo = intoEditorMo(a)
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
    
    // MARK: - Utils
    
    private func handleIdx(_ rules: [RouteRuleModel]) {
        for (idx, it) in rules.enumerated() {
            it.idx = idx
        }
    }
    
    private func intoItemEditor(_ a: Item.Data?) -> Editor.Data {
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
            domain: a.domain,
            ip: a.ip,
            port: a.port,
            network: a.network,
            protocol0: a.protocol
        )
    }
    
    private func options() -> [Editor.Option] {
        return [
            Editor.Option(id: "1", title: OutboundProxyTag, value: OutboundProxyTag),
            Editor.Option(id: "2", title: OutboundDirectTag, value: OutboundDirectTag),
            Editor.Option(id: "3", title: OutboundRejectTag, value: OutboundRejectTag)
        ]
    }
}

#Preview {
    SRoutePage()
}


// MARK: - Rule Item

fileprivate struct Item: View {
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

// MARK: - Rule Editor

fileprivate struct Editor: View {
    @State var data: Data
    
    let outboundTagOptions: [Option]
    
    let onConfirm: (Data) -> Void
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
