//
//  V2rayXTests.swift
//  V2rayXTests
//
//  Created by 杨洋 on 2024/11/17.
//

import Testing
import Foundation

@testable import V2rayX

struct V2rayXTests {
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func CoreDomain_BuildConfig() async throws {
        let config = CoreConfig(
            log: CoreConfig.Log(
                enableAccess: true,
                accessPath: "/tmp/access.log",
                enableError: true,
                errorPath: "/tmp/error.log",
                level: "none",
                enableDNS: true,
                enableMaskAddress: true
            ),
            dns: CoreConfig.DNS(
                hosts: [
                    ("www.baidu.com", "12.31.1.2")
                ],
                directIp: "223.5.5.5",
                proxyIp: "1.1.1.1",
                enableFakeDNS: true
            ),
            inbound: CoreConfig.Inbound(
                portHTTP: 10808,
                portSOCKS: 10809,
                allowLAN: false
            ),
            outbound: CoreConfig.Outbound(
                link: "vless://2beeb679-2f85-ab13-6fa6-724088fadbd1@server_name.com:443?encryption=none&type=grpc&headerType=none&host=n151.upsnode.top&path=&flow=&security=tls&sni=n151.upsnode.top&fp=&serviceName=1ups&mode=gun&alpn=#🇭🇰HongKong-1512",
                enableMux: true,
                muxConcurrency: 8,
                muxXudpConcurrency: 16,
                muxXudpProxyUDP443: "reject"
            ),
            routing: CoreConfig.Routing(
                domainStrategy: "AsIs",
                rules: [
                    UserRoutingRule(
                        key: "UDP443 Reject",
                        name: "UDP443 Reject",
                        outboundTag: OutboundRejectTag,
                        enabled: true,
                        port: "443",
                        network: "udp",
                        protocol: "http,tls,bittorrent"
                    ).into(),
                    UserRoutingRule(
                        key: "AD Reject",
                        name: "AD Reject",
                        outboundTag: OutboundRejectTag,
                        enabled: true,
                        domain: "geosite:category-ads-all",
                        network: "tcp,udp",
                        protocol: "http,tls,bittorrent"
                    ).into(),
                    UserRoutingRule(
                        key: "LAN IP Direct",
                        name: "LAN IP Direct",
                        outboundTag: OutboundDirectTag,
                        enabled: true,
                        ip: "geoip:private",
                        network: "tcp,udp",
                        protocol: "http,tls,bittorrent"
                    ).into(),
                    UserRoutingRule(
                        key: "China Domain Direct",
                        name: "China Domain Direct",
                        outboundTag: OutboundDirectTag,
                        enabled: true,
                        domain: "domain:dns.alidns.com,domain:doh.pub,domain:dot.pub,domain:doh.360.cn,domain:dot.360.cn,geosite:cn,geosite:geolocation-cn",
                        network: "tcp,udp",
                        protocol: "http,tls,bittorrent"
                    ).into(),
                    UserRoutingRule(
                        key: "China IP Direct",
                        name: "China IP Direct",
                        outboundTag: OutboundDirectTag,
                        enabled: true,
                        ip: "223.5.5.5/32,223.6.6.6/32,2400:3200::1/128,2400:3200:baba::1/128,119.29.29.29/32,1.12.12.12/32,120.53.53.53/32,2402:4e00::/128,2402:4e00:1::/128,180.76.76.76/32,2400:da00::6666/128,114.114.114.114/32,114.114.115.115/32,180.184.1.1/32,180.184.2.2/32,101.226.4.6/32,218.30.118.6/32,123.125.81.6/32,140.207.198.6/32,geoip:cn",
                        network: "tcp,udp",
                        protocol: "http,tls,bittorrent"
                    ).into(),
                    UserRoutingRule(
                        key: "Last Proxy",
                        name: "Last Proxy",
                        outboundTag: OutboundProxyTag,
                        enabled: true,
                        port: "0-65535",
                        network: "tcp,udp",
                        protocol: "http,tls,bittorrent"
                    ).into()
                ]
            ),
            stats: CoreConfig.Stats(enable: false)
        )
        
        let json = CoreDomain.shared.buildConfig(config: config)
        writeFile("config-test.json", json.data(using: .utf8)!)
    }
    
    @Test func unzip() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        debugPrint(URL.temporaryDirectory)
        
        let zipFile = URL.temporaryDirectory.appendingPathComponent("Xray-macos-64.zip")
        let to = URL.temporaryDirectory.appendingPathComponent("core")
        if let e = FileDomain.shared.unzip(zipFile, toDir: to) {
            debugPrint(e)
        }
    }
}

func writeFile(_ filename: String, _ data: Data) {
    let url = URL.temporaryDirectory.appendingPathComponent(filename)
    debugPrint("write file at:", url.path)
    try! data.write(to: url)
}
