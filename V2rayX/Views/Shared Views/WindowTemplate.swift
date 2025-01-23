//
//  WindowTemplate.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/23.
//

import SwiftUI

struct WindowTemplate: View {
    let pages: [Page]
    @State private var selected: Page
    
    init(pages: [Page]) {
        self.pages = pages
        self.selected = pages[0]
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
    }
}

struct Page: Hashable {
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
