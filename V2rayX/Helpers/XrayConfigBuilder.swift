//
//  XrayConfigBuilder.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/27.
//

import Foundation

class XrayConfigBuilder {
    static let shared = XrayConfigBuilder()
    
    static let kOutboundProxyTag = "proxy"
    static let kOutboundDirectTag = "direct"
    static let kOutboundRejectTag = "reject"
    
    func buildConfig(config: XrayConfig) throws -> Data {
        var json = [:].json
        self.buildLog(json: &json, config: config)
        self.buildDNS(json: &json, config: config)
        self.buildInbound(json: &json, config: config)
        try self.buildOutbound(json: &json, config: config)
        self.buildRouting(json: &json, config: config)
        self.buildStats(json: &json, config: config)
        return jsonEncodeData(json)
    }
    
    private func buildLog(json: inout JSON, config: XrayConfig) {
        let log = config.log
        json["log"] = [
            "access": (log.enableAccess ? log.accessPath : "none").json,
            "error": (log.enableError ? log.errorPath : "none").json,
            "loglevel": log.level.json,
            "dnsLog": log.enableDNS.json,
            "maskAddress": (log.enableMaskAddress ? "quarter" : "").json
        ].json
    }
    
    private func buildDNS(json: inout JSON, config: XrayConfig) {
        let dns = config.dns
        let routing = config.routing
        
        var hosts = [:].json
        dns.hosts.forEach { (a, b) in
            let b = b.replacingOccurrences(of: " ", with: "")
            if b.split(separator: ",").count == 1 {
                hosts[a] = b.json
            } else {
                hosts[a] = b.components(separatedBy: ",").json
            }
        }
        
        var servers: [JSON] = []
        let rules = routing.rules
        
        if dns.enableFakeDNS {
            servers.append([
                "address": "fakedns".json,
                "domains": rules.filter({ $0.domain != nil }).flatMap({ $0.domain! }).json,
            ].json)
        }
        
        servers.append(dns.proxyIp.json)
        servers.append([
            "address": dns.proxyIp.json,
            "domains": rules
                .filter({ $0.domain != nil && $0.outboundTag == Self.kOutboundProxyTag })
                .flatMap({ $0.domain! }).json,
            "expectIPs": rules
                .filter({ $0.ip != nil && $0.outboundTag == Self.kOutboundProxyTag })
                .flatMap({ $0.ip! }).json,
            "skipFallback": false.json,
        ].json)
        
        servers.append([
            "address": dns.directIp.json,
            "domains": rules
                .filter({ $0.domain != nil && $0.outboundTag == Self.kOutboundDirectTag })
                .flatMap({ $0.domain! }).json,
            "expectIPs": rules
                .filter({
                    $0.ip != nil &&
                    $0.outboundTag == Self.kOutboundDirectTag &&
                    ($0.ip == nil || $0.ip!.contains(where: { $0 != "geoip:private"}))
                })
                .flatMap({ $0.ip! }).json,
            "skipFallback": true.json,
        ].json)
        
        json["dns"] = [
            "hosts": hosts,
            "servers": servers.json
        ].json
        
        if dns.enableFakeDNS {
            json["fakedns"] = [
                "ipPool": "198.18.0.0/16".json,
                "poolSize": 65535.json
            ].json
        }
    }
    
    private func buildInbound(json: inout JSON, config: XrayConfig) {
        let inbound = config.inbound
        
        let ip = inbound.allowLAN ? "0.0.0.0" : "127.0.0.1"
        let destOverride = config.dns.enableFakeDNS ? ["fakedns+others"] : ["http", "tls", "quic"]
        let sniffing = [
            "enabled": true.json,
            "destOverride": destOverride.json,
            "metadataOnly": false.json,
            "routeOnly": true.json
        ]
        
        json["inbounds"] = [
            [
                "listen": ip.json,
                "port": inbound.portHTTP.json,
                "protocol": "http".json,
                "tag": "http".json,
                "sniffing": sniffing.json
            ].json,
            [
                "listen": ip.json,
                "port": inbound.portSOCKS.json,
                "protocol": "socks".json,
                "tag": "socks".json,
                "settings": [
                    "auth": "noauth".json,
                    "udp": true.json,
                ].json,
                "sniffing": sniffing.json
            ].json,
            [
                "listen": "127.0.0.1".json,
                "port": 10853.json,
                "protocol": "dokodemo-door".json,
                "settings": [
                    "address": "1.1.1.1".json,
                    "network": "tcp,udp".json,
                    "port": 53.json
                ].json,
                "tag": "dns-in".json
            ].json
        ].json
    }
    
