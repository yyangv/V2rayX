//
//  TestView.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/22.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        Form {
            Section {
                
            } header: {
                HStack {
                    Text("Core")
                    Spacer()
                    Button {
                        
                    } label: {
                        Label("Select", systemImage: "document.badge.plus.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
            } footer: {
                
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    TestView()
}
