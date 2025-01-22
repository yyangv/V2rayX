//
//  Downloader.swift
//  V2rayX
//
//  Created by 杨洋 on 2025/1/21.
//

import Foundation

class DownloadManager {
    static let shared = DownloadManager()
    
    private var downloaders: [String: Downloader] = [:] // link ->
    
    func download(
        link: URL,
        saveTo: URL,
        override: Bool = true,
        onProgress: @escaping (Double) -> Void,
        onSaved: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) -> String {
        let id = link.path()
        let download = Downloader(
            link: link,
            saveTo: saveTo,
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
        download.start()
        downloaders[id] = download
        return id
    }
    
    func resume(id: String) {
        downloaders[id]?.resume()
    }
    
    func pause(id: String) {
        downloaders[id]?.pause()
    }
    
    func cancel(id: String) {
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
        link: URL,
        saveTo: URL,
        override: Bool = false,
        onProgress: @escaping (Double) -> Void,
        onSaved: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.link = link
        self.saveTo = saveTo
        self.override = override
        self.onProgress = onProgress
        self.onSaved = onSaved
        self.onError = onError
    }
    
    func start() {
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        self.task = self.session?.downloadTask(with: link)
        self.resume()
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
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
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
            self.onError(error)
        }
    }
}
