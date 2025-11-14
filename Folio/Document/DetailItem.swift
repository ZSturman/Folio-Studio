//
//  DetailItem.swift
//  Folio
//
//  Created by Zachary Sturman on 11/8/25.
//

import Foundation


struct DetailItem: Codable, Identifiable, Equatable {
    var id: UUID
    var key: String
    var value: JSONValue

    init(id: UUID = UUID(), key: String, value: JSONValue) {
        self.id = id
        self.key = key
        self.value = value
    }
}
