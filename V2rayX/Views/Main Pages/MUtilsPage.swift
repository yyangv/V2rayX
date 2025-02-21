//
//  MUtilsPage.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/23.
//

import SwiftUI

struct MUtilsPage: View {
    var body: some View {
        Form {
            HStack {
                Text("Clear System Proxy")
                Spacer()
                Button {
                    clearProxy()
                } label: {
                    Label("Clear", systemImage: "eraser.line.dashed.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func clearProxy() {
        Task { await SystemProxy.shared.clear() }
    }
}

#Preview {
    MUtilsPage()
}
