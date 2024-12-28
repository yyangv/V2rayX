//
//  Shared.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/13.
//

import Foundation

// MARK: - Constants

let OutboundProxyTag = XrayConfigBuilder.kOutboundProxyTag
let OutboundDirectTag = XrayConfigBuilder.kOutboundDirectTag
let OutboundRejectTag = XrayConfigBuilder.kOutboundRejectTag


// MARK: - Error

struct V2Error: Error, LocalizedError, CustomStringConvertible {
    let message: String
    
    var description: String {
        return message
    }
    
    init(_ message: String) {
        self.message = message
    }
}

extension Error {
    var message: String {
        return "\(self)"
    }
}

// MARK: - Extension

extension Int {
    var string: String {
        return String(self)
    }
}

extension String {
    var int: Int {
        return Int(self) ?? -1
    }
}

// MARK: - Coder

func jsonEncodeData<T: Encodable>(_ a: T ,formatting: JSONEncoder.OutputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = formatting
    return try! encoder.encode(a)
}

func jsonEncode<T: Encodable>(_ a: T , formatting: JSONEncoder.OutputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) -> String {
    let data = jsonEncodeData(a, formatting: formatting)
    return String(data: data, encoding: .utf8)!
}

func jsonDecode<T: Decodable>(_ raw: String) -> T? {
    if raw.isEmpty { return nil }
    let decoder = JSONDecoder()
    let data = raw.data(using: .utf8)!
    return try! decoder.decode(T.self, from: data)
}

// MARK: - JSON

enum JSON: Codable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)
    case array([JSON])
    case dict([String: JSON?])
    
    subscript(key: String) -> JSON? {
        get {
            if case .dict(let dict) = self {
                return dict[key]!
            } else {
                return nil
            }
        }
        set(newValue) {
            if case .dict(var dict) = self, let newValue = newValue {
                dict[key] = newValue
                self = .dict(dict)
            }
        }
    }
    
    func stringValue() -> String {
        if case .string(let s) = self {
            return s
        }
        return ""
    }
    
    func intValue() -> Int {
        if case .int(let i) = self {
            return i
        }
        return 0
    }
    
    func boolValue() -> Bool {
        if case .bool(let b) = self {
            return b
        }
        return false
    }
    
    func doubleValue() -> Double {
        if case .double(let d) = self {
            return d
        }
        return 0.0
    }
    
    func arrayValue() -> [JSON] {
        if case .array(let arr) = self {
            return arr
        }
        return []
    }
    
    func dictValue() -> [String: JSON?] {
        if case .dict(let dict) = self {
            return dict
        }
        return [:]
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let str = try? container.decode(String.self) {
            self = .string(str)
            return
        }
        
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
            return
        }
        
        if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
            return
        }
        
        if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
            return
        }
        
        if let arrayVal = try? container.decode([JSON].self) {
            self = .array(arrayVal)
            return
        }
        
        if let dictVal = try? container.decode([String: JSON?].self) {
            self = .dict(dictVal)
            return
        }
        
        throw DecodingError.typeMismatch(JSON.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown JSON type"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .int(let intVal):
            try container.encode(intVal)
        case .bool(let boolVal):
            try container.encode(boolVal)
        case .double(let doubleVal):
            try container.encode(doubleVal)
        case .array(let arrayVal):
            try container.encode(arrayVal)
        case .dict(let dictVal):
            var newDict: [String: JSON] = [:]
            for (key, val) in dictVal {
                if val == nil {
                    continue
                }
                if case .array(let arr) = val {
                    if arr.isEmpty {
                        continue
                    }
                }
                newDict[key] = val!
            }
            try container.encode(newDict)
        }
    }
}

extension String {
    var json: JSON { .string(self) }
}

extension Int {
    var json: JSON { .int(self) }
}

extension Bool {
    var json: JSON { .bool(self) }
}

extension Double {
    var json: JSON { .double(self) }
}

extension Array {
    var json: JSON {
        switch self {
        case let a as [String]:
            return .array(a.map { $0.json })
        case let a as [Int]:
            return .array(a.map { $0.json })
        case let a as [Bool]:
            return .array(a.map { $0.json })
        case let a as [Double]:
            return .array(a.map { $0.json })
        default:
            return .array(self as! [JSON])
        }
    }
}

extension Dictionary {
    var json: JSON {
        return .dict(self as! [String: JSON?])
    }
}
