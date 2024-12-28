//
//  PopoverContentView.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/27.
//

import SwiftUI
import SwiftData

struct PopoverContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(SettingModel.self) private var settingModel
    
    @State private var errorAlertOpen = false
    @State private var errorAlertMessage = ""
    
    @State private var nodeConn: [String: Int] = [:] // link->ms
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Toolbar.frame(height: 50)
            if settingModel.links.count > 0 {
                NodeList
            } else {
                VStack(alignment: .center, spacing: 5) {
                    Spacer()
                    Text("Open Setting Window to complete the configuration")
                    Spacer()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 5)
        .alert2("Error", isPresented: $errorAlertOpen) {
            Button("OK") {
                errorAlertOpen = false
            }
        } message: {
            Text(errorAlertMessage)
        }
        .frame(width: 300, height: 500)
    }
    
    @State private var isPlaying: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var isTestRTing: Bool = false
    
    private var Toolbar: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("V2rayX")
                .font(.system(size: 13, weight: .black))
            
            Spacer()
            
            // Start.
            Button {
                if isPlaying {
                    stop()
                    isPlaying = false
                } else {
                    start { e in errorOrSucess(e) {
                        isPlaying = true
                    }}
                }
            } label: {
                Image(systemName: "play.circle.fill").imageScale(.large)
                    .foregroundStyle(isPlaying ? .green : .primary)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Start running!")
            
            
            // Refresh subscribe list.
            Button {
                if isRefreshing {
                    return
                }
                isRefreshing = true
                syncSubscription { e in
                    defer {
                        isRefreshing = false
                    }
                    errorOrSucess(e) { }
                }
            } label: {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                    .imageScale(.large).foregroundStyle(isRefreshing ? .green : .primary)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Update subscribe list.")
            
            // Test RT
            Button {
                if isTestRTing {
                    return
                }
                isTestRTing = true
                testconnectivity {
                    isTestRTing = false
                }
            } label: {
                Image(systemName: "timer.circle.fill").imageScale(.large)
                    .foregroundStyle(isTestRTing ? .green : .primary)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Ping nodes.")
            
            Divider()
            
            // Open Main Scene
            Button {
                openWindow(id: "main")
            } label: {
                Image(systemName: "macwindow")
                    .imageScale(.large)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Open main window.")
            
            // Open Preference Scene
            Button {
                openWindow(id: "settings")
            } label: {
                Image(systemName: "gearshape.fill")
                    .imageScale(.large)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Open preference window.")
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power.circle.fill")
                    .imageScale(.large)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Close App")
        }
        .padding([.top, .horizontal], 10)
    }
    
    private var NodeList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 5) {
                let list = settingModel.links
                ForEach(list.indices, id: \.self) { idx in
                    let link = list[idx]
                    let data = intoNode(link, activeLink: settingModel.activeLink, idx: idx, rt: nodeConn[link])
                    Item(data: data, onSelected: onNodeSelected(_:), onRemoved: onNodeRemoved(_:))
                }
            }
        }
    }
    
    private func onNodeSelected(_ link: String) {
        settingModel.activeLink = link
        if isPlaying {
            stop()
            start { e in errorOrSucess(e) {}}
        }
    }
    
    private func onNodeRemoved(_ link: String) {
        settingModel.links.removeAll { $0 == link }
        if link == settingModel.activeLink {
            settingModel.activeLink = ""
            stop()
        }
    }
    
    private func start(_ complete: @escaping (Error?)->Void) {
        do {
            let m = settingModel
            let core = m.coreActivePath
            let link = m.activeLink
            let home = m.homePath
            if core.isEmpty {
                throw V2Error("Core is not set.")
            }
            if link.isEmpty {
                throw V2Error("Node is not set.")
            }
            if home == nil {
                throw V2Error("Home path is not set.")
            }
            
            let corePath = URL(fileURLWithPath: core)
            
            if !Utils.shared.detectBinaryExecutable(corePath) {
                Utils.shared.openSystemSettingSecurity()
                throw V2Error("Core is not executable.")
            }
            
            let configPath = home!.appending(path: "config.json")
            let config = try collectConfig(link: link)
            let configData = try XrayConfigBuilder.shared.buildConfig(config: config)
            try Utils.shared.write(path: configPath, data: configData, override: true)
            
            CoreRunner.shared.start(bin: corePath, config: configPath) { e in
                if let e = e {
                    complete(e)
                    return
                }
                
                let h = "127.0.0.1"
                let hp = m.inPortHttp
                let sp = m.inPortSocks
                Utils.shared.registerSystemProxyWithSave(hh: h, hp: hp, sh: h, sp: sp)
            }
        } catch {
            complete(error)
        }
    }
    
    private func stop() {
        CoreRunner.shared.stop()
        Utils.shared.restoreSystemProxy()
    }
    
    private func syncSubscription(_ cb: @escaping (Error?)->Void) {
        let link = settingModel.subscriptionURL
        if link.isEmpty {
            cb(V2Error("Subscription URL is not set."))
            return
        }
        let url = URL(string: link)!
        Task {
            do {
                let raw = try await fetchSubscription(url: url)
                var links = raw.components(separatedBy: "\n")
                links.removeAll { $0.isEmpty }
                settingModel.links = links
                cb(nil)
            } catch {
                cb(error)
            }
        }
    }
    
    private func testconnectivity(_ complete: @escaping ()->Void) {
        let links = settingModel.links
        var total = 0
        var count = 0
        
        for i in 0..<links.count {
            let link = links[i]
            
            if !link.starts(with: "vless://") {
                continue
            }
            total += 1
            let (host, ip) = getServerAddress(link)
            Utils.shared.measureRTVless(host: host, port: ip) { ms in
                DispatchQueue.main.async {
                    nodeConn[link] = ms
                    
                    count += 1
                    if total == count {
                        complete()
                    }
                }
            }
        }
    }
    
    private func intoNode(_ link: String, activeLink: String, idx: Int, rt: Int?) -> Item.Data {
        let name = link.components(separatedBy: "#")[1]
        let protocol0 = link.components(separatedBy: "://")[0]
        return Item.Data(
            id: link,
            headline: name,
            subheadline: protocol0,
            selected: activeLink == link,
            useDark: idx % 2 == 0,
            rt: rt
        )
    }
    
    // MARK: - Utils
    
    private func errorOrSucess(_ e: Error?, success: ()->Void) {
        if let e = e {
            errorAlertMessage = e.message
            errorAlertOpen = true
            return
        }
        success()
    }
    
    private func collectConfig(link: String) throws -> XrayConfig {
        let m = settingModel
        
        guard let homePath = m.homePath else {
            throw V2Error("home path not set")
        }
        
        let container = try ModelContainer(for: RouteRuleModel.self)
        let rules = try container.mainContext.fetch(FetchDescriptor<RouteRuleModel>(
            sortBy: [ .init(\.idx, order: .forward) ]
        )).map { $0.into() }
        
        let config = XrayConfig(
            log: XrayConfig.Log(
                enableAccess: m.logEnableAccess,
                accessPath: homePath.appendingPathComponent("access.log").path,
                enableError: m.logEnableError,
                errorPath: homePath.appendingPathComponent("error.log").path,
                level: m.logLevel,
                enableDNS: m.logEnableDNS,
                enableMaskAddress: m.logEnableMaskAddress
            ),
            dns: XrayConfig.DNS(
                hosts: m.hosts.map { ($0.domain, $0.ip) },
                directIp: m.dnsDirectIp,
                proxyIp: m.dnsProxyIp,
                enableFakeDNS: m.dnsEnableFakeDNS
            ),
            inbound: XrayConfig.Inbound(
                portHTTP: Int(m.inPortHttp)!,
                portSOCKS: Int(m.inPortSocks)!,
                allowLAN: m.inAllowLAN
            ),
            outbound: XrayConfig.Outbound(
                link: link,
                enableMux: m.ouEnableMux,
                muxConcurrency: Int(m.ouMuxConcurrency)!,
                muxXudpConcurrency: Int(m.ouMuxXudpConcurrency)!,
                muxXudpProxyUDP443: m.ouMuxXudpProxyUDP443
            ),
            routing: XrayConfig.Routing(
                domainStrategy: m.domainStrategy,
                rules: rules
            ),
            stats: XrayConfig.Stats(enable: m.statsEnabled)
        )
        return config
    }
    
    private func fetchSubscription(url: URL) async throws -> String {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let base64 = String(data: data, encoding: .utf8),
               let decoded = Data(base64Encoded: base64) {
                if let str = String(data: decoded, encoding: .utf8) {
                    let result = str.removingPercentEncoding ?? str
                    return result
                } else {
                    throw V2Error("Failed to decode the response")
                }
            } else {
                throw V2Error("Failed to decode the response")
            }
        } catch {
            throw V2Error(error.localizedDescription)
        }
    }
    
    private func getServerAddress(_ link: String) -> (String, UInt16) {
        let s0 = link.firstIndex(of: "@")!
        let s = link.index(s0, offsetBy: 1)
        let e = link.firstIndex(of: "?")!
        let address = link[s..<e]
        let part = address.components(separatedBy: ":")
        let host = part[0]
        let port = part[1]
        return (host, UInt16(port)!)
    }
}

