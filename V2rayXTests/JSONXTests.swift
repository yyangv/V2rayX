//
//  JSONXTests.swift
//  V2rayXTests
//
//  Created by 杨洋 on 2024/12/14.
//

import Testing
import Foundation

@testable import V2rayX

struct JSONXTests {
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        
        let json = JSON.dict([
            "test": JSON.string("123"),
            "test2": JSON.array([
                JSON.dict(
                    ["test": JSON.string("123")]
                ),
                JSON.array([JSON.int(123), JSON.double(2222.1)])
            ]),
            "test3": JSON.int(123),
            "test4": JSON.double(123.123),
            "test5": JSON.bool(true)
        ])
        let a = jsonEncode(json, formatting: .prettyPrinted)
        writeFile("testjson.json", a.data(using: .utf8)!)
    }
}
