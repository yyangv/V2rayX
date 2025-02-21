//
//  V2rayX_CoreRunnerProtocol.swift
//  V2rayX-CoreRunner
//
//  Created by 杨洋 on 2024/11/17.
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc public protocol V2rayX_CoreRunnerProtocol: NSSecureCoding {
    func run(command: String, args: [String], with reply: @Sendable @escaping (Error?) -> Void)
    func close()
}

@objc public protocol ClientProtocol: NSSecureCoding, Sendable {
    func sendLog(_ log: String)
}

/*
 To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:

     connectionToService = NSXPCConnection(serviceName: "com.yangyang.V2rayX-CoreRunner")
     connectionToService.remoteObjectInterface = NSXPCInterface(with: V2rayX_CoreRunnerProtocol.self)
     connectionToService.resume()

 Once you have a connection to the service, you can use it like this:

     if let proxy = connectionToService.remoteObjectProxy as? V2rayX_CoreRunnerProtocol {
         proxy.performCalculation(firstNumber: 23, secondNumber: 19) { result in
             NSLog("Result of calculation is: \(result)")
         }
     }

 And, when you are finished with the service, clean up the connection like this:

     connectionToService.invalidate()
*/
