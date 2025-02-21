//
//  CoreRunner.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import Foundation
import XPC
import V2rayX_CoreRunner

actor CoreRunner {
    static let shared = CoreRunner()
    
    private var client: XPCClient? = nil
    
    func start(
        bin: URL,
        config: URL,
        stdOutput: @Sendable @escaping (String) -> Void = {_ in }
    ) async throws {
        if self.client == nil {
            self.client = XPCClient(stdout: stdOutput)
        }
        try await self.client!.run(command: bin.path, args: ["run", "-c", config.path])
    }
    
    func stop() async {
        await client?.close()
    }
}

@objc(_TtC6V2rayXP33_64D1B500EBE4661D27C56256BF1F21E89XPCClient)
fileprivate class XPCClient: NSObject, @unchecked Sendable {
    static let supportsSecureCoding: Bool = true
    
    func encode(with coder: NSCoder) {
    }

    required init?(coder: NSCoder) {
        self.stdout = {_ in }
    }

    private var conn: NSXPCConnection? = nil
    private let stdout: (String) -> Void
    
    init(stdout: @escaping (String) -> Void) {
        self.stdout = stdout
    }
    
    func run(command: String, args: [String]) async throws {
#if DEBUG
        let sn = "com.yangyang.V2rayX-CoreRunner.debug"
#else
        let sn = "com.yangyang.V2rayX-CoreRunner"
#endif
        let conn = NSXPCConnection(serviceName: sn)
        conn.remoteObjectInterface = NSXPCInterface(with: V2rayX_CoreRunnerProtocol.self)
        conn.exportedInterface = NSXPCInterface(with: ClientProtocol.self)
        conn.exportedObject = self
        conn.activate()
        self.conn = conn
        
        return try await withCheckedThrowingContinuation { continuation in
            if let proxy = conn.remoteObjectProxy as? V2rayX_CoreRunnerProtocol {
                proxy.run(command: command, args: args) { err in
                    err != nil ? continuation.resume(throwing: err!) : continuation.resume()
                }
            }
        }
    }
    
    func close() async {
        if let proxy = conn?.remoteObjectProxy as? V2rayX_CoreRunnerProtocol {
            proxy.close()
        }
        conn?.invalidate()
    }
}

extension XPCClient: ClientProtocol {
    func sendLog(_ log: String) {
        self.stdout(log)
    }
}
