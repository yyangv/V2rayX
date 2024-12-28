//
//  V2rayXTests.swift
//  V2rayXTests
//
//  Created by 杨洋 on 2024/11/17.
//

import Testing
import Foundation

@testable import V2rayX


struct V2rayXTests {
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        
        let a = "1,"
        let b = a.components(separatedBy: ",")
        debugPrint(a)
    }
}

func writeFile(_ filename: String, _ data: Data) {
    let url = URL.temporaryDirectory.appendingPathComponent(filename)
    debugPrint("write file at:", url.path)
    try! data.write(to: url)
}
