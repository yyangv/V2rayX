//
//  SystemProxy.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import Foundation

actor SystemProxy {
    static let shared = SystemProxy()
    
    private var saved: [SystemProxyInfo] = []
    
    func registerWithSave(hh: String, hp: String, sh: String, sp: String) async {
        saved = await getSystemProxyInfo()
        await registerSystemProxy(hh: hh, hp: hp, sh: sh, sp: sp)
    }
    
    func restore() async {
        await restoreSystemProxyInfo(saved)
    }
    
    private let bin = "/usr/sbin/networksetup"
    
    func clear() async {
        for network in await getNetworkInterfaces() {
            _ = await runCommand(bin: bin, args: ["-setwebproxy", network, "", ""])
            _ = await runCommand(bin: bin, args: ["-setsecurewebproxy", network, "", ""])
            _ = await runCommand(bin: bin, args: ["-setsocksfirewallproxy", network, "", ""])
            
            _ = await runCommand(bin: bin, args: ["-setwebproxystate", network, "off"])
            _ = await runCommand(bin: bin, args: ["-setsecurewebproxystate", network, "off"])
            _ = await runCommand(bin: bin, args: ["-setsocksfirewallproxystate", network, "off"])
        }
        saved.removeAll()
    }
    
    private func registerSystemProxy(hh: String, hp: String, sh: String, sp: String) async {
        for network in await getNetworkInterfaces() {
            _ = await runCommand(bin: bin, args: ["-setwebproxy", network, hh, hp])
            _ = await runCommand(bin: bin, args: ["-setwebproxystate", network, "on"])
            _ = await runCommand(bin: bin, args: ["-setsecurewebproxy", network, sh, sp])
            _ = await runCommand(bin: bin, args: ["-setsecurewebproxystate", network, "on"])
            _ = await runCommand(bin: bin, args: ["-setsocksfirewallproxy", network, sh, sp])
            _ = await runCommand(bin: bin, args: ["-setsocksfirewallproxystate", network, "on"])
        }
    }
    
    private func getSystemProxyInfo() async -> [SystemProxyInfo] {
        var r: [SystemProxyInfo] = []
        for network in await getNetworkInterfaces() {
            let raw1 = await runCommand(bin: bin, args: ["-getwebproxy", network])
            let raw2 = await runCommand(bin: bin, args: ["-getsecurewebproxy", network])
            let raw3 = await runCommand(bin: bin, args: ["-getsocksfirewallproxy", network])
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
    
    private func restoreSystemProxyInfo(_ infos: [SystemProxyInfo]) async {
        for info in infos {
            let network = info.network
            _ = await runCommand(bin: bin, args: ["-setwebproxy", network, info.httpHost, String(info.httpPort)])
            _ = await runCommand(bin: bin, args: ["-setsecurewebproxy", network, info.httpsHost, String(info.httpsPort)])
            _ = await runCommand(bin: bin, args: ["-setsocksfirewallproxy", network, info.socksHost, String(info.socksPort)])
            
            _ = await runCommand(bin: bin, args: ["-setwebproxystate", network, info.httpEnabled ? "on" : "off"])
            _ = await runCommand(bin: bin, args: ["-setsecurewebproxystate", network, info.httpsEnabled ? "on" : "off"])
            _ = await runCommand(bin: bin, args: ["-setsocksfirewallproxystate", network, info.socksEnabled ? "on" : "off"])
        }
    }
    
    private func handleSystemProxyGetInfo(raw: String) -> (Bool, String, Int) {
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
    
    private func getNetworkInterfaces() async -> [String] {
        return await runCommand(bin: "/usr/sbin/networksetup", args: ["listallnetworkservices"])
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
