//
//  Extensions.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import Foundation
import SwiftUI

actor IOQueue {
    static let shared = IOQueue()
    
    private let queue = DispatchQueue(label: "com.yangyang.V2rayX.IOQueue", qos: .userInitiated)
    
    func task(_ block: @escaping @Sendable () async throws -> Void) {
        queue.async { runBlockingThrowable { try await block() } }
    }
}

func runBlocking(_ block: @escaping @Sendable () async -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        await block()
        semaphore.signal()
    }
    semaphore.wait()
}

func runBlockingThrowable(_ block: @escaping @Sendable () async throws -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        try await block()
        semaphore.signal()
    }
    semaphore.wait()
}

func genResourceId(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0 ..< length).map { _ in letters.randomElement()! })
}

func runCommand(bin: String, args: [String]) async -> String {
    return await Task {
        let task = Process()
        task.launchPath = bin
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }.value
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
