//
//  JSONResource.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import Foundation

struct JSONResource: Codable, Hashable, Sendable {
    var label: String
    var category: String
    var type: String
    var url: String
    
    init(label: String = "", category: String = "", type: String = "", url: String = "") {
            self.label = label
            self.category = category
            self.type = type
            self.url = url
        }

}

