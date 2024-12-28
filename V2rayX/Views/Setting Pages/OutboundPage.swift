//
//  SOutboundPage.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/27.
//

import SwiftUI

struct SOutboundPage: View {
    @Environment(SettingModel.self) private var mo
    
    var body: some View {
        @Bindable var m = mo
        Form {
            Section("Subscription") {
                TextField(text: $m.subscriptionURL, prompt: Text("")) {
                    Text("Subscription URL")
                }
            }
            
            Section(header: Text("Mux")) {
                Toggle(isOn: $m.ouEnableMux) {
                    Text("Open Mux")
                }
                TextField(text: $m.ouMuxConcurrency, prompt: Text("8")) {
                    Text("Concurrency")
                }
                TextField(text: $m.ouMuxXudpConcurrency, prompt: Text("16")) {
                    Text("XUDP Concurrency")
                }
                TextField(text: $m.ouMuxXudpProxyUDP443, prompt: Text("reject")) {
                    Text("XUDP 443")
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SOutboundPage()
}