    private func buildOutbound(json: inout JSON, config: XrayConfig) throws {
        let outbound = config.outbound
        let link = outbound.link
        
        var proxy = [
            "tag": Self.kOutboundProxyTag.json
        ]
        
        if outbound.enableMux {
            proxy["mux"] = [
                "enabled": true.json,
                "concurrency": outbound.muxConcurrency.json,
                "xudpConcurrency": outbound.muxXudpConcurrency.json,
                "xudpProxyUDP443": outbound.muxXudpProxyUDP443.json
            ].json
        }
        
        let nodeProtocol = linkProtocol(link)
        
        let params = parseLinkParams(link)
        
        // Protocol
        switch nodeProtocol {
        case "vless":
            let node = VlessNode(link: link)
            node.build(json: &proxy, params: params)
        default:
            throw V2Error("Unsupported node protocol: \(nodeProtocol)")
        }
        
        // Transport & Security
        let transportType = params.value("type")
        let securityType = params.value("security")
        let serverName = getServerName(link: link)
        
        var streamSettings = [
            "network": transportType.json,
            "security": securityType.json,
            "sockopt": [
                "dialerProxy": "fragment".json
            ].json
        ].json
        
        switch transportType {
        case "grpc":
            build_tp_grpc(&streamSettings, params: params, multiMode: false)
        case "ws":
            build_tp_ws(&streamSettings, params: params)
        case "kcp":
            build_tp_kcp(&streamSettings, params: params)
        case "tcp":
            build_tp_tcp(&streamSettings, params: params)
        case "raw":
            build_tp_tcp(&streamSettings, params: params)
        default:
            throw V2Error("Unsupported transport type: \(transportType)")
        }
        
        switch securityType {
        case "tls":
            build_ts_tls(&streamSettings, params: params, allowInsecure: true, serverName: serverName)
        case "reality":
            build_ts_reality(&streamSettings, params: params, show: false)
        default:
            throw V2Error("Unsupported transport security type: \(securityType)")
        }
        
        proxy["streamSettings"] = streamSettings
        
        
        var outbounds = [
            proxy.json,
            [
                "protocol": "freedom".json,
                "settings": [
                    "domainStrategy": "UseIP".json
                ].json,
                "tag": Self.kOutboundDirectTag.json
            ].json,
            [
                "protocol": "blackhole".json,
                "settings": [
                    "response": [
                        "type": "http".json
                    ].json
                ].json,
                "tag": Self.kOutboundRejectTag.json
            ].json,
            [
                "protocol": "freedom".json,
                "settings": [
                    "fragment": [
                        "interval": "10-20".json,
                        "length": "50-100".json,
                        "packets": "tlshello".json
                    ].json,
                    "noises": [
                        [
                            "delay": "10-16".json,
                            "packet": "10-20".json,
                            "type": "rand".json
                        ].json
                    ].json
                ].json,
                "streamSettings": [
                    "network": "tcp".json,
                    "sockopt": [
                        "TcpNoDelay": true.json,
                        "mark": 255.json
                    ].json
                ].json,
                "tag": "fragment".json
            ].json
        ]
        
        if config.dns.enableFakeDNS {
            outbounds.append([
                "protocol": "dns".json,
                "tag": "dns-out".json
            ].json)
        }
        
        json["outbounds"] = outbounds.json
    }
    
    private func buildRouting(json: inout JSON, config: XrayConfig) {
        let routing = config.routing
        
        var rules = [
            [
                "ip": ["1.1.1.1"].json,
                "outboundTag": "proxy".json,
                "port": "53".json,
                "type": "field".json
            ].json,
            [
                "ip": ["223.5.5.5"].json,
                "outboundTag": "direct".json,
                "port": "53".json,
                "type": "field".json
            ].json
        ] + routing.rules.map { $0.json }
        
        if config.dns.enableFakeDNS {
            rules.append([
                "type": "field".json,
                "inboundTag": ["dns-in"].json,
                "port": 53.json,
                "outboundTag": "dns-out".json
            ].json)
        }
        
        json["routing"] = [
            "domainStrategy": routing.domainStrategy.json,
            "rules": rules.json
        ].json
    }
    
