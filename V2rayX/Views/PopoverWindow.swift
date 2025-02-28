//
//  PopoverWindow.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import SwiftUI
import SwiftData

struct PopoverWindow: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @Environment(SettingModel.self) private var modSetting
    @Environment(NodesModel.self) private var modNodes
    @Environment(CoreModel.self) private var modCore
    
    @State private var alertMessage: String? = nil

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Toolbar
                .frame(height: 50)
            if modNodes.links.count > 0 {
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
        .alert2("Error", data: $alertMessage) {
            Button("OK") {
                alertMessage = nil
            }
        } message: { message in
            Text(message)
        }
        .frame(width: 300, height: 500)
    }
    
    @State private var isPlay: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var isTestRTing: Bool = false
    
    private var Toolbar: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("V2rayX")
                .lineLimit(1)
                .font(.system(size: 13, weight: .black))
            
            Spacer()
            
            // Start.
            Button {
                if isPlay {
                    isPlay = false
                    stop()
                } else {
                    isPlay = true
                    start { e in
                        errorOrSuccess(e, fail: { isPlay = false })
                    }
                }
            } label: {
                Image(systemName: "play.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(isPlay ? .green : .primary)
            }
            .buttonStyle(PlainButtonStyle())
            .toolTip("Start running!")
            
            // Test RT
            Button {
                if isTestRTing {
                    return
                }
                isTestRTing = true
                testResponseTime {
                    isTestRTing = false
                }
            } label: {
                Image(systemName: "timer.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(isTestRTing ? .green : .primary)
            }
            .buttonStyle(PlainButtonStyle())
            .toolTip("Ping nodes.")
            
            // Refresh subscribe list.
            Button {
                if isRefreshing {
                    return
                }
                isRefreshing = true
                syncSubscription { e in
                    errorOrSuccess(e, finally: { isRefreshing = false })
                }
            } label: {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                    .imageScale(.large).foregroundStyle(isRefreshing ? .green : .primary)
            }
            .buttonStyle(PlainButtonStyle())
            .toolTip("Update subscribe list.")
            
            Divider()
            
            // Open Main Scene
            Button {
                openWindowAndActive(id: "Main")
            } label: {
                Image(systemName: "macwindow")
                    .imageScale(.large)
            }
            .buttonStyle(PlainButtonStyle())
            .toolTip("Open main window.")
            
            // Open Preference Scene
            Button {
                openWindowAndActive(id: "Setting")
            } label: {
                Image(systemName: "gearshape.fill")
                    .imageScale(.large)
            }
            .buttonStyle(PlainButtonStyle())
            .toolTip("Open preference window.")
            
            Button {
                closeApp()
            } label: {
                Image(systemName: "power.circle.fill")
                    .imageScale(.large)
            }
            .buttonStyle(PlainButtonStyle())
            .toolTip("Close App")
        }
        .padding([.top, .horizontal], 10)
        .onAppear {
            runAutoUpdate()
        }
    }
    
    @State private var nodes: [NodeItemView.Data] = []
    
    private var NodeList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 5) {
                ForEach(modNodes.links.indices, id: \.self) { idx in
                    let link = modNodes.links[idx]
                    let active = modNodes.activeLink
                    let rt = modNodes.nodeRTs[link]
                    let data = mapNode(link: link, active: active, idx: idx, rt: rt)
                    NodeItemView(data: data, onSelected: onNodeSelected(id:), onRemoved: onNodeRemoved(id:))
                }
            }
        }
    }
    
    private func mapNode(link: String, active: String, idx: Int, rt: Int?) -> NodeItemView.Data {
        let name = link.components(separatedBy: "#")[1]
        let protocol0 = link.components(separatedBy: "://")[0]
        return NodeItemView.Data(
            id: link,
            name: name,
            protocol0: protocol0,
            selected: active == link,
            useDark: idx % 2 == 0,
            rt: rt
        )
    }
    
    private func runAutoUpdate() {
        if !modSetting.enableAutoUpdateAndTest {
            return
        }
        if !modNodes.nodeRTs.isEmpty {
            return
        }
        if modNodes.links.isEmpty {
            return
        }
        isRefreshing = true
        syncSubscription { e in
            isRefreshing = false
            if e == nil {
                isTestRTing = true
                testResponseTime {
                    isTestRTing = false
                }
            }
        }
    }
    
    private func onNodeSelected(id: String) {
        let link = id
        modNodes.activeLink = link
        if isPlay {
            stop { start { e in errorOrSuccess(e) } }
        }
    }
    
    private func onNodeRemoved(id: String) {
        modNodes.links.removeAll { $0 == id }
        if id == modNodes.activeLink {
            modNodes.activeLink = ""
            stop()
        }
    }
    
    private func start(_ onCompleted: @escaping (Error?)->Void) {
        Task {
            let activeLink = modNodes.activeLink
            if activeLink.isEmpty {
                onCompleted(V2Error.message("Node is not set."))
                return
            }
            
            let homeURL = appHomeDirectory()
            let logAccessURL = homeURL.appendingPathComponent("access.log")
            let logErrorURL = homeURL.appendingPathComponent("error.log")
            let configURL = homeURL.appending(path: "config.json")
            
            do {
                let container = SwiftDataHelper.createModelContainer(for: RouteRuleModel.self)
                let rules = try container.mainContext.fetch(FetchDescriptor<RouteRuleModel>(
                    sortBy: [ .init(\.idx, order: .forward) ]
                ))
                
                try await modCore.run(
                    activeLink: activeLink,
                    logAccessURL: logAccessURL,
                    logErrorURL: logErrorURL,
                    configURL: configURL,
                    rules: rules
                )
            } catch V2Error.binaryUnexecutable {
                onCompleted(V2Error.message("Core binary is not executable."))
                openSystemSettingSecurity()
            } catch {
                onCompleted(error)
            }
        }
    }
    
    private func stop(_ onCompleted: @escaping ()->Void = {}) {
        Task {
            await modCore.stop()
            onCompleted()
        }
    }
    
    private func closeApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func openWindowAndActive(id: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: id)
    }
    
    private func syncSubscription(_ cb: @escaping (Error?)->Void) {
        Task {
            do {
                try await modNodes.syncSubscription()
                modNodes.nodeRTs.removeAll()
                if !modNodes.links.contains(where: { $0 == modNodes.activeLink }) {
                    modNodes.activeLink = ""
                    alertMessage = "The active node is not in the newest node list."
                }
            } catch {
                cb(error)
                return
            }
            cb(nil)
        }
    }
    
    private func testResponseTime(_ cb: @escaping ()->Void) {
        Task {
            await modNodes.testNodeResponseTime()
            cb()
        }
    }
    
    private func errorOrSuccess(_ e: Error?, fail: ()->Void = {}, success: ()->Void = {}, finally: ()->Void = {}) {
        if let e = e {
            alertMessage = e.message
            fail()
        } else {
            success()
        }
        finally()
    }
    
    private func openSystemSettingSecurity() {
        let alert = NSAlert()
        alert.messageText = "Unable to run the xray-core program"
        alert.informativeText = "The application has been blocked from running. Please open System Preferences > Security & Privacy > General and allow this app to run."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Go to Settings")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?General") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

