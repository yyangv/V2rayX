//
//  PopoverWindow.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/11.
//

import SwiftUI
import Combine

struct PopoverContentView: View {
    @Environment(\.openWindow) private var openWindow
    
    @State private var viewModel = PopoverContentViewModel()
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Toolbar.frame(height: 50)
            if viewModel.items.count > 0 {
                NodeList
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Spacer()
                    Text("Open Setting Window: ")
                    Text("1. Select Home and Core.")
                    Text("2. Print Subscription Link.")
                    Text("3. Other Preferences.")
                    Spacer()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 5)
        .frame(width: 300, height: 500)
    }
    
    @State private var isRefreshing: Bool = false
    @State private var isTestRTing: Bool = false
    
    @State private var errorAlertOpen = false
    @State private var errorAlertMessage = ""
    
    private var Toolbar: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("V2rayX")
                .font(.system(size: 13, weight: .black))
            
            Spacer()
            
            // Start.
            Button {
                if viewModel.isPlaying {
                    viewModel.stop()
                } else {
                    viewModel.start { e in
                        if e != nil {
                            errorAlertMessage = e!.message
                            errorAlertOpen = true
                        }
                    }
                }
            } label: {
                Image(systemName: "play.circle.fill").imageScale(.large)
                    .foregroundStyle(viewModel.isPlaying ? .green : .primary)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Start running!")
            
            
            // Refresh subscribe list.
            Button {
                if isRefreshing {
                    return
                }
                isRefreshing = true
                viewModel.syncSubscription { e in
                    if e != nil {
                        errorAlertMessage = e!.message
                        errorAlertOpen = true
                    }
                    isRefreshing = false
                    viewModel.loadItems()
                }
            } label: {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                    .imageScale(.large).foregroundStyle(isRefreshing ? .green : .primary)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Update subscribe list.")
            
            // Test RT
            Button {
                if isTestRTing {
                    return
                }
                isTestRTing = true
                viewModel.testconnectivity {
                    isTestRTing = false
                }
            } label: {
                Image(systemName: "timer.circle.fill").imageScale(.large)
                    .foregroundStyle(isTestRTing ? .green : .primary)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Ping nodes.")
            
            Divider()
            
            // Open Main Scene
            Button {
                openWindow(id: "main")
            } label: {
                Image(systemName: "macwindow")
                    .imageScale(.large)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Open main window.")
            
            // Open Preference Scene
            Button {
                openWindow(id: "settings")
            } label: {
                Image(systemName: "gearshape.fill")
                    .imageScale(.large)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Open preference window.")
            
            Button {
                viewModel.taskBeforeShutdown()
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power.circle.fill")
                    .imageScale(.large)
            }.buttonStyle(PlainButtonStyle())
                .toolTip("Close App")
        }
        .padding([.top, .horizontal], 10)
        .alert("Error", isPresented: $errorAlertOpen) {
            Button("OK") {
                errorAlertOpen = false
            }
        } message: {
            Text(errorAlertMessage)
        }
        .onAppear {
            viewModel.loadItems()
        }
    }
    
    private var NodeList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 5) {
                ForEach(Array(viewModel.items.enumerated()), id: \.offset) { i, it in
                    Item(
                        key: it.key,
                        headline: it.headline,
                        subheadline: it.subheadline,
                        selected: it.selected,
                        useDark: i % 2 == 0,
                        trailingOK: it.trailingOk
                    ) { key in
                        viewModel.onItemSelected(key) { e in if e != nil {
                            errorAlertMessage = e!.message
                            errorAlertOpen = true
                        }}
                    } onRemoved: { key in
                        viewModel.onItemRemoved(key)
                    }
                }
            }
        }
    }
}

// MARK: - Item View

fileprivate struct Item: View {
    let key: String
    let headline: String
    let subheadline: String
    let selected: Bool
    let useDark: Bool
    let trailingOK: Bool?
    
    let onSelected: (_ key: String) -> Void
    let onRemoved: (_ key: String) -> Void
    
    @State private var scale: CGFloat = 1
    
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.green)
                .opacity(selected ? 1 : 0).padding(.leading, 6)
            
            VStack(alignment: .leading) {
                Text(headline).font(.system(size: 12, weight: .semibold))
                    .frame(minWidth: 50)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subheadline).foregroundColor(.secondary)
                    .font(.system(size: 10, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            Image(systemName: (trailingOK == nil || trailingOK!) ? "checkmark.seal.fill" : "xmark.seal.fill")
                .imageScale(.medium)
                .foregroundStyle(trailingOK == nil ? .gray : (trailingOK! ? .green : .red) )
            
            Divider()
            
            Button {
                onRemoved(key)
            } label: {
                Image(systemName: "trash")
                    .imageScale(.medium)
                
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 10)
        }
        .frame(height: 35)
        .background(
            useDark ? Color("list_bg_dark") : Color("list_bg_light")
        )
        .cornerRadius(5)
        .scaleEffect(scale)
        .animation(.spring(response: 0.5, dampingFraction: 0.5), value: scale)
        .onTapGesture {
            startAnimation()
            onSelected(key)
        }
    }
    
    private func startAnimation() {
        scale = 0.9
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.scale = 1
        }
    }
}

// MARK: - ToolTip Extension

extension View {
    /// Overlays this view with a view that provides a toolTip with the given string.
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