#Preview {
    PopoverContentView()
}

// MARK: - Item View

fileprivate struct Item: View {
    let data: Data
    
    let onSelected: (_ key: String) -> Void
    let onRemoved: (_ key: String) -> Void
    
    @State private var scale: CGFloat = 1
    
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.green)
                .opacity(data.selected ? 1 : 0).padding(.leading, 6)
            
            VStack(alignment: .leading) {
                Text(data.headline).font(.system(size: 12, weight: .semibold))
                    .frame(minWidth: 50)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(data.subheadline).foregroundColor(.secondary)
                    .font(.system(size: 10, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            if let rt = data.rt {
                Text("\(rt)ms")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Button {
                onRemoved(data.id)
            } label: {
                Image(systemName: "trash")
                    .imageScale(.medium)
                
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 10)
        }
        .frame(height: 35)
        .background(
            data.useDark ? Color("list_bg_dark") : Color("list_bg_light")
        )
        .cornerRadius(5)
        .scaleEffect(scale)
        .animation(.spring(response: 0.5, dampingFraction: 0.5), value: scale)
        .onTapGesture {
            startAnimation()
            onSelected(data.id)
        }
    }
    
    private func startAnimation() {
        scale = 0.9
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scale = 1
        }
    }
    
    struct Data: Identifiable {
        let id: String
        let headline: String
        let subheadline: String
        var selected: Bool
        var useDark: Bool
        var rt: Int?
    }
}

