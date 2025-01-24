//
//  SGeneralPage.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/22.
//

import SwiftUI

struct SGeneralPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingModel.self) private var modSetting
    @Environment(CoreModel.self) private var modCore
    
    @State private var errorAlertOpen = false
    @State private var errorAlertMessage = ""
    
    var body: some View {
        Form {
            SystemSection
            CoreSection
            CoreLogSection
            CoreStatsSection
        }
        .alert("Error", isPresented: $errorAlertOpen, actions: {
            Button("OK", role: .cancel) {
                errorAlertOpen = false
                errorAlertMessage = ""
            }
        }, message: {
            Text(errorAlertMessage)
        })
        .formStyle(.grouped)
    }
    
    
    private var SystemSection: some View {
        Section(header: Text("System")) {
            @Bindable var m = modSetting
            Section {
                Toggle(isOn: $m.enableLoginLaunch) {
                    Text("Enable Auto Launch")
                }
                .onChange(of: m.enableLoginLaunch) { _, enabled in
                    onEnableLoginLaunch(enabled)
                }
            }
            
            Section {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Select Home Path").font(.headline)
                        Text(m.homePath?.path() ?? "").font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    let t = m.homePath != nil ? "Change" : "Select"
                    Button(t) { onSelectHome() }
                        .buttonStyle(.bordered)
                }
            }
            
            Section {
                HStack(alignment: .center) {
                    Text("Reset All Setting").font(.headline)
                    Spacer()
                    Button {
                        clearUserDefaults()
                        modelContext.container.deleteAllData()
                        NSApp.terminate(nil)
                    } label: {
                        Label("Reset", systemImage: "trash.fill")
                    }
                }
            }
        }
    }
    
    @State private var version: String = ""
    @State private var netVersion: String? = nil
    @State private var sheetCoreSelect = false
    
    private var CoreSection: some View {
        
        Section {
            if (modCore.corePath.isEmpty) {
                Text("No Core").font(.headline)
            } else {
                VStack(alignment: .leading) {
                    HStack {
                        Text(modCore.coreName).font(.headline)
                        Divider()
                        HStack {
                            if !version.isEmpty {
                                Text(version).font(.subheadline).foregroundColor(.secondary)
                            }
                            Image(systemName: "arrow.right").foregroundColor(.green)
                            if netVersion != nil {
                                Text(netVersion!).font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    HStack {
                        Text(modCore.corePath)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("github: \(modCore.coreGithub)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            HStack {
                Text("Core")
                Spacer()
                Button {
                    sheetCoreSelect = true
                } label: {
                    let title = modCore.corePath.isEmpty ? "New Core" : "Change Core"
                    Label(title, systemImage: "document.badge.plus.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .sheet(isPresented: $sheetCoreSelect, content: {
            CoreSelector { info in
                modCore.coreName = info.name
                modCore.corePath = info.path
                modCore.coreGithub = info.github
                
                loadLocalVersion()
                loadNetVersion()
            } onDismiss: {
                sheetCoreSelect = false
            }
        })
        .onAppear {
            loadLocalVersion()
            loadNetVersion()
        }
    }
    
    private var CoreLogSection: some View {
        Section(header: Text("Core Log")) {
            @Bindable var m = modCore
            Section {
                Toggle(isOn: $m.logEnableAccess) {
                    Text("Enable Access Log")
                }
                Toggle(isOn: $m.logEnableError) {
                    Text("Enable Error Log")
                }
                Toggle(isOn: $m.logEnableDNS) {
                    Text("Enable DNS Log")
                }
            }
            
            Section {
                Picker("Log Level", selection: $m.logLevel) {
                    Text("Info").tag("info")
                    Text("Debug").tag("debug")
                    Text("Warning").tag("warning")
                    Text("Error").tag("error")
                    Text("None").tag("none")
                }
                Toggle(isOn: $m.logEnableMaskAddress) {
                    Text("Enable Mask Address")
                }
            }
        }
    }
    
    
    private var CoreStatsSection: some View {
        Section(header: Text("Core Stats")) {
            @Bindable var m = modCore
            Section {
                Toggle(isOn: $m.statsEnabled) {
                    Text("Enable Stats")
                }
            }
        }
    }
    
    private func onEnableLoginLaunch(_ enabled: Bool) {
        if enabled {
            modSetting.registerLoginLaunch(error(_:))
        } else {
            modSetting.unregisterLoginLaunch(error(_:))
        }
    }
    
    private func onSelectHome() {
        if let url = self.openToGetURL() {
            modSetting.homePath = url
        }
    }
    
    private func error(_ e: Error?) {
        if let e = e {
            errorAlertMessage = e.message
            errorAlertOpen = true
        }
    }
    
    private func loadLocalVersion() {
        modCore.fetchLocalCoreVersion { v in
            if let v = v {
                version = v
            }
        }
    }
    
    private func loadNetVersion() {
        modCore.fetchNetVersion { v in
            netVersion = v
        }
    }
    
    private func clearUserDefaults() {
        let store = UserDefaults.standard
        store.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        store.synchronize()
    }
}

#Preview {
    SGeneralPage()
}

fileprivate struct CoreSelector: View {
    @State private var name: String = ""
    @State private var path: String = ""
    @State private var github: String = ""
    
    let onConfirm: (CoreInfo) -> Void
    let onDismiss: () -> Void
    
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Select Core").font(.headline)
            Form {
                TextField("Name", text: $name, prompt: Text("xray_v24.12.31"))
                HStack {
                    TextField("Core Path", text: $path, prompt: Text("Print Path"))
                    Divider()
                    Button(action: {
                        if let url = openToGetURL(useFile: true) {
                            path = url.path()
                        }
                    }) {
                        Label("Select", systemImage: "document.badge.plus.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                }
                TextField("Github Info", text: $github, prompt: Text("xtls/xray-core"))
            }
            .formStyle(.grouped)
            .disableAutocorrection(true)
            .textFieldStyle(.automatic)
            
            HStack(alignment: .center) {
                Spacer()
                Button {
                    onConfirm(CoreInfo(name: name, path: path, github: github))
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
    }
    
    struct CoreInfo {
        let name: String
        let path: String
        let github: String
    }
}

#Preview("Core Selector") {
    CoreSelector { info in
        
    } onDismiss: {
        
    }
}
