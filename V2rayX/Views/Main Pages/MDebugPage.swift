//
//  MDebugPage.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/5/8.
//

import SwiftUI

struct MDebugPage: View {
    @Environment(CoreModel.self) private var modCore
    @Environment(SettingModel.self) private var modSetting
    
    @State private var alert = false
    @State private var alertMessage: String?
    
    var body: some View {
        Form {
            HStack {
                VStack(alignment: .leading) {
                    Text("Launch With Debug Config File")
                    Text("Put config_debug.json file into .v2rayx directory.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Start") {
                    launchWithDebugFile()
                }
                Button("Shutdown") {
                    shutdownWithDebugFile()
                }
            }
        }
        .formStyle(.grouped)
        .alert("Info", isPresented: $alert, actions: {
            Button("OK", role: .cancel) {
                alert = false
                alertMessage = nil
            }
        }, message: {
            Text(alertMessage ?? "")
        })
    }
    
    private func launchWithDebugFile() {
        Task {
            let configURL = appHomeDirectory().appending(path: "config_debug.json")
            do {
                try await modCore.run(configURL: configURL)
                modCore.isRunning = true
                alertMessage = "Start running with debug config file."
                alert = true
            } catch {
                DispatchQueue.main.async {
                    alertMessage = error.localizedDescription
                    alert = true
                }
            }
        }
    }
    
    private func shutdownWithDebugFile() {
        Task {
            await modCore.stop()
            modCore.isRunning = false
        }
    }
}

#Preview {
    MDebugPage()
}
