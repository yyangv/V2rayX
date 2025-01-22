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
    
    func testNodeResponseTime(_ onCompleted: @escaping ()->Void) {
        if links.isEmpty {
            onCompleted()
            return
        }
        var total = 0
        var count = 0
        for i in 0..<links.count {
            let link = links[i]
            if !link.starts(with: "vless://") {
                continue
            }
            total += 1
            let (host, ip) = getServerAddress(link)
            Utils.measureRTVless(host: host, port: ip) { ms in
                DispatchQueue.main.async {
                    self.nodeRTs[link] = ms
                    count += 1
                    if total == count {
                        onCompleted()
                    }
                }
            }
        }
    }
    
    func syncSubscription(_ onCompleted: @escaping (Error?)->Void) {
        if subscriptionLink.isEmpty {
            onCompleted(V2Error.message("Subscription URL is not set."))
            return
        }
        let url = URL(string: subscriptionLink)!
        Task {
            do {
                let raw = try await fetchSubscription(url: url)
                var links = raw.components(separatedBy: "\n")
                links.removeAll { $0.isEmpty }
                self.links = links
                onCompleted(nil)
            } catch {
                onCompleted(error)
            }
        }
    }
    
    private func fetchSubscription(url: URL) async throws -> String {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let base64 = String(data: data, encoding: .utf8),
               let decoded = Data(base64Encoded: base64) {
                if let str = String(data: decoded, encoding: .utf8) {
                    let result = str.removingPercentEncoding ?? str
                    return result
                } else {
                    throw V2Error.message("Failed to decode the response")
                }
            } else {
                throw V2Error.message("Failed to decode the response")
            }
        } catch {
            throw V2Error.Err(error)
        }
    }
    
    private func getServerAddress(_ link: String) -> (String, UInt16) {
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
