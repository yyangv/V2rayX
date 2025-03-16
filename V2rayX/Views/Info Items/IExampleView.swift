//
//  IExampleView.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/3/1.
//

import SwiftUI

struct IExampleView: View {
    var body: some View {
        HStack {
            
        }
        .frame(width: 500, height: 300)
    }
}

#Preview {
    IExampleView()
}

fileprivate struct Item: View {
    private var trafficDownlink: Int = 0

    var body: some View {
        Text("")
    }
}