    private func buildStats(json: inout JSON, config: XrayConfig) {
        if config.stats.enable {
            json["stats"] = [:].json
        }
    }
}

struct XrayConfig {
    let log: Log
    let dns: DNS
    let inbound: Inbound
    let outbound: Outbound
    let routing: Routing
    let stats: Stats
    
    struct Log {
        let enableAccess: Bool
        let accessPath: String
        let enableError: Bool
        let errorPath: String
        let level: String
        let enableDNS: Bool
        let enableMaskAddress: Bool
    }
    
    struct DNS {
        let hosts: [(String, String)]
        let directIp: String
        let proxyIp: String
        let enableFakeDNS: Bool
    }
    
    struct Inbound {
        let portHTTP: Int
        let portSOCKS: Int
        let allowLAN: Bool
    }
    
    struct Outbound {
        let link: String
        let enableMux: Bool
        let muxConcurrency: Int // 8
        let muxXudpConcurrency: Int // 16
        let muxXudpProxyUDP443: String // "reject"
    }
    
    struct Routing {
        let domainStrategy: String
        let rules: [RoutingRule]
    }
    
    struct Stats {
        let enable: Bool
    }
}

struct RoutingRule: Codable, Hashable {
    let domainMatcher: String
    let type: String
    let domain: [String]?
    let ip: [String]?
    let port: String?
    let sourcePort: String?
    let network: String?
    let source: [String]?
    let inboundTag: String?
    let `protocol`: [String]?
    let attrs: [String: String]?
    let outboundTag: String
    let balancerTag: String?
    let ruleTag: String
    
    init(ruleTag: String,
         outboundTag: String,
         domain: [String]? = nil,
         ip: [String]? = nil,
         port: String? = nil,
         sourcePort: String? = nil,
         network: String? = nil,
         source: [String]? = nil,
         inboundTag: String? = nil,
         attrs: [String : String]? = nil,
         balancerTag: String? = nil,
         `protocol`: [String]? = nil
    ) {
        self.domainMatcher = "hybrid"
        self.type = "field"
        self.domain = domain
        self.ip = ip
        self.port = port
        self.sourcePort = sourcePort
        self.network = network
        self.source = source
        self.inboundTag = inboundTag
        self.attrs = attrs
        self.outboundTag = outboundTag
        self.balancerTag = balancerTag
        self.ruleTag = ruleTag
        self.protocol = `protocol`
    }
    
    var json: JSON {
        return [
            "domainMatcher": domainMatcher.json,
            "type": type.json,
            "domain": domain?.json,
            "ip": ip?.json,
            "port": port?.json,
            "sourcePort": sourcePort?.json,
            "network": network?.json,
            "source": source?.json,
            "inboundTag": inboundTag?.json,
            "attrs": attrs?.json,
            "outboundTag": outboundTag.json,
            "balancerTag": balancerTag?.json,
            "ruleTag": ruleTag.json
        ].json
    }
}

// MARK: Link

fileprivate func parseLinkParams(_ link: String) -> [String: String] {
    guard let s0 = link.firstIndex(of: "?") else {
        return [:]
    }
    let e0 = link.firstIndex(of: "#")
    let s = link.index(after: s0)
    let e = if e0 != nil { link.index(before: e0!) } else { link.endIndex }
    
    let q = link[s...e]
    var params: [String: String] = [:]
    for param in q.components(separatedBy: "&") {
        let kv = param.components(separatedBy: "=")
        params[kv[0]] = kv[1]
    }
    return params
}

fileprivate func getServerName(link: String) -> String {
    if link.starts(with: "vless") {
        let s = link.firstIndex(of: "@")
        let s1 = link.index(after: s!)
        let e = link.firstIndex(of: "?")!
        let address = String(link[s1...e])
        let part = address.components(separatedBy: ":")
        return part[0]
    }
    return ""
}


// MARK: - Node

fileprivate func linkProtocol(_ link: String) -> String {
    return link.components(separatedBy: "://")[0]
}

