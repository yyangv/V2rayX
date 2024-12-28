//
//  V2rayXApp.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/11/17.
//

import SwiftUI

@main
struct V2rayXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var settingModel = SettingModel()
    
    var body: some Scene {
        MenuBarExtra {
            PopoverContentView()
                .environment(settingModel)
        } label: {
            Image(nsImage: menuBarImage())
        }
        .menuBarExtraStyle(.window)
        
        Window("Main", id: "main") {
            MainContentView()
                .frame(width: 300, height: 300, alignment: .center)
        }
        
        Window("Setting", id: "settings") {
            SettingContentView()
                .environment(settingModel)
        }
    }
    
    private func menuBarImage() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular, scale: .medium)
        let image = NSImage(systemSymbolName: "v.square.fill", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
        image.isTemplate = true
        return image
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
//        clearUserDefaults()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up code here
        Utils.shared.restoreSystemProxy()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
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
