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
    
    private func runCommand(bin: String, args: [String]) -> String {
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
    
    func getCoreVersion(_ bin: URL) -> String? {
        let data = runCommand(bin: bin.path, args: ["version"])
        if data.isEmpty { return nil }
        return "v\(data.components(separatedBy: " ")[1])"
    }
    
    // MARK: - Login Launch
    
    func registerLoginLaunch() {
        try! SMAppService.mainApp.register()
    }
    
    func unregisterLoginLaunch() {
        try! SMAppService.mainApp.unregister()
    }
    
    // MARK: - File
    
    func write(path: URL, data: Data, override: Bool = true) throws {
        do {
            if override, FileManager.default.fileExists(atPath: path.path) {
                try FileManager.default.removeItem(at: path)
            }
            try data.write(to: path)
        } catch {
            throw error
        }
    }
    
    func detectBinaryExecutable(_ bin: URL) -> Bool {
        let task = Process()
        task.executableURL = bin
        do { try task.run() } catch {
            return false
        }
        return true
    }
    
    // MARK: - Binary Executable Detection
    
    func openSystemSettingSecurity() {
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
    
    func measureRT(cb: @escaping (_ ms: Int) -> Void) {
        let url = URL(string: "https://www.google.com/generate_204")!
        let t0 = Date()
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            if error != nil { cb(-1); return}
            let duration = Date().timeIntervalSince(t0)
            cb(Int(duration * 1000))
        }
        task.resume()
    }
    
    func measureRTVless(host: String, port: UInt16, completion: @escaping (Int) -> Void) {
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
    
    func fetchGithubLatestReleaseDownloadLink(
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
                cb(nil, V2Error("Server returned an error: \(res.debugDescription)"))
            }
        }
        task.resume()
        return
    }
    
    func fetchGithubLatestVersion (
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
                    let result = self.extractGithubVersion(text)
                    cb(result!, nil)
                }
            } else {
                cb(nil, V2Error("Server returned an error: \(res.debugDescription)"))
            }
        }
        task.resume()
        return
    }
    
    private func extractGithubVersion(_ raw: String) -> String? {
        let pattern = "v([0-9\\.]+)"
        let a = raw.range(of: pattern, options: .regularExpression, range: raw.startIndex..<raw.endIndex)!
        let start = a.lowerBound
        let end = a.upperBound
        return String(raw[start..<end])
    }
    
    private func extractGithubLink(_ raw: String, filename: String) -> String? {
        guard let a = raw.firstRange(of: "/\(filename)\"") else { return nil }
        guard let b = raw.range(of: "\"", options: .backwards, range: raw.startIndex..<a.lowerBound) else {
            return nil
        }
        let start = b.upperBound
        let end = raw.index(before: a.upperBound)
        return String(raw[start..<end])
    }
    
    // MARK: - System Proxy Setting
    
    private static var preSystemProxy: [SystemProxyInfo] = []
    
    func registerSystemProxyWithSave(hh: String, hp: String, sh: String, sp: String) {
        Utils.preSystemProxy = getSystemProxyInfo()
        registerSystemProxy(hh: hh, hp: hp, sh: sh, sp: sp)
    }
    
    func restoreSystemProxy() {
        restoreSystemProxyInfo(Utils.preSystemProxy)
    }
    
    private func registerSystemProxy(hh: String, hp: String, sh: String, sp: String) {
        let bin = "/usr/sbin/networksetup"
        getNetworkInterfaces().forEach { network in
            _ = self.runCommand(bin: bin, args: ["-setwebproxy", network, hh, hp])
            _ = self.runCommand(bin: bin, args: ["-setwebproxystate", network, "on"])
            _ = self.runCommand(bin: bin, args: ["-setsecurewebproxy", network, hh, hp])
            _ = self.runCommand(bin: bin, args: ["-setsecurewebproxystate", network, "on"])
            _ = self.runCommand(bin: bin, args: ["-setsocksfirewallproxy", network, sh, sp])
            _ = self.runCommand(bin: bin, args: ["-setsocksfirewallproxystate", network, "on"])
        }
    }
    
    private func getSystemProxyInfo() ->  [SystemProxyInfo] {
        var r: [SystemProxyInfo] = []
        let bin = "/usr/sbin/networksetup"
        getNetworkInterfaces().forEach { network in
            let raw1 = self.runCommand(bin: bin, args: ["-getwebproxy", network])
            let raw2 = self.runCommand(bin: bin, args: ["-getsecurewebproxy", network])
            let raw3 = self.runCommand(bin: bin, args: ["-getsocksfirewallproxy", network])
            let a1 = handleSystemProxyGetInfo(raw: raw1)
            let a2 = handleSystemProxyGetInfo(raw: raw2)
            let a3 = handleSystemProxyGetInfo(raw: raw3)
            r.append(SystemProxyInfo(
                network: network,
                httpEnabled: a1.0,
                httpHost: a1.1,
                httpPort: a1.2,
                httpsEnabled: a2.0,
                httpsHost: a2.1,
                httpsPort: a2.2,
                socksEnabled: a3.0,
                socksHost: a3.1,
                socksPort: a3.2
            ))
        }
        return r
    }
    
    private func restoreSystemProxyInfo(_ infos: [SystemProxyInfo]) {
        let bin = "/usr/sbin/networksetup"
        infos.forEach { info in
            let network = info.network
            
            _ = self.runCommand(bin: bin, args: ["-setwebproxy", network, info.httpHost, String(info.httpPort)])
            _ = self.runCommand(bin: bin, args: ["-setsecurewebproxy", network, info.httpsHost, String(info.httpsPort)])
            _ = self.runCommand(bin: bin, args: ["-setsocksfirewallproxy", network, info.socksHost, String(info.socksPort)])
            
            _ = self.runCommand(bin: bin, args: ["-setwebproxystate", network, info.httpEnabled ? "on" : "off"])
            _ = self.runCommand(bin: bin, args: ["-setsecurewebproxystate", network, info.httpsEnabled ? "on" : "off"])
            _ = self.runCommand(bin: bin, args: ["-setsocksfirewallproxystate", network, info.socksEnabled ? "on" : "off"])
        }
    }
    
    private func handleSystemProxyGetInfo(raw: String) -> (Bool, String, Int) {
        var enabled: Bool = false
        var server: String = ""
        var port: Int = 0
        let lines = raw.split(separator: "\n")
            .filter({ !$0.starts(with: "Authenticated Proxy Enabled") })
        for line in lines {
            let part = line.split(separator: ": ")
            switch part[0] {
            case "Enabled":
                enabled = part[1] == "Yes"
            case "Server":
                server = String(part[1])
            case "Port":
                port = Int(part[1])!
            default:
                break
            }
        }
        return (enabled, server, port)
    }
    
    private func getNetworkInterfaces() -> [String] {
        return self.runCommand(bin: "/usr/sbin/networksetup", args: ["listallnetworkservices"])
            .split(separator: "\n")
            .filter({ !$0.starts(with: "An asterisk") })
            .map { String($0) }
    }
    
    // MARK: - Download
    
    private var downloaders: [String: Downloader] = [:]
    
    func download(
        downloadLink: URL,
        savePath: URL,
        override: Bool = true,
        onProgress: @escaping (Double) -> Void,
        onSaved: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) throws -> String {
        let id = downloadLink.path()
        let download = Downloader(
            downloadLink: downloadLink,
            saveTo: savePath,
            override: override,
            onProgress: onProgress,
            onSaved: {
                self.downloaders.removeValue(forKey: id)
                onSaved()
            },
            onError: {e in
                self.downloaders.removeValue(forKey: id)
                onError(e)
            }
        )
        downloaders[downloadLink.path] = download
        try download.download()
        return id
    }
    
    func cancelDownload(_ id: String) {
        downloaders[id]?.cancel()
        downloaders.removeValue(forKey: id)
    }
}

