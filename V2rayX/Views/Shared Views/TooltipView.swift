//
//  TooltipView.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import SwiftUI


extension View {
    func toolTip(_ toolTip: String?) -> some View {
        self.overlay(TooltipView(toolTip))
    }
}

fileprivate struct TooltipView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = MyView()
        view.toolTip = self.toolTip
        view.layer?.backgroundColor = CGColor.black
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    typealias NSViewType = NSView
    
    let toolTip: String?
    
    init(_ toolTip: String?) {
        self.toolTip = toolTip
    }
    
    class MyView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }
    }
}
