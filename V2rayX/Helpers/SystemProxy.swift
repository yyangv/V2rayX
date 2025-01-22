//
//  SystemProxy.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import Foundation

class SystemProxy {
    static let shared = SystemProxy()
    
    private var saved: [SystemProxyInfo] = []
    
    func registerWithSave(hh: String, hp: String, sh: String, sp: String) {
        saved = Self.getSystemProxyInfo()
        Self.registerSystemProxy(hh: hh, hp: hp, sh: sh, sp: sp)
    }
    
    func restore() {
        Self.restoreSystemProxyInfo(saved)
    }
    
    private static func registerSystemProxy(hh: String, hp: String, sh: String, sp: String) {
        let bin = "/usr/sbin/networksetup"
        getNetworkInterfaces().forEach { network in
            _ = Utils.runCommand(bin: bin, args: ["-setwebproxy", network, hh, hp])
            _ = Utils.runCommand(bin: bin, args: ["-setwebproxystate", network, "on"])
            _ = Utils.runCommand(bin: bin, args: ["-setsecurewebproxy", network, sh, sp])
            _ = Utils.runCommand(bin: bin, args: ["-setsecurewebproxystate", network, "on"])
            _ = Utils.runCommand(bin: bin, args: ["-setsocksfirewallproxy", network, sh, sp])
            _ = Utils.runCommand(bin: bin, args: ["-setsocksfirewallproxystate", network, "on"])
        }
    }
    
    private static func getSystemProxyInfo() ->  [SystemProxyInfo] {
        var r: [SystemProxyInfo] = []
        let bin = "/usr/sbin/networksetup"
        getNetworkInterfaces().forEach { network in
            let raw1 = Utils.runCommand(bin: bin, args: ["-getwebproxy", network])
            let raw2 = Utils.runCommand(bin: bin, args: ["-getsecurewebproxy", network])
            let raw3 = Utils.runCommand(bin: bin, args: ["-getsocksfirewallproxy", network])
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
    
    private static func restoreSystemProxyInfo(_ infos: [SystemProxyInfo]) {
        let bin = "/usr/sbin/networksetup"
        infos.forEach { info in
            let network = info.network
            _ = Utils.runCommand(bin: bin, args: ["-setwebproxy", network, info.httpHost, String(info.httpPort)])
            _ = Utils.runCommand(bin: bin, args: ["-setsecurewebproxy", network, info.httpsHost, String(info.httpsPort)])
            _ = Utils.runCommand(bin: bin, args: ["-setsocksfirewallproxy", network, info.socksHost, String(info.socksPort)])
            
            _ = Utils.runCommand(bin: bin, args: ["-setwebproxystate", network, info.httpEnabled ? "on" : "off"])
            _ = Utils.runCommand(bin: bin, args: ["-setsecurewebproxystate", network, info.httpsEnabled ? "on" : "off"])
            _ = Utils.runCommand(bin: bin, args: ["-setsocksfirewallproxystate", network, info.socksEnabled ? "on" : "off"])
        }
    }
    
    private static func handleSystemProxyGetInfo(raw: String) -> (Bool, String, Int) {
        var enabled: Bool = false
        var server: String = ""
        var port: Int = 0
        let lines = raw.split(separator: "\n")
            .filter({ !$0.starts(with: "Authenticated Proxy Enabled") })
        for line in lines {
            let part = line.components(separatedBy: ": ")
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
    
    private static func getNetworkInterfaces() -> [String] {
        return Utils.runCommand(bin: "/usr/sbin/networksetup", args: ["listallnetworkservices"])
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