// MARK: - Alert View

extension View {
    fileprivate func alert2<A, B>(
        _ title: String,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: @escaping () -> A,
        @ViewBuilder message: @escaping () -> B
    ) -> some View where A: View, B: View {
        ZStack {
            self
            if isPresented.wrappedValue {
                Alert(title: title, actions: actions, message: message)
            }
        }
    }
}

fileprivate struct Alert<A, B>: View where A: View, B: View {
    let title: String
    @ViewBuilder let actions: ()->A
    @ViewBuilder let message: ()->B
    
    var body: some View {
        Group {
            VStack {
                Text("⚠️").font(.system(size: 58, weight: .black))
                    .padding(.bottom, 5)
                Text(title).font(.headline)
                
                message()
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
                
                Divider()
                
                HStack {
                    actions()
                        .buttonStyle(AlertButtonStyle())
                }
            }
            .frame(width: 220)
            .padding(12)
            .background(.windowBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.secondary, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 2, y: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground.opacity(0.5))
    }
    
    private struct AlertButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(width: 200)
                .padding(.vertical, 6)
                .background(.tint)
                .foregroundColor(.white)
                .cornerRadius(6)
        }
    }
}

#Preview("Alert") {
    @Previewable @State var open = false
    
    VStack {
        Button("Open") {
            open = true
        }
    }
    .alert2("Title", isPresented: $open, actions: {
        Button("OK") {
            open.toggle()
        }
    }, message: {
        Text("This is a very long message, A long message will wrap to multiple lines.")
    })
    .frame(width: 300, height: 300, alignment: .center)
}


// MARK: - ToolTip Extension

extension View {
    /// Overlays this view with a view that provides a toolTip with the given string.
    fileprivate func toolTip(_ toolTip: String?) -> some View {
        self.overlay(TooltipView(toolTip))
    }
}

fileprivate struct TooltipView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = MyView()
        view.toolTip = self.toolTip
        view.layer?.backgroundColor = CGColor.black
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    typealias NSViewType = NSView
    
    let toolTip: String?

    init(_ toolTip: String?) {
        self.toolTip = toolTip
    }
    
    class MyView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }
    }
}
