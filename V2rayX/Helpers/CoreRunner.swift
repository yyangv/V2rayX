//
//  CoreRunner.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/27.
//

import Foundation
import XPC
import V2rayX_CoreRunner

class CoreRunner {
    static let shared = CoreRunner()
    
    private var client: XPCClient? = nil
    
    func start(bin: URL, config: URL, callback: @escaping (Error?) -> Void) {
        self.client = XPCClient(stdout: handleStdout)
        client!.run(command: bin.path, args: ["run", "-c", config.path], cb: callback)
    }
    
    func stop() {
        self.client?.close()
    }
    
    private func handleStdout(_ a: String) {
        // TODO: handle Stdout
    }
}


@objc(_TtC6V2rayXP33_64D1B500EBE4661D27C56256BF1F21E89XPCClient)fileprivate class XPCClient: NSObject, ClientProtocol, NSCoding {
    static var supportsSecureCoding: Bool = true

    func encode(with coder: NSCoder) {
    }

    required init?(coder: NSCoder) {
        self.stdout = {_ in }
    }

    private var conn: NSXPCConnection? = nil
    private let stdout: (String) -> Void
    
    init(stdout: @escaping (String) -> Void) {
        self.stdout = stdout
        self.conn = NSXPCConnection(serviceName: "com.istomyang.V2rayX-CoreRunner")
        super.init()
    }
    
    func run(command: String, args: [String], cb: @escaping (Error?) -> Void) {
        conn?.remoteObjectInterface = NSXPCInterface(with: V2rayX_CoreRunnerProtocol.self)
        conn?.exportedInterface = NSXPCInterface(with: ClientProtocol.self)
        conn?.exportedObject = self
        conn?.resume()
        
        if let proxy = conn?.remoteObjectProxy as? V2rayX_CoreRunnerProtocol {
            proxy.run(command: command, args: args) { err in cb(err) }
        }
    }
    
    func close() {
        if let proxy = conn?.remoteObjectProxy as? V2rayX_CoreRunnerProtocol {
            proxy.close()
        }
    }
    
    func sendLog(_ log: String) {
        self.stdout(log)
    }
}
