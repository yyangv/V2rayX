//
//  CoreRunner.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import Foundation
import XPC

actor CoreRunner {
    static let shared = CoreRunner()
    
    private var process: Process?
    private var std: Pipe?
    
    func start(
        bin: URL,
        config: URL,
        stdOutput: @Sendable @escaping (String) -> Void = {_ in }
    ) throws {
        if self.process != nil {
            return
        }
        let process = Process()
        process.executableURL = bin
        process.arguments = ["run", "-c", config.path]
        let std = Pipe()
        std.fileHandleForReading.readabilityHandler = { fileHandle in
            if let str = String(data: fileHandle.availableData, encoding: .utf8) {
                stdOutput(str)
            }
        }
        process.standardOutput = std
        process.standardError = std
        
        self.process = process
        self.std = std
        
        try process.run()
    }
    
    func stop() {
        guard let process = process else { return }
        if !process.isRunning { return }
        process.terminate()
        try? std?.fileHandleForReading.close()
        self.process = nil
        std = nil
    }
}
