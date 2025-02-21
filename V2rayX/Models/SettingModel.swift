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
    
    var homePath: URL? {
        didSet { store.set(homePath, forKey: kHomePath) }
    }
    
    init() {
        let store = UserDefaults.standard
        enableLoginLaunch = store.bool(forKey: kEnableLoginLaunch)
        homePath = store.url(forKey: kHomePath)
    }
    
    func enableLoginLaunch(_ enabled: Bool) throws {
        enabled ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister()
    }
}


// MARK: - Store Key

fileprivate let kEnableLoginLaunch = "S/EnableLoginLaunch"
fileprivate let kHomePath = "S/HomePath"
