//
//  SOutboundPage.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/27.
//

import SwiftUI

struct SOutboundPage: View {
    @Environment(\.modCore) private var modCore
    @Environment(\.modNodes) private var modNodes
    
    var body: some View {
        @Bindable var mCore = modCore
        @Bindable var mNode = modNodes
        Form {
            Section("Subscription") {
                TextField(text: $mNode.subscriptionLink, prompt: Text("https://.....")) {
                    Text("Subscription URL")
                }
            }
            
            
            Section(header: Text("Mux")) {
                Toggle(isOn: $mCore.ouEnableMux) {
                    Text("Open Mux")
                }
                TextField(text: $mCore.ouMuxConcurrency, prompt: Text("8")) {
                    Text("Concurrency")
                }
                TextField(text: $mCore.ouMuxXudpConcurrency, prompt: Text("16")) {
                    Text("XUDP Concurrency")
                }
                TextField(text: $mCore.ouMuxXudpProxyUDP443, prompt: Text("reject")) {
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
