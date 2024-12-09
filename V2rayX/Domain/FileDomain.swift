//
//  FileDomain.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/13.
//

import Foundation
import Zip

class FileDomain {
    static let shared = FileDomain()
    
    private let kStore = "Files"
    private let store = UserDefaults.standard
    
    private var downloaders: [String: Downloader] = [:] // file_id:
    
    func writeFile(name: String, group: String, data: Data, override: Bool = true) throws -> URL {
        let url = self.fileDir().appendingPathComponent(name)
        if FileManager.default.createFile(atPath: url.path, contents: data, attributes: nil) {
             throw V2Error("File write failed!")
        }
        let file = File.from(name: name, group: group)
        _ = self.create(file)
        return url
    }
    
    func list(id: String = "", group: String = "") -> [File] {
        let raws = store.stringArray(forKey: kStore) ?? []
        return raws.compactMap({ File.from(raw: $0) }).filter({ $0.id == id || $0.group == group })
    }
    
    func create(_ file: File) -> Error? {
        let raws = store.stringArray(forKey: kStore) ?? []
        if raws.contains(where: { $0.contains(file.id) }) {
            return V2Error("File already exists")
        }
        store.set(raws + [file.into()], forKey: kStore)
        return nil
    }
    
    func update(_ file: File) {
        let raws = store.stringArray(forKey: kStore) ?? []
        store.set(raws.map {
            if $0.contains(file.id) {
                return file.into()
            }
            return $0
        }, forKey: kStore)
    }
    
    func delete(_ id: String) {
        let raws = store.stringArray(forKey: kStore) ?? []
        guard let del = raws.first(where: { $0.contains(id) }) else { return }
        let file = File.from(raw: del)
        if file?.path != nil {
            try! FileManager.default.removeItem(atPath: file!.path!)
        }
        store.set(raws.filter { !$0.contains(id) }, forKey: kStore)
    }
    
    private func fileDir() -> URL {
        return URL.documentsDirectory.appendingPathComponent("Files")
    }
}

// MARK: - Not In Sandbox
extension FileDomain {
    func write(name: String, path: URL, data: Data, override: Bool = true) throws -> URL {
        let fullPath = path.appending(path: name)
        do {
            if override, FileManager.default.fileExists(atPath: fullPath.path) {
                try FileManager.default.removeItem(at: fullPath)
            }
            try data.write(to: fullPath)
        } catch {
            throw error
        }
        return fullPath
    }
}

// MARK: - unzip
extension FileDomain {
    func unzip(_ filePath: URL, toDir: URL) -> Error? {
        do {
           try Zip.unzipFile(filePath, destination: toDir, overwrite: true, password: nil)
        } catch {
            return error
        }
        return nil
    }
}

// MARK: - Github

extension FileDomain {
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
    
    private func extractGithubLink(_ raw: String, filename: String) -> String? {
        guard let a = raw.firstRange(of: "/\(filename)\"") else { return nil }
        guard let b = raw.range(of: "\"", options: .backwards, range: raw.startIndex..<a.lowerBound) else {
            return nil
        }
        let start = b.upperBound
        let end = raw.index(before: a.upperBound)
        return String(raw[start..<end])
    }
}


// MARK: Download

extension FileDomain {
    func download(
        group: String,
        link: String,
        override: Bool = true, update: Bool = false,
        onProgress: @escaping (Double) -> Void,
        onSaved: @escaping (URL) -> Void,
        onError: @escaping (Error) -> Void
    ) -> Error? {
        var file = File.from(group: group, link: link)
        guard let linkURL = URL(string: link) else { return V2Error("Invalid link") }
        let pathURL = self.fileDir()
        let download = Downloader(
            downloadLink: linkURL,
            saveTo: pathURL,
            override: override,
            onProgress: onProgress,
            onSaved: {
                file.path = pathURL.path
                let ts = Date().timeIntervalSince1970
                file.created_at = ts
                file.updated_at = ts
                if update {
                    self.update(file)
                } else {
                    _ = self.create(file)
                }
                onSaved(pathURL)
                self.downloaders.removeValue(forKey: file.id)
            },
            onError: {e in
                if update {
                    self.update(file)
                } else {
                    _ = self.create(file)
                }
                onError(e)
                self.downloaders.removeValue(forKey: file.id)
            }
        )
        downloaders[file.id] = download
        if let e = download.download() {
            return e
        }
        return nil
    }
    
    func cancelDownload(_ id: String) {
        downloaders[id]?.cancel()
        downloaders.removeValue(forKey: id)
    }
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
    
    func download() -> Error? {
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        self.task = self.session?.downloadTask(with: link)
        self.task?.resume()
        return nil
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

// MARK: Types

struct File: Codable {
    let id: String
    let name: String
    let group: String
    let link: String?
    var path: String?
    var error: String?
    var created_at: Double?
    var updated_at: Double?
    
    static func from(group: String, link: String) -> Self {
        let name = link.split(separator: "/").last!
        return Self(
            id: UUID().uuidString,
            name: String(name),
            group: group,
            link: link, path: nil,
            created_at: nil,
            updated_at: nil
        )
    }
    
    static func from(name: String, group: String) -> Self {
        return Self(
            id: UUID().uuidString,
            name: name,
            group: group,
            link: nil,
            path: nil,
            created_at: nil,
            updated_at: nil
        )
    }
    
    static func from(raw: String) -> Self? {
        if raw.isEmpty { return nil }
        return try! JSONDecoder().decode(File.self, from: raw.data(using: .utf8)!)
    }
    
    func into() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}