#Preview {
    PopoverWindow()
}

// MARK: - NodeItem View

fileprivate struct NodeItemView: View {
    let data: Data
    
    let onSelected: (_ id: String) -> Void
    let onRemoved: (_ id: String) -> Void
    
    @State private var scale: CGFloat = 1
    
    @State private var titleTruncationMode: Text.TruncationMode = .tail
    
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.green)
                .opacity(data.selected ? 1 : 0).padding(.leading, 6)
            
            VStack(alignment: .leading) {
                Text(data.name).font(.system(size: 12, weight: .semibold))
                    .frame(minWidth: 50)
                    .lineLimit(1)
                    .truncationMode(titleTruncationMode)
                    .onHover { isHover in
                        titleTruncationMode = isHover ? .head : .tail
                    }
                
                Text(data.protocol0).foregroundColor(.secondary)
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
        let name: String
        let protocol0: String
        var selected: Bool
        var useDark: Bool
        var rt: Int?
    }
}


// MARK: - Alert View

extension View {
    fileprivate func alert2<A, B, C>(
        _ title: String,
        data: Binding<Optional<C>>,
        @ViewBuilder actions: @escaping () -> A,
        @ViewBuilder message: @escaping (_ data: C) -> B
    ) -> some View where A: View, B: View {
        ZStack {
            self
            if let data = data.wrappedValue {
                Alert(title: title, data: data, actions: actions, message: message)
            }
        }
    }
}

fileprivate struct Alert<A, B, C>: View where A: View, B: View {
    let title: String
    let data: C
    @ViewBuilder let actions: ()->A
    @ViewBuilder let message: (_ data: C)->B
    
    var body: some View {
        Group {
            VStack {
                Text("⚠️").font(.system(size: 58, weight: .black))
                    .padding(.bottom, 5)
                Text(title).font(.headline)
                
                message(data)
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
    @Previewable @State var message: String? = nil
    
    VStack {
        Button("Open") {
            message = "This is a very long message, A long message will wrap to multiple lines."
        }
    }
    .alert2("Title", data: $message, actions: {
        Button("OK") {
            message = nil
        }
    }, message: { data in
        Text("This is a very long message, A long message will wrap to multiple lines.")
    })
    .frame(width: 300, height: 300, alignment: .center)
}
