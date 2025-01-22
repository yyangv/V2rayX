//
//  Button.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/20.
//

import SwiftUI

struct IconButton: View {
    let icon: String
    let text: String? = nil
    @MainActor let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if let text = text {
                Label(text, systemImage: icon).labelStyle(.titleAndIcon)
            } else {
                Image(systemName: icon)
            }
        }
        .buttonStyle(.borderless)
    }
}
