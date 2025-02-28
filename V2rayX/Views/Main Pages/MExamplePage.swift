//
//  MExamplePage.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/2/28.
//

import SwiftUI

struct MExamplePage: View {
    var body: some View {
        Form {
            ButtonItemWithDescription
        }
        .formStyle(.grouped)
    }
    
    private var ButtonItemWithDescription: some View {
        Section {
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text("ButtonItemWithDescription").font(.headline)
                    Text("""
This item view is a example for button with description.
This item view is a example for button with description.
""").font(.subheadline)
                }
                Spacer()
                Button {
                } label: {
                    Label("Click", systemImage: "square.and.arrow.up.fill")
                }
                .buttonStyle(.automatic)
            }
        }
    }
    
    private var B: some View {
        Section {
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text("ButtonItemWithDescription").font(.headline)
                    Text("""
This item view is a example for button with description.
This item view is a example for button with description.
""").font(.subheadline)
                }
                Spacer()
                Button {
                } label: {
                    Label("Click", systemImage: "square.and.arrow.up.fill")
                }
                .buttonStyle(.automatic)
            }
        }
    }
}

#Preview {
    MExamplePage()
}
