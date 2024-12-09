//
//  V2rayX_CoreRunner.swift
//  V2rayX-CoreRunner
//
//  Created by 杨洋 on 2024/11/17.
//

import Foundation

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class V2rayX_CoreRunner: NSObject, V2rayX_CoreRunnerProtocol {
    static var supportsSecureCoding: Bool = true
    
    func encode(with coder: NSCoder) {
    }
    
    required init?(coder: NSCoder) {
    }
    
    override init() {
        super.init()
    }
    
    var conn: NSXPCConnection? = nil
    
    private var runner: CommandRunner?
    
    @objc func run(command: String, args: [String], with reply: @escaping (Error?) -> Void) {
        let svc = self.conn?.remoteObjectProxyWithErrorHandler { err in
            reply(err)
        } as? ClientProtocol
        
        self.runner = CommandRunner(command: command, args: args, output: { svc?.sendLog($0) })
        
        DispatchQueue.global().async {
            do {
                try self.runner?.run()
                reply(nil)
            } catch {
                reply(error)
            }
        }
    }
    
    
    @objc func close() {
        self.runner?.close()
    }
}


fileprivate class CommandRunner {
    private var process: Process?
    private var output: (String) -> Void
    private var std: Pipe?
    
    init(command: String, args: [String], output: @escaping (String) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        let std = Pipe()
        process.standardOutput = std
        process.standardError = std
        
        self.process = process
        self.output = output
        self.std = std
    }
    
    func run() throws {
        try process?.run()
        
        std?.fileHandleForReading.readabilityHandler = { fileHandle in
            if let str = String(data: fileHandle.availableData, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.output(str)
                }
            }
        }
    }
    
    func close() {
        process?.terminate()
        try? std?.fileHandleForReading.close()
    }
}
