//
//  PopoverViewModel.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/13.
//

import Foundation
import Network
import SwiftUI

@Observable class PopoverContentViewModel {
    private let store = UserDefaults.standard
    
    var items: [ItemData] = []
    private var itemLinkDict: [String:String] = [:] // key: link
    
    var isPlaying = false
    var changeSystemProxy = false
    
    func start(cb: @escaping (Error?) -> Void) {
        guard let activeCore = store.string(forKey: STUActiveCore) else {
            cb(V2Error("Active core not found"))
            return
        }
        let coreURL = URL(fileURLWithPath: activeCore)
        
        if !UtilsDomain.shared.detectBinaryExecutable(coreURL) {
            UtilsDomain.shared.openSystemSettingSecurity()
            return cb(V2Error("Core is not executable"))
        }
        
        do {
            let config = try collectConfig()
            let json = CoreDomain.shared.buildConfig(config: config)
            let configURL: URL
            if SANDBOX {
                configURL = try FileDomain.shared.writeFile(name: "config", group: "Core",data: json.data(using: .utf8)!, override: true)
            } else {
                guard let home = store.string(forKey: STUHomePath) else {
                    cb(V2Error("Home path not found"))
                    return
                }
                configURL = try FileDomain.shared.write(name: "config.json", path: URL(filePath: home), data: json.data(using: .utf8)!)
            }
            
            CoreDomain.shared.start(bin: coreURL, config: configURL) { e in
                if let e = e {
                    cb(e)
                    return
                }
                
                let hp = config.inbound.portHTTP.string
                let sp = config.inbound.portSOCKS.string
                UtilsDomain.shared.registerSystemProxyWithSave(hh: "127.0.0.1", hp: hp, sh: "127.0.0.1", sp: sp)
                self.changeSystemProxy = true
                self.isPlaying = true
                cb(nil)
            }
        } catch {
            cb(error)
            return
        }
    }
    
    func stop() {
        if !isPlaying {
            return
        }
        defer {
            isPlaying = false
        }
        UtilsDomain.shared.restoreSystemProxy()
        CoreDomain.shared.stop()
    }
    
    func restart(_ cb: @escaping (Error?) -> Void) {
        stop()
        start(cb: cb)
    }
    
    func syncSubscription(cb: @escaping (Error?) -> Void) {
        guard let urlStr = store.string(forKey: STUSubscriptionURL) else {
            cb(V2Error("Subscription URL not found"))
            return
        }
        guard let url = URL(string: urlStr) else {
            cb(V2Error("Invalid Subscription URL"))
            return
        }
        Task {
            do {
                let raw = try await self.fetch(url: url)
                let lines = raw.split(separator: "\n")
                self.store.set(lines, forKey: STUSubscriptionLinks)
                cb(nil)
            } catch {
                cb(error)
            }
        }
    }
    
    func onItemSelected(_ key: String, cb: @escaping (Error?) -> Void) {
        let link = itemLinkDict[key]!
        if link.starts(with: "ss://") {
            return // ignore
        }
        if let idx = self.items.firstIndex(where: { $0.selected }) {
            self.items[idx].selected = false
        }
        let idx = self.items.firstIndex(where: { $0.key == key })!
        self.items[idx].selected = true
        store.set(link, forKey: STUActiveNode)
        if isPlaying {
            restart(cb)
            return
        }
    }
    
    func onItemRemoved(_ key: String) {
        let link = itemLinkDict[key]!
        let save = store.stringArray(forKey: STUSubscriptionLinks)?.filter({ $0 != link })
        store.set(save, forKey: STUSubscriptionLinks)
        
        itemLinkDict.removeValue(forKey: key)
        let item = self.items.first(where: { $0.key == key })!
        self.items.removeAll(where: { $0.key == key })
        if item.selected {
            stop()
        }
    }
    
    func testconnectivity(finished: @escaping () -> Void) {
        let reals = itemLinkDict.compactMap({ k, v in
            if !v.starts(with: "ss://") {
                return (k, v)
            }
            return nil
        })
        let total = reals.count
        var count = 0
        reals.forEach { (key, link) in
            let s0 = link.firstIndex(of: "@")!
            let s = link.index(s0, offsetBy: 1)
            let e = link.firstIndex(of: "?")!
            let address = link[s..<e]
            let part = address.split(separator: ":")
            let host = part[0]
            let port = part[1]
            if link.starts(with: "vless") {
                UtilsDomain.shared.measureConnectivityVless(host: String(host), port: UInt16(port)!) { ok in
                    let idx = self.items.firstIndex(where: { $0.key == key })!
                    DispatchQueue.main.async {
                        self.items[idx].trailingOk = ok
                        count += 1
                        if total == count {
                            finished()
                        }
                    }
                }
            }
        }
    }
    
