//
//  SettingContentView.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/27.
//

import SwiftUI
import SwiftData

struct SettingContentView: View {
    @Environment(SettingModel.self) private var settingModel
    
    @State private var selected: Page
    private let pages: [Page] = [
        Page(name: "General", icon: "gear") { GeneralPage() },
        Page(name: "Core", icon: "engine.combustion.fill") { SCorePage() },
        Page(name: "Inbound", icon: "airplane.arrival") { SInboundPage() },
        Page(name: "Outbound", icon: "airplane.departure") { SOutboundPage() },
        Page(name: "Route", icon: "arrow.trianglehead.branch") { SRoutePage() },
        Page(name: "Log", icon: "chart.line.text.clipboard.fill") { LogPage() },
        Page(name: "Stats", icon: "waveform.path.ecg.rectangle.fill") { StatsPage() },
    ]
    
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
            AnyView(selected.makeView())
        }
        .environment(settingModel)
        .modelContainer(for: [
            RouteRuleModel.self,
        ])
    }
}

#Preview {
    SettingContentView()
}

fileprivate struct Page: Hashable {
    let name: String
    let icon: String
    let makeView: () -> any View
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    static func == (lhs: Page, rhs: Page) -> Bool {
        return lhs.name == rhs.name
    }
}

func openToGetURL(useFile: Bool = false) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = useFile
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.urls.first {
        return url
    }
    return nil
}

// MARK: - General Page

struct GeneralPage: View {
    @Environment(SettingModel.self) private var m
    
    var body: some View {
        Form {
            Section {
                @Bindable var m = m
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
                    Button(t) { openToGetFile() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func openToGetFile() {
        if let url = openToGetURL() {
            m.homePath = url
        }
    }

    private func onEnableLoginLaunch(_ enabled: Bool) {
        if enabled {
            Utils.shared.registerLoginLaunch()
        } else {
            Utils.shared.unregisterLoginLaunch()
        }
    }
}

#Preview {
    GeneralPage()
}

// MARK: - Log Page

fileprivate struct LogPage: View {
    @Environment(SettingModel.self) private var setting
    
    var body: some View {
        @Bindable var m = setting
        Form {
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
        }.formStyle(.grouped)
    }
}

#Preview {
    LogPage()
}

// MARK: - Stats Page

struct StatsPage: View {
    @Environment(SettingModel.self) private var setting
    
    var body: some View {
        @Bindable var m = setting
        Form {
            Section {
                Toggle(isOn: $m.statsEnabled) {
                    Text("Enable Stats")
                }
            }
        }.formStyle(.grouped)
    }
}

#Preview {
    StatsPage()
}
