//
//  SwiftDataHelper.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/2/28.
//

import Foundation
import SwiftData

class SwiftDataHelper {
    /// SwiftData has some bad ideas like default storage location.
    /// https://gist.github.com/pdarcey/981b99bcc436a64df222cd8e3dd92871
    static func createModelContainer(for types: any PersistentModel.Type...) -> ModelContainer {
        let config = ModelConfiguration(url: modelFile)
        
        return try! ModelContainer(for: Schema(types), configurations: config)
    }
    
    static func clear() {
        let fm = FileManager.default
        let fileURL = modelFile
        if fm.fileExists(atPath: fileURL.path) {
            try! fm.removeItem(at: fileURL)
        }
    }
    
    static var modelFile: URL {
        let fm = FileManager.default
        let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        
#if DEBUG
        let appName = "V2rayX-Debug"
#else
        let appName = "V2rayX"
#endif
        let appURL = appSupportURL.appendingPathComponent(appName)
        
        if !fm.fileExists(atPath: appURL.path) {
            try! fm.createDirectory (at: appURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        let fileURL = appURL.appendingPathComponent("swiftdata.store")
        
        return fileURL
    }
}
