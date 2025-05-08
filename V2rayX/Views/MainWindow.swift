//
//  MainWindow.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/23.
//

import SwiftUI

struct MainWindow: View {
    private let pages: [Page] = [
        Page(name: "Utils", icon: "wrench.and.screwdriver.fill") { MUtilsPage() },
        Page(name: "Debug", icon: "ladybug.fill") { MDebugPage() },
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
    MainWindow()
}
