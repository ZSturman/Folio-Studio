//
//  CustomFieldDefinition.swift
//  Folio
//
//  Created by Zachary Sturman on 11/19/25.
//

import Foundation

/// Represents a custom field definition stored app-wide in AppStorage.
struct CustomFieldDefinition: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var type: JSONType
    
    init(id: UUID = UUID(), name: String, type: JSONType) {
        self.id = id
        self.name = name
        self.type = type
    }
}

/// Type of JSON value for custom fields
enum JSONType: String, CaseIterable, Codable {
    case string = "String"
    case number = "Number"
    case bool = "Bool"
    case array = "Array"
    case object = "Object"
    case null = "Null"
    
    var displayName: String {
        rawValue
    }
}
