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
    @Test func example() throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
//        print("hello: \("1asdadasdas".hashValue), \("2dfsfasdadasds".hashValue)")
    }
    
    @Test func extractStringTest() {
        let raw = ":aaaaa@123456:bbbbbb"
        let result = extractString(text: raw, start: "@", end: ":")!
        print(result)
    }
    
}

func writeFile(_ filename: String, _ data: Data) {
    let url = URL.temporaryDirectory.appendingPathComponent(filename)
    debugPrint("write file at:", url.path)
    try! data.write(to: url)
}

func extractString(text: String, start: String, end: String) -> String? {
    let pattern = "(?<=\(start))[^\(end)]+(?=\(end))"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return nil
    }
    let range = NSRange(text.startIndex..., in: text)
    if let match = regex.firstMatch(in: text, range: range) {
        return String(text[Range(match.range, in: text)!])
    }
    return nil
}
