//
//  SettingModel.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/26.
//

import SwiftUI

@Observable class SettingModel {
    private let store = UserDefaults.standard
    
    var enableLoginLaunch: Bool {
        didSet { store.set(enableLoginLaunch, forKey: kEnableLoginLaunch) }
    }
    
    var homePath: URL? {
        didSet { store.set(homePath, forKey: kHomePath) }
    }
    
    var useJsonFile: Bool {
        didSet { store.set(useJsonFile, forKey: kUseJsonFile) }
    }
    
    var jsonFilePath: URL? {
        didSet { store.set(jsonFilePath, forKey: kJsonFilePath) }
    }
    
    // MARK: - Core
    
    var coreActivePath: String {
        didSet { store.set(coreActivePath, forKey: kActiveCorePath) }
    }
    var coreGithubOwner: String {
        didSet { store.set(coreGithubOwner, forKey: kCoreGithubOwner) }
    }
    var coreGithubRepo: String {
        didSet { store.set(coreGithubRepo, forKey: kCoreGithubRepo) }
    }
    
    // MARK: - Node
    
    var activeLink: String {
        didSet { store.set(activeLink, forKey: kActiveNode) }
    }
    var subscriptionURL: String {
        didSet { store.set(subscriptionURL, forKey: kSubscriptionURL) }
    }
    var links: [String] {
        didSet { store.set(links, forKey: kSubscriptionLinks) }
    }
    
    // MARK: - Inbound
    
    var inPortHttp: String {
        didSet { store.set(inPortHttp, forKey: kInboundPortHTTP) }
    }
    var inPortSocks: String {
        didSet { store.set(inPortSocks, forKey: kInboundPortSOCKS) }
    }
    var inAllowLAN: Bool {
        didSet { store.set(inAllowLAN, forKey: kInboundAllowLAN) }
    }
    
    // MARK: - DNS
    
    var hosts: [Host] {
        didSet { store.set(Host.strings(hosts), forKey: kDNSHosts) }
    }
    var dnsDirectIp: String {
        didSet { store.set(dnsDirectIp, forKey: kDNSDirectIp) }
    }
    var dnsProxyIp: String {
        didSet { store.set(dnsProxyIp, forKey: kDNSProxyIp) }
    }
    var dnsEnableFakeDNS: Bool {
        didSet { store.set(dnsEnableFakeDNS, forKey: kDNSEnableFakeDNS) }
    }
    
    // MARK: - Outbound
    
    var ouEnableMux: Bool {
        didSet { store.set(ouEnableMux, forKey: kOutboundEnableMux) }
    }
    
    var ouMuxConcurrency: String {
        didSet { store.set(ouMuxConcurrency, forKey: kOutboundMuxConcurrency) }
    }
    
    var ouMuxXudpConcurrency: String {
        didSet { store.set(ouMuxXudpConcurrency, forKey: kOutboundMuxXudpConcurrency) }
    }
    
    var ouMuxXudpProxyUDP443: String {
        didSet { store.set(ouMuxXudpProxyUDP443, forKey: kOutboundMuxXudpProxyUDP443) }
    }
    
    // MARK: - Route
    
    var domainStrategy: String {
        didSet { store.set(domainStrategy, forKey: kRoutingDomainStrategy) }
    }
    
    // MARK: - Log
    
    var logEnableAccess: Bool {
        didSet { store.set(logEnableAccess, forKey: kLogEnableAccess) }
    }
    var logEnableError: Bool {
        didSet { store.set(logEnableError, forKey: kLogEnableError) }
    }
    var logEnableDNS: Bool {
        didSet { store.set(logEnableDNS, forKey: kLogEnableDNS) }
    }
    var logEnableMaskAddress: Bool {
        didSet { store.set(logEnableMaskAddress, forKey: kLogEnableMaskAddress) }
    }
    var logLevel: String {
        didSet { store.set(logLevel, forKey: kLogLevel) }
    }
    
    // MARK: - Stats
    
    var statsEnabled: Bool {
        didSet { store.set(statsEnabled, forKey: kStatsEnable) }
    }
    
