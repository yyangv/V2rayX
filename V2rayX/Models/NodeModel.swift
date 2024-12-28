//
//  NodeModel.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/30.
//

import SwiftData

@Model class Node {
    var name: String
    var protocol0: String
    var link: String
    var selected: Bool
    
    init(link: String) {
        let name = link.components(separatedBy: "#")[1]
        let protocol0 = link.components(separatedBy: "://")[0]
        self.name = name
        self.protocol0 = protocol0
        self.link = link
        self.selected = false
    }
}