fileprivate struct VlessNode {
    let name: String
    let protocol0: String
    let uuid: String
    let address: String
    let port: Int
    
    init(link: String) {
        let a = link.components(separatedBy: "://")
        protocol0 = a[0]
        let b = a[1].components(separatedBy: "@")
        uuid = b[0]
        let c = b[1].components(separatedBy: ":")
        address = c[0]
        let d = c[1].components(separatedBy: "?")
        port = Int(d[0])!
        let e = d[1].components(separatedBy: "#")
        name = e[1]
    }
    
    func build(json: inout [String: JSON], params: [String: String]) {
        json["protocol"] = protocol0.json
        json["settings"] = [
            "vnext": [
                [
                    "address": address.json,
                    "port": port.json,
                    "users": [
                        [
                            "id": uuid.json,
                            "encryption": params.value("encryption").json,
                            "flow": params.value("flow").json,
                            "level": 0.json,
                        ].json
                    ].json
                ].json
            ].json
        ].json
    }
}

fileprivate struct SSNode {
    let name: String
    let protocol0: String
    let method: String
    let password: String
    let address: String
    let port: String
    
    init(_ link: String) {
        let a = link.split(separator: "://")
        protocol0 = String(a[0])
        let b = a[1].split(separator: "#")
        name = String(b[1])
        let c = b[0].split(separator: "@")
        
        let decoded = Data(base64Encoded: String(c[0]))
        let str = String(data: decoded!, encoding: .utf8)!
        let d = str.split(separator: ":")
        method = String(d[0])
        password = String(d[1])
        
        let e = c[1].split(separator: ":")
        address = String(e[0])
        port = String(e[1])
    }
}

// MARK: - Transport

fileprivate func supportTransport(protocol0: String) -> Bool {
    return ["grpc", "ws", "kcp"].contains(protocol0)
}

fileprivate func build_tp_grpc(_ json: inout JSON, params: [String: String], multiMode: Bool) {
    var cfg: [String: JSON] = [
        "idle_timeout": 60.json,
        "health_check_timeout": 20.json,
        "multiMode": multiMode.json
    ]
    
    cfg.add(params, "authority")
    cfg.add(params, "serviceName")
    
    json["grpcSettings"] = cfg.json
}

fileprivate func build_tp_ws(_ json: inout JSON, params: [String: String]) {
    var cfg: [String: JSON] = [:]
    
    cfg.add(params, "path")
    cfg.add(params, "host")
    
    json["wsSettings"] = cfg.json
}

fileprivate func build_tp_kcp(_ json: inout JSON, params: [String: String]) {
    var cfg: [String: JSON] = [
        "header": [
            "type": params["headerType"]!.json,
            "domian": "example.com".json
        ].json
    ]
    
    cfg.add(params, "seed")
    
    json["kcpSettings"] = cfg.json
}

fileprivate func build_tp_tcp(_ json: inout JSON, params: [String: String]) {
    var cfg: [String: JSON] = [
        "header": [
            "type": params["headerType"]!.json,
        ].json
    ]
    json["tcpSettings"] = cfg.json
}


// MARK: - Transport Security

fileprivate func build_ts_tls(_ json: inout JSON, params: [String: String], allowInsecure: Bool, serverName: String) {
    var cfg: [String: JSON] = [
        "allowInsecure": allowInsecure.json,
        "serverName": serverName.json
    ]
    
    let alpn = params.value("alpn")
    if alpn != "" {
        let v = alpn.removingPercentEncoding!.split(separator: ",")
        cfg["alpn"] = v.json
    }
    cfg.add(params, "fp", selfKey: "fingerprint")
    
    json["tlsSettings"] = cfg.json
}

fileprivate func build_ts_reality(_ json: inout JSON, params: [String: String], show: Bool) {
    var cfg: [String: JSON] = ["show": show.json]
    
    cfg.add(params, "serverName")
    cfg.add(params, "fp", selfKey: "fingerprint")
    cfg.add(params, "pbk", selfKey: "publicKey")
    cfg.add(params, "sid", selfKey: "shortId")
    cfg.add(params, "spx", selfKey: "spiderx")
    
    json["realitySettings"] = cfg.json
}


extension Dictionary<String, JSON> {
    fileprivate mutating func add(
        _ params: [String: String],
        _ key: String,
        selfKey: String? = nil,
        default0: JSON? = nil,
        middleware: ((String) -> JSON)? = nil
    ) {
        let selfKey = selfKey ?? key
        if params[key] != nil {
            let v = params[key]!
            if middleware != nil {
                self[selfKey] = middleware!(v)
            } else {
                self[selfKey] = v.json
            }
        } else {
            if default0 != nil {
                self[selfKey] = default0!
            }
        }
    }
}

extension Dictionary<String, String> {
    fileprivate func value(_ key: String) -> String {
        return self[key] ?? ""
    }
}
