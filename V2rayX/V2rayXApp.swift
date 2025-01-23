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
    
    var body: some Scene {
        MenuBarExtra {
            PopoverWindow()
        } label: {
            Image(nsImage: menuBarImage())
        }
        .menuBarExtraStyle(.window)
        
        Window("Main", id: "Main") {
            MainWindow()
        }
        
        Window("Setting", id: "Setting") {
            SettingWindow()
        }
    }
    
    private func menuBarImage() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular, scale: .medium)
        let image = NSImage(systemSymbolName: "v.square.fill", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
        image.isTemplate = true
        return image
    }
}

extension EnvironmentValues {
    @Entry var modSetting = SettingModel()
    @Entry var modNodes = NodesModel()
    @Entry var modCore = CoreModel()
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
//        clearUserDefaults()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up code here
        SystemProxy.shared.restore()
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
