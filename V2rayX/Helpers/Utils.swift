//
//  Utils.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/16.
//

import Foundation
import Network
import SwiftUI
import ServiceManagement

class Utils {
    static func getCoreVersion(_ bin: URL) async -> String? {
        let data = await runCommand(bin: bin.path, args: ["version"])
        if data.isEmpty { return nil }
        return "v\(data.components(separatedBy: " ")[1])"
    }
    
    // MARK: - Login Launch
    
    static func registerLoginLaunch() {
        try! SMAppService.mainApp.register()
    }
    
    static func unregisterLoginLaunch() {
        try! SMAppService.mainApp.unregister()
    }
    
    // MARK: - File
    
    static func write(path: URL, data: Data, override: Bool = true) async throws {
        return try await Task {
            if override, FileManager.default.fileExists(atPath: path.path) {
                try FileManager.default.removeItem(at: path)
            }
            try data.write(to: path)
        }.value
    }
    
    // MARK: - Binary Executable Detection
    
    static func checkBinaryExecutable(_ bin: URL) async -> Bool {
        return await Task {
            let task = Process()
            task.executableURL = bin
            do { try task.run() } catch {
                return false
            }
            return true
        }.value
    }
    
    // MARK: - Connection Test
    
    static func measureRT() async throws -> Int {
        return try await withUnsafeThrowingContinuation { cont in
            let url = URL(string: "https://www.google.com/generate_204")!
            let t0 = Date()
            let task = URLSession.shared.dataTask(with: url) { _, response, error in
                if error != nil { cont.resume(throwing: error!); return}
                let duration = Date().timeIntervalSince(t0)
                cont.resume(returning: Int(duration * 1000))
            }
            task.resume()
        }
    }
    
    static func measureRTVless(host: String, port: UInt16) async -> Int {
        return await withUnsafeContinuation { cont in
            let t0 = DispatchTime.now()
            var request = URLRequest(url: URL(string: "https://\(host):\(port)")!)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10
            let session = URLSession(configuration: .default)
            let task = session.dataTask(with: request) { _, response, error in
                if error != nil { cont.resume(returning: -1); return }
                if let res = response as? HTTPURLResponse {
                    if res.statusCode == 200 {
                        let t1 = DispatchTime.now()
                        let delta = (t1.uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000
                        cont.resume(returning: Int(delta))
                        return
                    }
                }
                cont.resume(returning: -1)
            }
            task.resume()
        }
    }
    
    // MARK: - Github
    
    static func fetchGithubLatestReleaseDownloadLink(
        owner: String,
        repo: String,
        fileName: String
    ) async throws -> String? {
        return try await withUnsafeThrowingContinuation { cont in
            let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
            let task = URLSession.shared.dataTask(with: url) { data, res, error in
                if let error = error { cont.resume(throwing: error); return }
                if let res = res as? HTTPURLResponse, res.statusCode == 200 {
                    if let data = data {
                        let text = String(data: data, encoding: .utf8)!
                        let result = extractGithubLink(text, filename: fileName)
                        cont.resume(returning: result)
                    }
                } else {
                    cont.resume(throwing: V2Error.message("Server returned an error: \(res.debugDescription)"))
                }
            }
            task.resume()
        }
    }
    
    static func fetchGithubLatestVersion (
        owner: String,
        repo: String
    ) async throws -> String? {
        return try await withUnsafeThrowingContinuation { cont in
            let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
            let task = URLSession.shared.dataTask(with: url) { data, res, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let res = res as? HTTPURLResponse, res.statusCode == 200 {
                    if let data = data {
                        let text = String(data: data, encoding: .utf8)!
                        let result = extractGithubVersion(text)
                        cont.resume(returning: result!)
                    }
                } else {
                    cont.resume(throwing: V2Error.message("error: \(res.debugDescription)"))
                }
            }
            task.resume()
        }
    }
    
    private static func extractGithubVersion(_ raw: String) -> String? {
        let pattern = "v([0-9\\.]+)"
        let a = raw.range(of: pattern, options: .regularExpression, range: raw.startIndex..<raw.endIndex)!
        let start = a.lowerBound
        let end = a.upperBound
        return String(raw[start..<end])
    }
    
    private static func extractGithubLink(_ raw: String, filename: String) -> String? {
        guard let a = raw.firstRange(of: "/\(filename)\"") else { return nil }
        guard let b = raw.range(of: "\"", options: .backwards, range: raw.startIndex..<a.lowerBound) else {
            return nil
        }
        let start = b.upperBound
        let end = raw.index(before: a.upperBound)
        return String(raw[start..<end])
    }
}