    init() {
        Self.install()
        
        let store = UserDefaults.standard
        enableLoginLaunch = store.bool(forKey: kEnableLoginLaunch)
        homePath = store.url(forKey: kHomePath)
        useJsonFile = store.bool(forKey: kUseJsonFile)
        jsonFilePath = store.url(forKey: kJsonFilePath)
        
        coreActivePath = store.string(forKey: kActiveCorePath)!
        coreGithubOwner = store.string(forKey: kCoreGithubOwner)!
        coreGithubRepo = store.string(forKey: kCoreGithubRepo)!
        
        activeLink = store.string(forKey: kActiveNode)!
        subscriptionURL = store.string(forKey: kSubscriptionURL)!
        links = store.stringArray(forKey: kSubscriptionLinks)!
        
        inPortHttp = store.string(forKey: kInboundPortHTTP)!
        inPortSocks = store.string(forKey: kInboundPortSOCKS)!
        inAllowLAN = store.bool(forKey: kInboundAllowLAN)
        
        hosts = Host.from(raws: store.string(forKey: kDNSHosts) ?? "")
        dnsDirectIp = store.string(forKey: kDNSDirectIp)!
        dnsProxyIp = store.string(forKey: kDNSProxyIp)!
        dnsEnableFakeDNS = store.bool(forKey: kDNSEnableFakeDNS)
        
        ouEnableMux = store.bool(forKey: kOutboundEnableMux)
        ouMuxConcurrency = store.string(forKey: kOutboundMuxConcurrency)!
        ouMuxXudpConcurrency = store.string(forKey: kOutboundMuxXudpConcurrency)!
        ouMuxXudpProxyUDP443 = store.string(forKey: kOutboundMuxXudpProxyUDP443)!
        
        domainStrategy = store.string(forKey: kRoutingDomainStrategy)!
        
        logEnableAccess = store.bool(forKey: kLogEnableAccess)
        logEnableError = store.bool(forKey: kLogEnableError)
        logEnableDNS = store.bool(forKey: kLogEnableDNS)
        logEnableMaskAddress = store.bool(forKey: kLogEnableMaskAddress)
        logLevel = store.string(forKey: kLogLevel)!
        
        statsEnabled = store.bool(forKey: kStatsEnable)
    }
    
    private static func install() {
        let store = UserDefaults.standard
        let kStoreInited = "S/StoreInstalled"
        if !store.bool(forKey: kStoreInited) {
            defer {
                store.set(true, forKey: kStoreInited)
            }
            
            // App
            store.set(false, forKey: kEnableLoginLaunch)
            store.set("", forKey: kHomePath)
            store.set(false, forKey: kUseJsonFile)
            store.set(nil, forKey: kJsonFilePath)
            
            // Core
            store.set("", forKey: kActiveCorePath)
            store.set("xtls", forKey: kCoreGithubOwner)
            store.set("xray-core", forKey: kCoreGithubRepo)
            
            // Node
            store.set("", forKey: kActiveNode)
            store.set("", forKey: kSubscriptionURL)
            store.set([], forKey: kSubscriptionLinks)
            
            // Inbound
            store.set("10808", forKey: kInboundPortHTTP)
            store.set("10809", forKey: kInboundPortSOCKS)
            store.set(true, forKey: kInboundAllowLAN)
            
            // DNS
            store.set("", forKey: kDNSHosts)
            store.set("223.5.5.5", forKey: kDNSDirectIp)
            store.set("1.1.1.1", forKey: kDNSProxyIp)
            store.set(true, forKey: kDNSEnableFakeDNS)
            store.set(Host.strings(Host.preset()), forKey: kDNSHosts)
            
            // Outbound
            store.set(true, forKey: kOutboundEnableMux)
            store.set("8", forKey: kOutboundMuxConcurrency)
            store.set("16", forKey: kOutboundMuxXudpConcurrency)
            store.set("allow", forKey: kOutboundMuxXudpProxyUDP443)
            
            // Routing
            store.set("IPIfNonMatch", forKey: kRoutingDomainStrategy)
            
            // Stats
            store.set(true, forKey: kStatsEnable)
            
            // Log
            store.set(false, forKey: kLogEnableAccess)
            store.set(false, forKey: kLogEnableError)
            store.set(false, forKey: kLogEnableDNS)
            store.set(true, forKey: kLogEnableMaskAddress)
            store.set("none", forKey: kLogLevel)
            
            // Stats
            store.set(false, forKey: kStatsEnable)
        }
    }
}


