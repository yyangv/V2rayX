//
//  CoreModel.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import Foundation

@Observable class CoreModel {
    static let kProxyTag = XrayConfigBuilder.kOutboundProxyTag
    static let kDirectTag = XrayConfigBuilder.kOutboundProxyTag
    static let kRejectTag = XrayConfigBuilder.kOutboundProxyTag
    
    private let store = UserDefaults.standard
    
    var corePath: String {
        didSet { store.set(corePath, forKey: kCorePath) }
    }
    var coreName: String {
        didSet { store.set(coreName, forKey: kCoreName) }
    }
    var coreGithub: String {
        didSet { store.set(coreGithub, forKey: kCoreGithub) }
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
    
    func run(
        activeLink: String,
        logAccessURL: URL,
        logErrorURL: URL,
        configURL: URL,
        rules: [RouteRuleModel],
        onCompleted: @escaping (Error?)->Void
    ) throws {
        typealias E = V2Error
        
        if corePath.isEmpty {
            throw E.message("Core is not set.")
        }
        let coreURL = URL(fileURLWithPath: corePath)
        
        if !Utils.checkBinaryExecutable(coreURL) {
            throw E.binaryUnexecutable
        }
        
        let config = XrayConfig(
            log: XrayConfig.Log(
                enableAccess:logEnableAccess,
                accessPath: logAccessURL.path(),
                enableError: logEnableError,
                errorPath: logErrorURL.path(),
                level: logLevel,
                enableDNS: logEnableDNS,
                enableMaskAddress: logEnableMaskAddress
            ),
            dns: XrayConfig.DNS(
                hosts: hosts.map { ($0.domain, $0.ip) },
                directIp: dnsDirectIp,
                proxyIp: dnsProxyIp,
                enableFakeDNS: dnsEnableFakeDNS
            ),
            inbound: XrayConfig.Inbound(
                portHTTP: Int(inPortHttp)!,
                portSOCKS: Int(inPortSocks)!,
                allowLAN: inAllowLAN
            ),
            outbound: XrayConfig.Outbound(
                link: activeLink,
                enableMux: ouEnableMux,
                muxConcurrency: Int(ouMuxConcurrency)!,
                muxXudpConcurrency: Int(ouMuxXudpConcurrency)!,
                muxXudpProxyUDP443: ouMuxXudpProxyUDP443
            ),
            routing: XrayConfig.Routing(
                domainStrategy: domainStrategy,
                rules: rules.map { $0.into() }
            ),
            stats: XrayConfig.Stats(enable: statsEnabled)
        )
        
        let configData = try XrayConfigBuilder.shared.buildConfig(config: config)
        try Utils.write(path: configURL, data: configData, override: true)
        
        CoreRunner.shared.start(bin: coreURL, config: configURL) { e in
            if let e = e {
                onCompleted(e)
                return
            }
            let h = "127.0.0.1"
            let hp = self.inPortHttp
            let sp = self.inPortSocks
            SystemProxy.shared.registerWithSave(hh: h, hp: hp, sh: h, sp: sp)
            onCompleted(nil)
        }
    }
    
    func stop() {
        CoreRunner.shared.stop()
        SystemProxy.shared.restore()
    }
    
    func fetchLocalCoreVersion(cb: @escaping (String?)->Void) {
        if corePath.isEmpty {
            cb(nil)
            return
        }
        let url = URL(fileURLWithPath: corePath)
        DispatchQueue.main.async {
            let v = Utils.getCoreVersion(url)
            cb(v)
        }
    }
    
    func fetchNetVersion(cb: @escaping (String?)->Void) {
        if coreGithub.isEmpty {
            cb(nil)
            return
        }
        let a = coreGithub.components(separatedBy: "/")
        if a.count < 2 {
            cb(nil)
            return
        }
        DispatchQueue.main.async {
            Utils.fetchGithubLatestVersion(owner: a.first!, repo: a.last!) { v, _ in
                cb(v)
            }
        }
    }
    
    init() {
        Self.install()
        
        let store = UserDefaults.standard
        
        coreName = store.string(forKey: kCoreName) ?? ""
        corePath = store.string(forKey: kCorePath) ?? ""
        coreGithub = store.string(forKey: kCoreGithub) ?? ""
        
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
        let kStoreInited = "C/StoreInstalled"
        if !store.bool(forKey: kStoreInited) {
            defer {
                store.set(true, forKey: kStoreInited)
            }
            
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

fileprivate let kCoreName = "C/CoreName"
fileprivate let kCorePath = "C/CorePath"
fileprivate let kCoreGithub = "C/CoreGithub"

fileprivate let kInboundPortHTTP = "C/Inbound/PortHTTP"
fileprivate let kInboundPortSOCKS = "C/Inbound/PortSOCKS"
fileprivate let kInboundAllowLAN = "C/Inbound/AllowLAN"

fileprivate let kDNSHosts = "C/DNC/Hosts"
fileprivate let kDNSDirectIp = "C/DNC/DirectIp"
fileprivate let kDNSProxyIp = "C/DNC/ProxyIp"
fileprivate let kDNSEnableFakeDNS = "C/DNC/EnableFakeDNS"

fileprivate let kOutboundEnableMux = "C/Outbound/EnableMux"
fileprivate let kOutboundMuxConcurrency = "C/Outbound/MuxConcurrency"
fileprivate let kOutboundMuxXudpConcurrency = "C/Outbound/MuxXudpConcurrency"
fileprivate let kOutboundMuxXudpProxyUDP443 = "C/Outbound/MuxXudpProxyUDP443"

fileprivate let kLogEnableAccess = "C/Log/EnableAccess"
fileprivate let kLogEnableError = "C/Log/EnableError"
fileprivate let kLogLevel = "C/Log/Level"
fileprivate let kLogEnableDNS = "C/Log/EnableDNS"
fileprivate let kLogEnableMaskAddress = "C/Log/EnableMaskAddress"

fileprivate let kRoutingDomainStrategy = "C/Routing/DomainStrategy"

fileprivate let kStatsEnable = "C/Stats/Enable"
