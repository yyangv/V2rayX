//
//  SettingWindow.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/22.
//

import SwiftUI

struct SettingWindow: View {
    private let pages: [Page] = [
        Page(name: "General", icon: "gear") { SGeneralPage() },
        Page(name: "Inbound", icon: "airplane.arrival") { SInboundPage() },
        Page(name: "Outbound", icon: "airplane.departure") { SOutboundPage() },
        Page(name: "Route", icon: "arrow.trianglehead.branch") { SRoutePage() },
//        Page(name: "About", icon: "info.circle") { SAboutPage() },
    ]
    
    var body: some View {
        WindowTemplate(pages: pages)
            .modelContainer(for: [
                RouteRuleModel.self,
                FileModel.self
            ])
    }
}

#Preview {
    SettingWindow()
}
