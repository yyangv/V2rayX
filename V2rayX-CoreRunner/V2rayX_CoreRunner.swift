//
//  V2rayX_CoreRunner.swift
//  V2rayX-CoreRunner
//
//  Created by 杨洋 on 2024/11/17.
//

import Foundation

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class V2rayX_CoreRunner: NSObject, V2rayX_CoreRunnerProtocol, @unchecked Sendable {
    static let supportsSecureCoding: Bool = true
    
    func encode(with coder: NSCoder) {
    }
    
    required init?(coder: NSCoder) {
    }
    
    override init() {
        super.init()
    }
    
    var conn: NSXPCConnection? = nil
    
    private var runner: CommandRunner?
    
    @objc func run(command: String, args: [String], with reply: @Sendable @escaping (Error?) -> Void) {
        runSafely {
            let svc = self.conn?.remoteObjectProxyWithErrorHandler { err in
                reply(err)
            } as? ClientProtocol
            
            self.runner = CommandRunner(command: command, args: args, output: { svc?.sendLog($0) })
            
            do {
                try self.runner?.run()
                reply(nil)
            } catch {
                reply(error)
            }
        }
    }
    
    @objc func close() {
        runSafely {
            try? self.runner?.close()
        }
    }
    
    private func runSafely(_ block: @Sendable @escaping () -> Void) {
        DispatchQueue.main.async {
            block()
        }
    }
}

fileprivate class CommandRunner {
    private var process: Process?
    private var std: Pipe?
    
    init(command: String, args: [String], output: @Sendable @escaping (String) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        
        let std = Pipe()
        std.fileHandleForReading.readabilityHandler = { fileHandle in
            if let str = String(data: fileHandle.availableData, encoding: .utf8) {
                output(str)
            }
        }
        process.standardOutput = std
        process.standardError = std
        
        self.process = process
        self.std = std
    }
    
    func run() throws {
        try process?.run()
    }
    
    func close() throws {
        process?.terminate()
        try std?.fileHandleForReading.close()
    }
}
