//
//  V2rayXTests.swift
//  V2rayXTests
//
//  Created by 杨洋 on 2024/11/17.
//

import Testing
import Foundation
import SwiftData

@testable import V2rayX


@MainActor struct SwiftDataXTests {
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        run()
    }
    
    private func run() {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: true)
            let container = try ModelContainer(for: User.self, configurations: configuration)
            let ctx = container.mainContext
            
            // insert
            for i in 0 ..< 10 {
                let user = User(id: i, name: "name\(i)", idx: i)
                ctx.insert(user)
            }
            try ctx.save()
            
            // query
            let users = try ctx.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.id < 5 },
                sortBy: [.init(\.idx, order: .forward)]
            ))
            debugPrint(users.count)
            
            // modify
            let user1 = users.first!
            user1.name = "new name"
            try ctx.save()
            
            let users2 = try ctx.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.id < 5 },
                sortBy: [.init(\.idx, order: .forward)]
            ))
            debugPrint(users2.first!.string())
            
            // move
            var users3 = users2
            (users3[0], users3[1]) = (users3[1], users3[0])
            for (idx, u) in users3.enumerated() {
                u.idx = idx
            }
            debugPrint(users3[0].string())
            debugPrint(users3[1].string())
            try ctx.save()
            
            let users4 = try ctx.fetch(FetchDescriptor<User>(
                predicate: #Predicate { $0.id < 5 },
                sortBy: [.init(\.idx, order: .forward)]
            ))
            let u0 = users4[0]
            debugPrint("0: \(u0.string())")
            let u1 = users4[1]
            debugPrint("1: \(u1.string())")
            debugPrint("end")
        } catch {
            debugPrint("Error: \(error)")
        }
    }
}

@Model class User {
    var id: Int
    var name: String
    var idx: Int
    
    init(id: Int, name: String, idx: Int) {
        self.id = id
        self.name = name
        self.idx = idx
    }
    
    func string() -> String {
        return "id: \(id), name: \(name), idx: \(idx)"
    }
}