fileprivate struct SystemProxyInfo: Codable {
    let network: String
    
    let httpEnabled: Bool
    let httpHost: String
    let httpPort: Int
    
    let httpsEnabled: Bool
    let httpsHost: String
    let httpsPort: Int
    
    let socksEnabled: Bool
    let socksHost: String
    let socksPort: Int
}

fileprivate class Downloader: NSObject, URLSessionDelegate {
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    
    private let link: URL
    private var saveTo: URL
    private let override: Bool
    private let onProgress: (Double) -> Void
    private let onSaved: () -> Void
    private let onError: (Error) -> Void
    
    init(
        downloadLink: URL,
        saveTo: URL,
        override: Bool = false,
        onProgress: @escaping (Double) -> Void,
        onSaved: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.link = downloadLink
        self.saveTo = saveTo
        self.override = override
        self.onProgress = onProgress
        self.onSaved = onSaved
        self.onError = onError
    }
    
    func download() throws {
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        self.task = self.session?.downloadTask(with: link)
        self.task?.resume()
    }
    
    func cancel() {
        task?.cancel()
        session?.invalidateAndCancel()
    }
    
    func pause() {
        task?.suspend()
    }
    
    func resume() {
        task?.resume()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        self.onProgress(progress)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fm = FileManager.default
        if fm.fileExists(atPath: saveTo.path) {
            if override {
                try! fm.removeItem(at: saveTo)
            } else {
                let path = self.saveTo.path.split(separator: ".")[0].appending("_old")
                try! fm.moveItem(at: saveTo, to: URL(fileURLWithPath: path))
            }
        }
        try! fm.moveItem(at: location, to: saveTo)
        self.onSaved()
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
        if let error = error {
            self.onError(V2Error(error.localizedDescription))
        }
    }
}
