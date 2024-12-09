//
//  CoreDomain.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/13.
//

import Foundation
import XPC
import V2rayX_CoreRunner

class CoreDomain {
    static let shared = CoreDomain()
    
    private var client: XPCClient? = nil
    
    func start(bin: URL, config: URL, callback: @escaping (Error?) -> Void) {
        self.client = XPCClient(stdout: handleStdout)
        client!.run(command: bin.path, args: ["run", "-c", config.path], cb: callback)
    }
    
    func stop() {
        self.client?.close()
    }
    
    func buildConfig(config: CoreConfig) -> String {
        var json = [:].json!
        self.buildLog(json: &json, config: config)
        self.buildDNS(json: &json, config: config)
        self.buildInbound(json: &json, config: config)
        self.buildOutbound(json: &json, config: config)
        self.buildRouting(json: &json, config: config)
        self.buildStats(json: &json, config: config)
        return jsonEncode(json)
    }
    
    
    private func handleStdout(_ a: String) {
        // TODO: handle Stdout
    }
    
    private func buildLog(json: inout JSON, config: CoreConfig) {
        let log = config.log
        json["log"] = [
            "access": (log.enableAccess ? log.accessPath : "none").json,
            "error": (log.enableError ? log.errorPath : "none").json,
            "loglevel": log.level.json,
            "dnsLog": log.enableDNS.json,
            "maskAddress": (log.enableMaskAddress ? "quarter" : "").json
        ].json
    }
    
    private func buildDNS(json: inout JSON, config: CoreConfig) {
        let dns = config.dns
        let routing = config.routing
        
        var hosts = [:].json
        dns.hosts.forEach { (a, b) in
            if b.split(separator: ",").count == 1 {
                hosts![a] = b.json
            } else {
                hosts![a] = (b.map {String($0)}).json
            }
        }
        
        var servers: [JSON] = []
        let rules = routing.rules

        if dns.enableFakeDNS {
            servers.append([
                "address": "fakedns".json,
                "domains": rules.filter({ $0.domain != nil }).flatMap({ $0.domain! }).json,
            ].json!)
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
        ].json!)
        
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
        ].json!)
        
        json["dns"] = [
            "hosts": hosts,
            "servers": servers.json
        ].json
        
        if dns.enableFakeDNS {
            json["fakedns"] = [
                "ipPool": "198.18.0.0/16".json,
                "poolSize": 65535.json
            ].json!
        }
    }
    
    static let kOutboundProxyTag = "proxy"
    static let kOutboundDirectTag = "direct"
    static let kOutboundRejectTag = "reject"
    
    private func buildInbound(json: inout JSON, config: CoreConfig) {
        let inbound = config.inbound
        json["inbounds"] = [
            [
                "listen": (inbound.allowLAN ? "0.0.0.0" : "127.0.0.1").json,
                "port": inbound.portHTTP.json,
                "protocol": "http".json,
                "tag": "http".json,
                "settings": [
                    "userLevel": 0.json
                ].json
            ].json,
            [
                "listen": (inbound.allowLAN ? "0.0.0.0" : "127.0.0.1").json,
                "port": inbound.portSOCKS.json,
                "protocol": "socks".json,
                "tag": "socks".json,
                "settings": [
                    "auth": "noauth".json,
                    "udp": true.json,
                    "userLevel": 0.json
                ].json!,
                "sniffing": [
                    "enabled": true.json,
                    "destOverride": ["fakedns+others"].json,
                    "metadataOnly": false.json,
                    "routeOnly": true.json
                ].json
            ].json
        ].json
    }
    
    private func buildOutbound(json: inout JSON, config: CoreConfig) {
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
        
        if link.starts(with: "vless") {
            let node = VlessNode(link: link)
            proxy["protocol"] = "vless".json
            proxy["settings"] = [
                "vnext": [
                    [
                        "address": node.address.json,
                        "port": node.port.json,
                        "users": [
                            [
                                "id": node.uuid.json,
                                "encryption": node.encryption.json,
                                "flow": node.flow.json,
                                "level": 0.json,
                            ].json
                        ].json
                    ].json
                ].json
            ].json
            switch node.type {
            case "grpc":
                proxy["streamSettings"] = [
                    "network": "grpc".json,
                    "security": node.security.json,
                    "tlsSettings": [
                        "allowInsecure": true.json,
                        "serverName": node.address.json,
                        "show": false.json,
                        "fingerprint": node.fp.json
                    ].json,
                    "grpcSettings": [
                        "serviceName": node.serviceName.json,
                        "health_check_timeout": 20.json,
                        "idle_timeout": 60.json,
                        "multiMode": false.json,
                        "authority": "".json,
                    ].json
                ].json
            default:
                break
            }
        }
        
        json["outbounds"] = [
            proxy.json,
            [
                "protocol": "freedom".json,
                "settings": [
                    "domainStrategy": "UseIP".json
                ].json,
                "tag": Self.kOutboundDirectTag.json
            ].json!,
            [
                "protocol": "blackhole".json,
                "settings": [
                    "response": [
                        "type": "http".json
                    ].json
                ].json,
                "tag": Self.kOutboundRejectTag.json
            ].json!
        ].json
    }
    
    private func buildRouting(json: inout JSON, config: CoreConfig) {
        let routing = config.routing
        
        json["routing"] = [
            "domainStrategy": routing.domainStrategy.json,
            "rules": routing.rules.map { $0.json }.json
        ].json
    }
    
    private func buildStats(json: inout JSON, config: CoreConfig) {
        if config.stats.enable {
            json["stats"] = [:].json
        }
    }
}

