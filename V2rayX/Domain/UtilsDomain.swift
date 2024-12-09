//
//  UtilsDomain.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/16.
//

import Foundation
import Network
import SwiftUI
import ServiceManagement

class UtilsDomain: ObservableObject {
    static let shared = UtilsDomain()
    
    private func runCommand(bin: String, args: [String]) -> String {
        let task = Process()
        task.launchPath = bin
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        try! task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Login Launch
extension UtilsDomain {
    func registerLoginLaunch() {
        try! SMAppService.mainApp.register()
    }
    
    func unregisterLoginLaunch() {
        try! SMAppService.mainApp.unregister()
    }
}

// MARK: - Binary Executable Detection
extension UtilsDomain {
    func detectBinaryExecutable(_ bin: URL) -> Bool {
        let task = Process()
        task.executableURL = bin
        do { try task.run() } catch {
            return false
        }
        return true
    }
    
    func openSystemSettingSecurity() {
        let alert = NSAlert()
        alert.messageText = "Unable to run the xray-core program"
        alert.informativeText = "The application has been blocked from running. Please open System Preferences > Security & Privacy > General and allow this app to run."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Go to Settings")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?General") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Connection Test
extension UtilsDomain {
    func measureRT(cb: @escaping (_ ms: Int) -> Void) {
        let url = URL(string: "https://www.google.com/generate_204")!
        let t0 = Date()
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            if error != nil { cb(-1); return}
            let duration = Date().timeIntervalSince(t0)
            cb(Int(duration * 1000))
        }
        task.resume()
    }
    
    func measureConnectivityVless(host: String, port: UInt16, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: URL(string: "https://\(host):\(port)")!)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { _, response, error in
            if error != nil {
                completion(false)
                return
            }
            if let res = response as? HTTPURLResponse {
                if res.statusCode == 200 {
                    completion(true)
                    return
                }
            }
            completion(false)
        }
        task.resume()
    }
}


// MARK: - System Proxy Setting
extension UtilsDomain {
    private static var preSystemProxy: [SystemProxyInfo] = []
    
    func registerSystemProxyWithSave(hh: String, hp: String, sh: String, sp: String) {
        UtilsDomain.preSystemProxy = getSystemProxyInfo()
        registerSystemProxy(hh: hh, hp: hp, sh: sh, sp: sp)
    }
    
    func restoreSystemProxy() {
        restoreSystemProxyInfo(UtilsDomain.preSystemProxy)
    }
    
    private func registerSystemProxy(hh: String, hp: String, sh: String, sp: String) {
        let bin = "/usr/sbin/networksetup"
        getNetworkInterfaces().forEach { network in
            _ = self.runCommand(bin: bin, args: ["-setwebproxy", network, hh, hp])
            _ = self.runCommand(bin: bin, args: ["-setwebproxystate", network, "on"])
            _ = self.runCommand(bin: bin, args: ["-setsecurewebproxy", network, hh, hp])
            _ = self.runCommand(bin: bin, args: ["-setsecurewebproxystate", network, "on"])
            _ = self.runCommand(bin: bin, args: ["-setsocksfirewallproxy", network, sh, sp])
            _ = self.runCommand(bin: bin, args: ["-setsocksfirewallproxystate", network, "on"])
        }
    }
    
    private func getSystemProxyInfo() ->  [SystemProxyInfo] {
        var r: [SystemProxyInfo] = []
        let bin = "/usr/sbin/networksetup"
        getNetworkInterfaces().forEach { network in
            let raw1 = self.runCommand(bin: bin, args: ["-getwebproxy", network])
            let raw2 = self.runCommand(bin: bin, args: ["-getsecurewebproxy", network])
            let raw3 = self.runCommand(bin: bin, args: ["-getsocksfirewallproxy", network])
            let a1 = handleSystemProxyGetInfo(raw: raw1)
            let a2 = handleSystemProxyGetInfo(raw: raw2)
            let a3 = handleSystemProxyGetInfo(raw: raw3)
            r.append(SystemProxyInfo(
                network: network,
                httpEnabled: a1.0,
                httpHost: a1.1,
                httpPort: a1.2,
                httpsEnabled: a2.0,
                httpsHost: a2.1,
                httpsPort: a2.2,
                socksEnabled: a3.0,
                socksHost: a3.1,
                socksPort: a3.2
            ))
        }
        return r
    }
    
    private func restoreSystemProxyInfo(_ infos: [SystemProxyInfo]) {
        let bin = "/usr/sbin/networksetup"
        infos.forEach { info in
            let network = info.network
            
            _ = self.runCommand(bin: bin, args: ["-setwebproxy", network, info.httpHost, String(info.httpPort)])
            _ = self.runCommand(bin: bin, args: ["-setsecurewebproxy", network, info.httpsHost, String(info.httpsPort)])
            _ = self.runCommand(bin: bin, args: ["-setsocksfirewallproxy", network, info.socksHost, String(info.socksPort)])
            
            _ = self.runCommand(bin: bin, args: ["-setwebproxystate", network, info.httpEnabled ? "on" : "off"])
            _ = self.runCommand(bin: bin, args: ["-setsecurewebproxystate", network, info.httpsEnabled ? "on" : "off"])
            _ = self.runCommand(bin: bin, args: ["-setsocksfirewallproxystate", network, info.socksEnabled ? "on" : "off"])
        }
    }
    
    private func handleSystemProxyGetInfo(raw: String) -> (Bool, String, Int) {
        var enabled: Bool = false
        var server: String = ""
        var port: Int = 0
        let lines = raw.split(separator: "\n")
            .filter({ !$0.starts(with: "Authenticated Proxy Enabled") })
        for line in lines {
            let part = line.split(separator: ": ")
            switch part[0] {
            case "Enabled":
                enabled = part[1] == "Yes"
            case "Server":
                server = String(part[1])
            case "Port":
                port = Int(part[1])!
            default:
                break
            }
        }
        return (enabled, server, port)
    }
    
    private func getNetworkInterfaces() -> [String] {
        return self.runCommand(bin: "/usr/sbin/networksetup", args: ["listallnetworkservices"])
            .split(separator: "\n")
            .filter({ !$0.starts(with: "An asterisk") })
            .map { String($0) }
    }
}

fileprivate struct SystemProxyInfo: Codable {
    let network: String
    
    let httpEnabled: Bool
    let httpHost: String
    let httpPort: Int
    
    let httpsEnabled: Bool
    let httpsHost: String
    let httpsPort: Int
    
    let socksEnabled: Bool
    let socksHost: String
    let socksPort: Int
}
