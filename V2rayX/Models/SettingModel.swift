//
//  SettingModel.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/26.
//

import SwiftUI
import ServiceManagement

@Observable class SettingModel {
    private let store = UserDefaults.standard
    
    var enableLoginLaunch: Bool {
        didSet { store.set(enableLoginLaunch, forKey: kEnableLoginLaunch) }
    }
    
    var enableAutoUpdateAndTest: Bool {
        didSet { store.set(enableAutoUpdateAndTest, forKey: kEnableAutoUpdateAndTest) }
    }
    
    init() {
        let store = UserDefaults.standard
        enableLoginLaunch = store.bool(forKey: kEnableLoginLaunch)
        enableAutoUpdateAndTest = store.bool(forKey: kEnableAutoUpdateAndTest)
        
        self.migrate()
    }
    
    func enableLoginLaunch(_ enabled: Bool) throws {
        enabled ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister()
    }
    
    func migrate() {
        let kHomePath = "S/HomePath"
        store.removeObject(forKey: kHomePath)
    }
}


// MARK: - Store Key

fileprivate let kEnableLoginLaunch = "S/EnableLoginLaunch"
fileprivate let kEnableAutoUpdateAndTest = "S/EnableAutoUpdateAndTest"
