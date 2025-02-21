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
    @Test func test_async() {
        debugPrint("start")
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000 * 2)
            debugPrint("done")
        }
        debugPrint("end")
        while true {
        }
    }
}


