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
    static let shared = Utils()
    
    static func runCommand(bin: String, args: [String]) -> String {
        let task = Process()
        task.launchPath = bin
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    static func getCoreVersion(_ bin: URL) -> String? {
        let data = runCommand(bin: bin.path, args: ["version"])
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
    
    static func write(path: URL, data: Data, override: Bool = true) throws {
        do {
            if override, FileManager.default.fileExists(atPath: path.path) {
                try FileManager.default.removeItem(at: path)
            }
            try data.write(to: path)
        } catch {
            throw error
        }
    }
    
    // MARK: - Binary Executable Detection
    
    static func checkBinaryExecutable(_ bin: URL) -> Bool {
        let task = Process()
        task.executableURL = bin
        do { try task.run() } catch {
            return false
        }
        return true
    }
    
    static func openSystemSettingSecurity() {
        let alert = NSAlert()
        alert.messageText = "Unable to run the xray-core program"
        alert.informativeText = "The application has been blocked from running. Please open System Preferences > Security & Privacy > General and allow this app to run."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Go to Settings")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?General") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Connection Test
    
    static func measureRT(cb: @escaping (_ ms: Int) -> Void) {
        let url = URL(string: "https://www.google.com/generate_204")!
        let t0 = Date()
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            if error != nil { cb(-1); return}
            let duration = Date().timeIntervalSince(t0)
            cb(Int(duration * 1000))
        }
        task.resume()
    }
    
    static func measureRTVless(host: String, port: UInt16, completion: @escaping (Int) -> Void) {
        let t0 = DispatchTime.now()
        var request = URLRequest(url: URL(string: "https://\(host):\(port)")!)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { _, response, error in
            if error != nil {
                completion(-1)
                return
            }
            if let res = response as? HTTPURLResponse {
                if res.statusCode == 200 {
                    let t1 = DispatchTime.now()
                    let delta = (t1.uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000
                    completion(Int(delta))
                    return
                }
            }
            completion(-1)
        }
        task.resume()
    }
    
    // MARK: - Github
    
    static func fetchGithubLatestReleaseDownloadLink(
        owner: String,
        repo: String,
        fileName: String,
        cb: @escaping (String?, Error?) -> Void
    ) {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        
        let task = URLSession.shared.dataTask(with: url) { data, res, error in
            if let error = error {
                cb(nil, error)
                return
            }
            if let res = res as? HTTPURLResponse, res.statusCode == 200 {
                if let data = data {
                    let text = String(data: data, encoding: .utf8)!
                    let result = self.extractGithubLink(text, filename: fileName)
                    cb(result!, nil)
                }
            } else {
                cb(nil, V2Error.message("Server returned an error: \(res.debugDescription)"))
            }
        }
        task.resume()
        return
    }
    
    static func fetchGithubLatestVersion (
        owner: String,
        repo: String,
        _ cb: @escaping (String?, Error?) -> Void
    ) {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        
        let task = URLSession.shared.dataTask(with: url) { data, res, error in
            if let error = error {
                cb(nil, error)
                return
            }
            if let res = res as? HTTPURLResponse, res.statusCode == 200 {
                if let data = data {
                    let text = String(data: data, encoding: .utf8)!
                    let result = extractGithubVersion(text)
                    cb(result!, nil)
                }
            } else {
                cb(nil, V2Error.message("Server returned an error: \(res.debugDescription)"))
            }
        }
        task.resume()
        return
    }
    
    static private func extractGithubVersion(_ raw: String) -> String? {
        let pattern = "v([0-9\\.]+)"
        let a = raw.range(of: pattern, options: .regularExpression, range: raw.startIndex..<raw.endIndex)!
        let start = a.lowerBound
        let end = a.upperBound
        return String(raw[start..<end])
    }
    
    static private func extractGithubLink(_ raw: String, filename: String) -> String? {
        guard let a = raw.firstRange(of: "/\(filename)\"") else { return nil }
        guard let b = raw.range(of: "\"", options: .backwards, range: raw.startIndex..<a.lowerBound) else {
            return nil
        }
        let start = b.upperBound
        let end = raw.index(before: a.upperBound)
        return String(raw[start..<end])
    }
}
