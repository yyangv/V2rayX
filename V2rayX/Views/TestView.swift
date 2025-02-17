//
//  TestView.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/22.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        VStack {
            VStack {
                Text("Hello, World! World!")
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 100, height: 200)
        }
        .frame(width: 200, height: 300)
    }
}

#Preview {
    TestView()
}
