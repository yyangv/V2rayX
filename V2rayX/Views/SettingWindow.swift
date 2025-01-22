//
//  SettingWindow.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/22.
//

import SwiftUI

struct SettingWindow: View {
    @State private var selected: Page
    private let pages: [Page] = [
        Page(name: "General", icon: "gear") { SGeneralPage() },
        Page(name: "Inbound", icon: "airplane.arrival") { SInboundPage() },
        Page(name: "Outbound", icon: "airplane.departure") { SOutboundPage() },
        Page(name: "Route", icon: "arrow.trianglehead.branch") { SRoutePage() },
//        Page(name: "About", icon: "info.circle") { SAboutPage() },
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
        .modelContainer(for: [
            RouteRuleModel.self,
            FileModel.self
        ])
    }
}

#Preview {
    SettingWindow()
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
