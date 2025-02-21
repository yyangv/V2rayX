//
//  SAboutPage.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/22.
//

import SwiftUI

struct SAboutPage: View {
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            
            Text("V2rayX").font(.title)
            Text("V2rayX is a free and open source v2ray proxy app for macOS.")
            
            Text("Storage Usage").font(.title3).padding(.top, 20)
            Text("""
V2rayx use UserDefaults as Preference Storage and SwiftData as Data Storage:
UserDefaults Locaton: ~/Library/Preferences/com.yangyang.V2rayX(.debug).plist
SwiftData Locaton: ~/Library/Containers/com.yangyang.V2rayX(--CoreRunner)
""")
            
            Spacer()
        }
    }
}

#Preview {
    SAboutPage()
}
