//
//  SInboundPage.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/22.
//

import SwiftUI

struct SInboundPage: View {
    @Environment(\.modCore) private var modCore
    
    @State private var editingHostOpen = false
    @State private var editingHost: HostData? = nil
    
    var body: some View {
        Form {
            @Bindable var m = modCore
            Section(header: Text("Inbound")) {
                TextField(text: $m.inPortHttp, prompt: Text(m.inPortHttp)) {
                    Text("HTTP Port")
                }
                TextField(text: $m.inPortSocks, prompt: Text(m.inPortSocks)) {
                    Text("SOCKS5 Port")
                }
                
                Toggle(isOn: $m.inAllowLAN) {
                    Text("Allow LAN")
                }
            }
            
            Section(header: Text("DNS")) {
                TextField(text: $m.dnsDirectIp, prompt: Text(m.dnsDirectIp)) {
                    Text("Direct IP")
                }
                TextField(text: $m.dnsProxyIp, prompt: Text(m.dnsProxyIp)) {
                    Text("Proxy IP")
                }
                Toggle(isOn: $m.dnsEnableFakeDNS) {
                    Text("Enable Fake DNS")
                }
            }
            
            Section {
                List {
                    let hosts = m.hosts.map { HostData($0) }
                    ForEach(hosts) { h in
                        HostItem(domain: h.domain, ip: h.ip, onEdit: {
                            editingHostOpen = true
                            editingHost = h
                        }, onRemove: {
                            onHostRemove(h)
                        })
                    }
                }
            } header: {
                HStack {
                    Text("DNS Hosts")
                    Spacer()
                    Button(action: {
                        editingHost = nil
                        editingHostOpen = true
                    }) {
                        Label("Add New Host", systemImage: "document.badge.plus.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .sheet(isPresented: $editingHostOpen) {
                let h = editingHost ?? HostData()
                HostEditor(domain: h.domain, ip: h.ip) { domain, ip in
                    onHostInsertOrUpdate(h, Host(domain: domain, ip: ip))
                } onDismiss: {
                    editingHostOpen = false
                    editingHost = nil
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func onHostRemove(_ a: HostData) {
        modCore.hosts.removeAll { h in h.domain == a.domain && h.ip == a.ip }
    }
    
    private func onHostInsertOrUpdate(_ old: HostData, _ new: Host) {
        if old.id != "new" {
            modCore.hosts.removeAll { h in h.domain == old.domain && h.ip == old.ip }
        }
        modCore.hosts.append(new)
    }
    
    private struct HostData: Identifiable {
        let id: String
        let domain: String
        let ip: String
        
        init(_ host: Host) {
            id = host.domain + host.ip
            domain = host.domain
            ip = host.ip
        }
        
        init() {
            id = "new"
            domain = ""
            ip = ""
        }
    }
}

#Preview {
    SInboundPage()
}


fileprivate struct HostItem: View {
    let domain: String
    let ip: String
    
    let onEdit: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            Text("\(domain) -> \(ip)")
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            
            Divider()
            
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil.tip.crop.circle").imageScale(.medium)
            }
            .buttonStyle(.borderless)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "trash.fill").imageScale(.medium)
            }
            .buttonStyle(.borderless)
        }
        .padding(.all, 5)
    }
}

#Preview {
    HostItem(domain: "127.0.0.12", ip: "127.3.4.5") {
        
    } onRemove: {
        
    }
    .frame(height: 30)
}


fileprivate struct HostEditor: View {
    @State var domain: String
    @State var ip: String
    
    let onConfirm: (_ domain: String, _ ip: String) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            Text("Host Editor").font(.title3)
            
            Form {
                VStack(alignment: .center) {
                    TextField("Domain", text: $domain, prompt: Text(domain))
                    TextField("IP", text: $ip, prompt: Text(ip))
                }
            }.formStyle(.grouped)
            
            HStack() {
                Spacer()
                Button("Confim") {
                    domain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
                    ip = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                    onConfirm(domain, ip)
                    onDismiss()
                }
                Button("Cancel") {
                    onDismiss()
                }
                Spacer()
            }
        }
        .padding(.all, 10)
    }
}

#Preview {
    HostEditor(domain: "127.3.2.4", ip: "213.23.4.5") { _, _ in
        
    } onDismiss: {
        
    }
}