    func loadItems() {
        let active = store.string(forKey: STUActiveNode)
        let links = store.stringArray(forKey: STUSubscriptionLinks) ?? []
        self.items = links.compactMap { link in
            let a = link.split(separator: "://")
            let `protocol` = String(a[0])
            let b = a[1].split(separator: "#")
            let name = String(b[1])
            self.itemLinkDict[name] = link
            return ItemData(
                key: name,
                headline: name,
                subheadline: `protocol`,
                selected: active == link
            )
        }
    }
    
    func taskBeforeShutdown() {
        if changeSystemProxy {
            UtilsDomain.shared.restoreSystemProxy()
        }
    }
    
    private func fetch(url: URL) async throws -> String {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let base64 = String(data: data, encoding: .utf8),
               let decoded = Data(base64Encoded: base64) {
                if let str = String(data: decoded, encoding: .utf8) {
                    let result = str.removingPercentEncoding ?? str
                    return result
                } else {
                    throw V2Error("Failed to decode the response")
                }
            } else {
                throw V2Error("Failed to decode the response")
            }
        } catch {
            throw V2Error(error.localizedDescription)
        }
    }
    
    private func collectConfig() throws -> CoreConfig {
        let home = URL(fileURLWithPath: store.string(forKey: STUHomePath)!)
        let logDir = home.appendingPathComponent("logs")
        
        let hostsRaw = store.string(forKey: STCDNSHosts)
        let hosts = DNSItem.from(raws: hostsRaw ?? "").map { it in
            return (it.host, it.address)
        }
        
        guard let link = store.string(forKey: STUActiveNode) else {
            throw V2Error("Active node not found")
        }
        guard let ruleRaws = store.string(forKey: STURoutingRules) else {
             throw V2Error("Routing rules not found")
        }
        let rules = (jsonDecode(ruleRaws)! as [UserRoutingRule]).map { $0.into() }
        
        let config = CoreConfig(
            log: CoreConfig.Log(
                enableAccess: store.bool(forKey: STCLogEnableAccess),
                accessPath: logDir.appendingPathComponent("access.log").path,
                enableError: store.bool(forKey: STCLogEnableError),
                errorPath: logDir.appendingPathComponent("error.log").path,
                level: store.string(forKey: STCLogLevel)!,
                enableDNS: store.bool(forKey: STCLogEnableDNS),
                enableMaskAddress: store.bool(forKey: STCLogEnableMaskAddress)
            ),
            dns: CoreConfig.DNS(
                hosts: hosts,
                directIp: store.string(forKey: STCDNSDirectIp)!,
                proxyIp: store.string(forKey: STCDNSProxyIp)!,
                enableFakeDNS: store.bool(forKey: STCDNSEnableFakeDNS)
            ),
            inbound: CoreConfig.Inbound(
                portHTTP: store.string(forKey: STCInboundPortHTTP)!.int,
                portSOCKS: store.string(forKey: STCInboundPortSOCKS)!.int,
                allowLAN: store.bool(forKey: STCInboundAllowLAN)
            ),
            outbound: CoreConfig.Outbound(
                link: link,
                enableMux: store.bool(forKey: STCOutboundEnableMux),
                muxConcurrency: store.string(forKey: STCOutboundMuxConcurrency)!.int,
                muxXudpConcurrency: store.string(forKey: STCOutboundMuxXudpConcurrency)!.int,
                muxXudpProxyUDP443: store.string(forKey: STCOutboundMuxXudpProxyUDP443)!
            ),
            routing: CoreConfig.Routing(
                domainStrategy: store.string(forKey: STCRoutingDomainStrategy)!,
                rules: rules
            ),
            stats: CoreConfig.Stats(enable: store.bool(forKey: STCStatsEnable))
        )
        return config
    }
    
    struct ItemData {
        let key: String
        let headline: String
        let subheadline: String
        var selected: Bool
        var useDark: Bool = false
        var trailingOk: Bool? = nil
    }
}


