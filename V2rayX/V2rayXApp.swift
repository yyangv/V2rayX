//
//  V2rayXApp.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/11/17.
//

import SwiftUI
import SwiftData

@main
struct V2rayXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var modNodes = NodesModel()
    @State private var modCore = CoreModel()
    @State private var modSetting = SettingModel()
    
    private let container = SwiftDataHelper.createModelContainer(for:RouteRuleModel.self,FileModel.self)
    
    var body: some Scene {
        MenuBarExtra {
            PopoverWindow()
                .environment(modNodes)
                .environment(modCore)
                .environment(modSetting)
                .modelContainer(container)
        } label: {
            Image(nsImage: menuBarImage())
        }
        .menuBarExtraStyle(.window)
        
        Window("Main", id: "Main") {
            MainWindow()
                .environment(modNodes)
                .environment(modCore)
                .environment(modSetting)
                .modelContainer(container)
        }
        
        Window("Setting", id: "Setting") {
            SettingWindow()
                .environment(modNodes)
                .environment(modCore)
                .environment(modSetting)
                .modelContainer(container)
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
        // clearUserDefaults()
        
        ensureAppHomeExists()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up code here
        runBlocking {
            await CoreRunner.shared.stop()
            await SystemProxy.shared.restore()
        }
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
    
    private func ensureAppHomeExists() {
        let path = appHomeDirectory().path()
        if !FileManager.default.fileExists(atPath: path) {
            try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
