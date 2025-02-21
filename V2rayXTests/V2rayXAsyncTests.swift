//
//  V2rayXAsyncTests.swift
//  V2rayXTests
//
//  Created by 杨洋 on 2024/11/17.
//

import Testing
import Foundation

@testable import V2rayX

struct V2rayXAsyncTests {
    @Test func test_process() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["5"]
        
        do {
            try process.run()
            print("111111")
            process.waitUntilExit()
            print("222222")
        } catch {
            print("Failed to run the process: \(error)")
        }
    }
}