struct CoreConfig {
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
        ].json!
    }
}



class XPCClient: ClientProtocol {
    static var supportsSecureCoding: Bool = true

    func encode(with coder: NSCoder) {
    }

    required init?(coder: NSCoder) {
        self.stdout = {_ in }
    }

    private var conn: NSXPCConnection? = nil
    private let stdout: (String) -> Void
    
    init(stdout: @escaping (String) -> Void) {
        self.stdout = stdout
        self.conn = NSXPCConnection(serviceName: "com.istomyang.V2rayX-CoreRunner")
        conn?.remoteObjectInterface = NSXPCInterface(with: V2rayX_CoreRunnerProtocol.self)
        conn?.exportedInterface = NSXPCInterface(with: ClientProtocol.self)
        conn?.exportedObject = self
        conn?.resume()
    }
    
    func run(command: String, args: [String], cb: @escaping (Error?) -> Void) {
        if let proxy = conn?.remoteObjectProxy as? V2rayX_CoreRunnerProtocol {
            proxy.run(command: command, args: args) { err in cb(err) }
        }
    }
    
    func close() {
        if let proxy = conn?.remoteObjectProxy as? V2rayX_CoreRunnerProtocol {
            proxy.close()
        }
    }
    
    func sendLog(_ log: String) {
        self.stdout(log)
    }
}

// MARK: - Nodes

fileprivate struct VlessNode {
    let name: String
    let `protocol`: String
    let uuid: String
    let address: String
    let port: Int
    let encryption: String
    let type: String
    let headerType: String
    let host: String
    let path: String
    let flow: String
    let security: String
    let sni: String
    let fp: String
    let serviceName: String
    let mode: String
    let alpn: String
    
    init(link: String) {
        let a = link.split(separator: "://")
        `protocol` = String(a[0])
        let b = a[1].split(separator: "@")
        uuid = String(b[0])
        let c = b[1].split(separator: ":")
        address = String(c[0])
        let d = c[1].split(separator: "?")
        port = Int(d[0])!
        let e = d[1].split(separator: "#")
        name = String(e[1])
        
        var params: [String: String] = [:]
        for param in e[0].split(separator: "&") {
            let kv = param.split(separator: "=")
            if kv.count == 2 {
                let k = String(kv[0])
                let v = String(kv[1])
                params[k] = v
            }
        }
        
        encryption = params["encryption"] ?? ""
        type = params["type"] ?? ""
        headerType = params["headerType"] ?? ""
        host = params["host"] ?? ""
        path = params["path"] ?? ""
        flow = params["flow"] ?? ""
        security = params["security"] ?? ""
        sni = params["sni"] ?? ""
        fp = params["fp"] ?? ""
        serviceName = params["serviceName"] ?? ""
        mode = params["mode"] ?? ""
        alpn = params["alpn"] ?? ""
    }
}
