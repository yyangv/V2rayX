//
//  NodesModel.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import Foundation
import SwiftData

@Observable class NodesModel {
    private let store = UserDefaults.standard
    
    var activeLink: String {
        didSet { store.set(activeLink, forKey: kActiveNode) }
    }
    
    var subscriptionLink: String {
        didSet { store.set(subscriptionLink, forKey: kSubscriptionURL) }
    }
    
    var links: [String] {
        didSet { store.set(links, forKey: kSubscriptionLinks) }
    }
    
    var nodeRTs: [String: Int] = [:] // link ->
    
    init() {
        let store = UserDefaults.standard
        
        activeLink = store.string(forKey: kActiveNode) ?? ""
        subscriptionLink = store.string(forKey: kSubscriptionURL) ?? ""
        links = store.array(forKey: kSubscriptionLinks) as? [String] ?? []
    }
    
    @MainActor func testNodeResponseTime() async {
        if links.isEmpty {
            return
        }
        return await withTaskGroup(of: (String, Int).self) { group in
            for link in self.links {
                if !link.starts(with: "vless://") {
                    continue
                }
                
                group.addTask {
                    return await Task(priority: .medium) {
                        let (host, ip) = Self.getServerAddress(link)
                        let rt = await Utils.measureRTVless(host: host, port: ip)
                        return (link, rt)
                    }.value
                }
            }
            
            for await result in group {
                self.nodeRTs[result.0] = result.1
            }
        }
    }
    
    @MainActor func syncSubscription() async throws {
        if subscriptionLink.isEmpty {
            throw V2Error.message("Subscription URL is not set.")
        }
        let url = URL(string: subscriptionLink)!
        let raw =  try await Task(priority: .medium) {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10
            let session = URLSession(configuration: config)
            let (data, _) = try await session.data(from: url)
            guard let base64 = String(data: data, encoding: .utf8) else {
                throw V2Error.message("Failed to decode the response data.")
            }
            guard let decoded = Data(base64Encoded: base64) else {
                throw V2Error.message("Failed to parse base64.")
            }
            guard let str = String(data: decoded, encoding: .utf8) else {
                throw V2Error.message("Failed to parse to utf-8")
            }
            let result = str.removingPercentEncoding ?? str
            return result
        }.value
        var links = raw.components(separatedBy: "\n")
        links.removeAll { $0.isEmpty }
        self.links = links
    }
    
    private static func getServerAddress(_ link: String) -> (String, UInt16) {
        let s0 = link.firstIndex(of: "@")!
        let s = link.index(s0, offsetBy: 1)
        let e = link.firstIndex(of: "?")!
        let address = link[s..<e]
        let part = address.components(separatedBy: ":")
        let host = part[0]
        let port = part[1]
        return (host, UInt16(port)!)
    }
}

fileprivate let kActiveNode = "N/ActiveNode" // link
fileprivate let kSubscriptionURL = "N/SubscriptionURL"
fileprivate let kSubscriptionLinks = "N/SubscriptionLinks" // [Link]
