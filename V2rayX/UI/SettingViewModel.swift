//
//  SettingViewModel.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/13.
//

import Foundation
import SwiftUI

@Observable class SettingViewModel {
    static let shared = SettingViewModel()
    
    private let kStoreInited = "U/StoreInstalled"
    
    func install() {
        let store = UserDefaults.standard
        if !store.bool(forKey: kStoreInited) {
            defer {
                store.set(true, forKey: kStoreInited)
            }
            
            // Inbound
            store.set("10808", forKey: STCInboundPortHTTP)
            store.set("10809", forKey: STCInboundPortSOCKS)
            store.set(true, forKey: STCInboundAllowLAN)
            
            // DNS
            store.set("", forKey: STCDNSHosts)
            store.set("223.5.5.5", forKey: STCDNSDirectIp)
            store.set("1.1.1.1", forKey: STCDNSProxyIp)
            store.set(true, forKey: STCDNSEnableFakeDNS)

            // Outbound
            store.set(true, forKey: STCOutboundEnableMux)
            store.set("8", forKey: STCOutboundMuxConcurrency)
            store.set("16", forKey: STCOutboundMuxXudpConcurrency)
            store.set("allow", forKey: STCOutboundMuxXudpProxyUDP443)
            
            // Routing
            store.set("IPIfNonMatch", forKey: STCRoutingDomainStrategy)
            // Preset Routing Rules
            let rules = usePresetRules()
            let raw = jsonEncode(rules, formatting: .withoutEscapingSlashes)
            store.set(raw, forKey: STURoutingRules)
            
            // Stats
            store.set(true, forKey: STCStatsEnable)
            
            // Log
            store.set(false, forKey: STCLogEnableAccess)
            store.set(false, forKey: STCLogEnableError)
            store.set(false, forKey: STCLogEnableDNS)
            store.set(true, forKey: STCLogEnableMaskAddress)
            store.set("none", forKey: STCLogLevel)
            
            // Stats
            store.set(false, forKey: STCStatsEnable)
        }
    }
    
    private func usePresetRules() -> [UserRoutingRule] {
        return [
            UserRoutingRule(
                key: "UDP443 Reject",
                name: "UDP443 Reject",
                outboundTag: OutboundRejectTag,
                enabled: true,
                port: "443",
                network: "udp",
                protocol: "http,tls,bittorrent"
            ),
            UserRoutingRule(
                key: "AD Reject",
                name: "AD Reject",
                outboundTag: OutboundRejectTag,
                enabled: true,
                domain: "geosite:category-ads-all",
                network: "tcp,udp",
                protocol: "http,tls,bittorrent"
            ),
            UserRoutingRule(
                key: "LAN IP Direct",
                name: "LAN IP Direct",
                outboundTag: OutboundDirectTag,
                enabled: true,
                ip: "geoip:private",
                network: "tcp,udp",
                protocol: "http,tls,bittorrent"
            ),
            UserRoutingRule(
                key: "China Domain Direct",
                name: "China Domain Direct",
                outboundTag: OutboundDirectTag,
                enabled: true,
                domain: "domain:dns.alidns.com,domain:doh.pub,domain:dot.pub,domain:doh.360.cn,domain:dot.360.cn,geosite:cn,geosite:geolocation-cn",
                network: "tcp,udp",
                protocol: "http,tls,bittorrent"
            ),
            UserRoutingRule(
                key: "China IP Direct",
                name: "China IP Direct",
                outboundTag: OutboundDirectTag,
                enabled: true,
                ip: "223.5.5.5/32,223.6.6.6/32,2400:3200::1/128,2400:3200:baba::1/128,119.29.29.29/32,1.12.12.12/32,120.53.53.53/32,2402:4e00::/128,2402:4e00:1::/128,180.76.76.76/32,2400:da00::6666/128,114.114.114.114/32,114.114.115.115/32,180.184.1.1/32,180.184.2.2/32,101.226.4.6/32,218.30.118.6/32,123.125.81.6/32,140.207.198.6/32,geoip:cn",
                network: "tcp,udp",
                protocol: "http,tls,bittorrent"
            ),
            UserRoutingRule(
                key: "Last Proxy",
                name: "Last Proxy",
                outboundTag: OutboundProxyTag,
                enabled: true,
                port: "0-65535",
                network: "tcp,udp",
                protocol: "http,tls,bittorrent"
            )
        ]
    }
    
    
    func openToGetDir() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.urls.first {
            return url.path
        }
        return nil
    }
    
    func openToGetFile() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.urls.first {
            return url.path
        }
        return nil
    }
    
    // MARK: App
    
    func enableAutoLaunch(_ enabled: Bool) {
        if enabled {
            UtilsDomain.shared.registerLoginLaunch()
        } else {
            UtilsDomain.shared.unregisterLoginLaunch()
        }
    }
    
    // MARK: File
    
    func downloadFile(
        group: String,
        link: String,
        override: Bool = true, update: Bool = false,
        onProgress: @escaping (Double) -> Void,
        onSaved: @escaping (URL) -> Void,
        onError: @escaping (Error) -> Void
    ) -> Error? {
        return FileDomain.shared.download(
            group: group,
            link: link,
            override: override,
            update: update,
            onProgress: onProgress,
            onSaved: onSaved,
            onError: onError
        )
    }
    
    func cancelDownload(_ id: String) {
        FileDomain.shared.cancelDownload(id)
    }
    
    func listFiles(group: String) -> [File] {
        return FileDomain.shared.list(group: group)
    }
    
    func writeFile(name: String, group: String, data: Data, override: Bool = true) -> Error? {
        do {
            _ = try FileDomain.shared.writeFile(name: name, group: group, data: data, override: override)
            return nil
        } catch {
            return error
        }
    }
    
    func updateFileInfo(file: File) {
        FileDomain.shared.update(file)
    }
    
    func deleteFile(_ id: String) {
        FileDomain.shared.delete(id)
    }
}

