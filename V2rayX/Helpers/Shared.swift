//
//  Extensions.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import Foundation
import SwiftUI

func genResourceId(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0 ..< length).map { _ in letters.randomElement()! })
}

extension Int {
    var string: String {
        return String(self)
    }
}

extension String {
    var int: Int {
        return Int(self) ?? -1
    }
}

extension View {
    func openToGetURL(useFile: Bool = false) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = useFile
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.urls.first {
            return url
        }
        return nil
    }
    
    func openGetFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            return panel.urls
        }
        return []
    }
}

// MARK: - V2Error

enum V2Error: Error {
    case message(_ msg: String)
    case Err(_ e: any Error)
    
    case binaryUnexecutable
}

extension Error {
    var message: String {
        if let e = self as? V2Error {
            switch e {
            case .message(let msg): return msg
            case .Err(let e): return "\(e)"
            default: return self.localizedDescription
            }
        }
        return self.localizedDescription
    }
}
