//
//  SCorePage.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/27.
//

import SwiftUI

struct SCorePage: View {
    @Environment(SettingModel.self) private var mo
    
    @State private var version: String = ""
    @State private var netVersion: String? = nil
    
    var body: some View {
        @Bindable var m = mo
        Form {
            Section("Core") {
                VStack {
                    TextField("Bin Path", text: $m.coreActivePath, prompt: Text("You can print manually!"))
                        .onChange(of: m.coreActivePath) { _, _ in loadLocalVersion() }
                    HStack {
                        if !version.isEmpty {
                            Text(version).foregroundColor(.secondary)
                        }
                        Image(systemName: "arrow.right").foregroundColor(.green)
                        if netVersion != nil {
                            Text(netVersion!).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                TextField("Github Owner", text: $m.coreGithubOwner, prompt: Text(m.coreGithubOwner))
                TextField("Github Repository", text: $m.coreGithubRepo, prompt: Text(m.coreGithubRepo))
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    if let url = openToGetURL(useFile: true) {
                        m.coreActivePath = url.path()
                    }
                }) {
                    Label("Select Core Path", systemImage: "document.badge.plus.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .onAppear {
            loadLocalVersion()
            loadNetVersion()
        }
    }
    
    private func loadLocalVersion() {
        if mo.coreActivePath.isEmpty {
            version = ""
            return
        }
        let url = URL(fileURLWithPath: mo.coreActivePath)
        DispatchQueue.main.async {
            self.version = Utils.shared.getCoreVersion(url) ?? ""
        }
    }
    
    private func loadNetVersion() {
        DispatchQueue.main.async {
            Utils.shared.fetchGithubLatestVersion(owner: mo.coreGithubOwner, repo: mo.coreGithubRepo) { v, _ in
                self.netVersion = v
            }
        }
    }
}

#Preview {
    SCorePage()
}


// MARK: - Core Item

fileprivate struct Item: View {
    @State var data: Data

    let onSelect: (String) -> Void
    let onRemove: (String) -> Void
    let onEdit: (String) -> Void
    let onGetLocalVersion: (String, (String)->Void) -> Void
    let onGetNetVersion: (String, @escaping (String?)->Void) -> Void
    
    @State private var localVersion: String = ""
    @State private var netVersion: String? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.green)
                .opacity(data.active ? 1 : 0).padding(.leading, 6)
            
            VStack(alignment: .leading) {
                Text(data.name).font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(data.path).foregroundColor(.secondary)
                    .lineLimit(1)
                Text("version: \(localVersion)").foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if netVersion != nil {
                VStack(alignment: .center) {
                    Text(netVersion!).foregroundColor(.secondary)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }
            
            Divider()
            
            Button {
                onSelect(data.id)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.medium)
                
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 10)
            
            Button {
                onEdit(data.id)
            } label: {
                Image(systemName: "square.and.pencil.circle.fill")
                    .imageScale(.medium)
                
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 10)
            
            Button {
                onRemove(data.id)
            } label: {
                Image(systemName: "trash.circle.fill")
                    .imageScale(.medium)
                
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 10)
        }
        .onAppear {
            onGetNetVersion(data.id) { netVersion = $0 }
            onGetLocalVersion(data.id) { localVersion = $0 }
        }
    }
    
    struct Data {
        let id: String
        let name: String
        let path: String
        let active: Bool
    }
}

#Preview {
    let data = Item.Data(
        id: "id", name: "xray-core", path: "/path/to/core", active: true
    )
    Item(
        data: data,
        onSelect: { _ in },
        onRemove: { _ in },
        onEdit: { _ in },
        onGetLocalVersion: { id, cb in
            cb("v1.0.0")
        },
        onGetNetVersion: { id, cb in
            cb("v1.0.1")
        }
    )
}

// MARK: - Core Editor

fileprivate struct Editor: View {
    @State var data: Data
    @State private var way: Way = .none
    
    let onConfirm: (_ data: Data) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .center) {
            Form {
                TextField("Core Name", text: $data.name, prompt: Text("Google"))
                
                Section("Select Core") {
                    if way == .path || way == .none {
                        TextField("Print Path", text: $data.path, prompt: Text(data.path))
                            .onChange(of: data.path) { _, _ in
                                way = .path
                            }
                    }
                    if way == .select || way == .none {
                        HStack(alignment: .center) {
                            Text("Select Core Binary").font(.headline)
                            Spacer()
                            Button("Select") {
                                if let url = openToGetURL(useFile: true) {
                                    data.path = url.path()
                                }
                            }.buttonStyle(.bordered)
                        }
                    }
                }
                .disabled(!data.path.isEmpty)
                
                Section("Check Update by Github") {
                    TextField("Github Owner", text: $data.githubRepo, prompt: Text(""))
                    TextField("Github Repository", text: $data.githubOwner, prompt: Text(""))
                }
            }
            .formStyle(.grouped)
            .disableAutocorrection(true)
            .textFieldStyle(.automatic)
            
            HStack(alignment: .center) {
                Spacer()
                Button {
                    if data.name.isEmpty || data.path.isEmpty {
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
        .onAppear {
            if !data.path.isEmpty {
                way = .path
            }
        }
    }
    
    struct Data {
        var id: String
        var name: String
        var path: String
        
        var githubOwner: String
        var githubRepo: String
        
        static func empty() -> Self {
            Self(id: "", name: "", path: "", githubOwner: "", githubRepo: "")
        }
    }
    
    private enum Way { case path, select, none }
}

#Preview {
    let data = Editor.Data(id: "", name: "", path: "", githubOwner: "", githubRepo: "")
    Editor(data: data) { data in
        
    } onDismiss: {
        
    }
}
