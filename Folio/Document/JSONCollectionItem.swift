//
//  JSONCollectionItem.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import Foundation

struct JSONCollectionItem: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var type: String
    var label: String
    var summary: String?
    var filePath: AssetPath
    var thumbnail: AssetPath
    var resource: JSONResource

    init(
            id: UUID = UUID(),
            type: String = "",
            label: String = "",
            summary: String? = nil,
            filePath: AssetPath = AssetPath(),
            thumbnail: AssetPath = AssetPath(),
            resource: JSONResource = JSONResource()
        ) {
            self.id = id
            self.type = type
            self.label = label
            self.summary = summary
            self.filePath = filePath
            self.thumbnail = thumbnail
            self.resource = resource
        }
}
