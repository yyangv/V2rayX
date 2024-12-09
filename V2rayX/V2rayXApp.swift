//
//  V2rayXApp.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/11/17.
//

import SwiftUI
import ServiceManagement

@main
struct V2rayXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some Scene {
        WindowGroup(id: "main") {
            MainView().onAppear {
                dismissWindow(id: "main")
            }
            .frame(width: 300, height: 300, alignment: .center)
        }
        
        WindowGroup(id: "settings") {
            SettingContentView()
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                }
                .onDisappear {
                    NSApplication.shared.setActivationPolicy(.accessory)
                }
        }
        
//        Settings {
//            EmptyView()
//        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // install stage
        SettingViewModel.shared.install()
        
        // register PopoverWindow in Status Bar.
        self.registerPopover()
        
        debugPrint("====>", URL.homeDirectory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up code here
        UtilsDomain.shared.restoreSystemProxy()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    func registerPopover() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "v.square.fill", accessibilityDescription: nil)!
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular, scale: .medium))
            button.image!.isTemplate = true
            button.action = #selector(togglePopover(_:))
        }
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverContentView())
    }
    
    @objc private func togglePopover(_ sender: Any) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.maxY)
            }
        }
    }
    
    private func clearUserDefaults() {
        let store = UserDefaults.standard
        store.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        store.synchronize()
    }
    
    private func catUserDefaults() {
        let store = UserDefaults.standard
        print(store.dictionaryRepresentation())
    }
}
