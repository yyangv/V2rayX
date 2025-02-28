//
//  CoreModel+SwiftData.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/22.
//

import SwiftData
import Foundation

@Model class RouteRuleModel {
    @Attribute(.unique) var id: String
    var name: String
    var outboundTag: String
    var enabled: Bool
    
    var idx: Int
    
    var domain: String?
    var ip: String?
    var port: String?
    var network: String?
    var protocol0: String?
    
    init(
        name: String,
        outboundTag: String,
        enabled: Bool,
        idx: Int,
        domain: String? = nil,
        ip: String? = nil,
        port: String? = nil,
        network: String? = nil,
        protocol0: String? = nil
    ) {
        let id = "\(name)-\(genResourceId(length: 8))"
        self.id = id
        self.name = name
        self.outboundTag = outboundTag
        self.enabled = enabled
        self.domain = domain
        self.ip = ip
        self.port = port
        self.network = network
        self.protocol0 = protocol0
        self.idx = idx
    }
    
    func into() -> XrayConfig.RoutingRule {
        let a = self
        return XrayConfig.RoutingRule(
            ruleTag: a.name,
            outboundTag: a.outboundTag,
            domain: a.domain != nil ? a.domain?.components(separatedBy: ",") : nil,
            ip: a.ip != nil ? a.ip?.components(separatedBy: ",") : nil,
            port: a.port,
            sourcePort: nil,
            network: a.network,
            source: nil,
            inboundTag: nil,
            attrs: nil,
            balancerTag: nil,
            protocol: a.protocol0 != nil ? a.protocol0?.components(separatedBy: ",") : nil
        )
    }
    
    var uiId: String {
        let components = [id, domain.str, ip.str, port.str, network.str, protocol0.str]
        return components.joined()
    }
    
    static var preset: [RouteRuleModel] {
        [
            RouteRuleModel(
                name: "UDP443 Reject",
                outboundTag: XrayConfig.kOutboundRejectTag,
                enabled: true,
                idx: 0,
                port: "443",
                network: "udp",
                protocol0: "http,tls,bittorrent"
            ),
            RouteRuleModel(
                name: "AD Reject",
                outboundTag: XrayConfig.kOutboundRejectTag,
                enabled: true,
                idx: 1,
                domain: "geosite:category-ads-all",
                network: "tcp,udp",
                protocol0: "http,tls,bittorrent"
            ),
            RouteRuleModel(
                name: "LAN IP Direct",
                outboundTag: XrayConfig.kOutboundDirectTag,
                enabled: true,
                idx: 2,
                ip: "geoip:private",
                network: "tcp,udp",
                protocol0: "http,tls,bittorrent"
            ),
            RouteRuleModel(
                name: "China Domain Direct",
                outboundTag: XrayConfig.kOutboundDirectTag,
                enabled: true,
                idx: 3,
                domain: "domain:dns.alidns.com,domain:doh.pub,domain:dot.pub,domain:doh.360.cn,domain:dot.360.cn,geosite:cn,geosite:geolocation-cn",
                network: "tcp,udp",
                protocol0: "http,tls,bittorrent"
            ),
            RouteRuleModel(
                name: "China IP Direct",
                outboundTag: XrayConfig.kOutboundDirectTag,
                enabled: true,
                idx: 4,
                ip: "223.5.5.5/32,223.6.6.6/32,2400:3200::1/128,2400:3200:baba::1/128,119.29.29.29/32,1.12.12.12/32,120.53.53.53/32,2402:4e00::/128,2402:4e00:1::/128,180.76.76.76/32,2400:da00::6666/128,114.114.114.114/32,114.114.115.115/32,180.184.1.1/32,180.184.2.2/32,101.226.4.6/32,218.30.118.6/32,123.125.81.6/32,140.207.198.6/32,geoip:cn",
                network: "tcp,udp",
                protocol0: "http,tls,bittorrent"
            ),
            RouteRuleModel(
                name: "Last Proxy",
                outboundTag: XrayConfig.kOutboundProxyTag,
                enabled: true,
                idx: 5,
                port: "0-65535",
                network: "tcp,udp",
                protocol0: "http,tls,bittorrent"
            )
        ]
    }
}

@Model class FileModel {
    var id: String
    var fileName: String
    var filePath: String?
    var fileType: String
    var createdAt: Double
    var updatedAt: Double
    
    var downloadLink: String?
    var downloadError: String?
    
    init(
        fileName: String,
        filePath: String?,
        fileType: String,
        createdAt: Double,
        updatedAt: Double,
        downloadLink: String? = nil,
        downloadError: String? = nil
    ) {
        self.id = "\(fileName)-\(genResourceId(length: 8))"
        self.fileName = fileName
        self.filePath = filePath
        self.fileType = fileType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.downloadLink = downloadLink
        self.downloadError = downloadError
    }
    
    static func fileTime() -> Double {
        return Date().timeIntervalSince1970
    }
    
    static let kFileTypeGeo = "geo"
}