struct Host {
    let domain: String
    let ip: String
    
    func string() -> String {
        return domain + "<>" + ip
    }
    
    static func from(raw: String) -> Self? {
        if raw.isEmpty { return nil }
        let components = raw.components(separatedBy: "<>")
        return Self(domain: components[0], ip: components[1])
    }
    
    static func from(raws: String) -> [Self] {
        if raws.isEmpty { return [] }
        return raws.split(separator: "\n").compactMap { from(raw: String($0)) }
    }
    
    static func strings(_ dns: [Self]) -> String {
        return dns.map { $0.string() }.joined(separator: "\n")
    }
    
    static func preset() -> [Host] {
        return [
            "geosite:category-ads-all": "127.0.0.1",
            "domain:googleapis.cn": "googleapis.com",
            "dns.alidns.com": "223.5.5.5,223.6.6.6,2400:3200::1,2400:3200:baba::1",
            "one.one.one.one": "1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001",
            "dot.pub": "1.12.12.12, 120.53.53.53",
            "dns.google": "8.8.8.8, 8.8.4.4, 2001:4860:4860::8888, 2001:4860:4860::8844",
            "dns.quad9.net": "9.9.9.9, 149.112.112.112, 2620:fe::fe, 2620:fe::9",
            "common.dot.dns.yandex.net": "77.88.8.8, 77.88.8.1, 2a02:6b8::feed:0ff, 2a02:6b8:0:1::feed:0ff"
        ].map { Host(domain: $0, ip: $1) }
    }
}

// MARK: - Store Key

fileprivate let kEnableLoginLaunch = "S/EnableLoginLaunch"
fileprivate let kHomePath = "S/HomePath"
fileprivate let kUseJsonFile = "S/UseJsonFile"
fileprivate let kJsonFilePath = "S/JsonFilePath"

fileprivate let kActiveCorePath = "S/ActiveCorePath"
fileprivate let kCoreGithubOwner = "S/CoreGithubOwner"
fileprivate let kCoreGithubRepo = "S/CoreGithubRepo"

fileprivate let kActiveNode = "S/ActiveNode" // link
fileprivate let kSubscriptionURL = "S/SubscriptionURL"
fileprivate let kSubscriptionLinks = "S/SubscriptionLinks" // [Link]

fileprivate let kInboundPortHTTP = "S/Inbound/PortHTTP"
fileprivate let kInboundPortSOCKS = "S/Inbound/PortSOCKS"
fileprivate let kInboundAllowLAN = "S/Inbound/AllowLAN"

fileprivate let kDNSHosts = "S/DNS/Hosts"
fileprivate let kDNSDirectIp = "S/DNS/DirectIp"
fileprivate let kDNSProxyIp = "S/DNS/ProxyIp"
fileprivate let kDNSEnableFakeDNS = "S/DNS/EnableFakeDNS"

fileprivate let kOutboundEnableMux = "S/Outbound/EnableMux"
fileprivate let kOutboundMuxConcurrency = "S/Outbound/MuxConcurrency"
fileprivate let kOutboundMuxXudpConcurrency = "S/Outbound/MuxXudpConcurrency"
fileprivate let kOutboundMuxXudpProxyUDP443 = "S/Outbound/MuxXudpProxyUDP443"

fileprivate let kLogEnableAccess = "S/Log/EnableAccess"
fileprivate let kLogEnableError = "S/Log/EnableError"
fileprivate let kLogLevel = "S/Log/Level"
fileprivate let kLogEnableDNS = "S/Log/EnableDNS"
fileprivate let kLogEnableMaskAddress = "S/Log/EnableMaskAddress"

fileprivate let kRoutingDomainStrategy = "S/Routing/DomainStrategy"

fileprivate let kStatsEnable = "S/Stats/Enable"
