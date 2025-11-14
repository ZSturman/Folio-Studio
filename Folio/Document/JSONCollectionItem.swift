//
//  JSONCollectionItem.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import Foundation

enum CollectionItemType: String, Codable, CaseIterable {
    case file = "File"
    case urlLink = "URL"
    case folio = "Folio"
}

struct JSONCollectionItem: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var type: CollectionItemType
    var label: String
    var summary: String?
    var filePath: AssetPath?
    var url: String?
    var thumbnail: AssetPath
    var resource: JSONResource
    
    init(
        id: UUID = UUID(),
        type: CollectionItemType = .file,
        label: String = "",
        summary: String? = nil,
        filePath: AssetPath? = nil,
        url: String? = nil,
        thumbnail: AssetPath = AssetPath(),
        resource: JSONResource = JSONResource()
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.summary = summary
        self.filePath = filePath
        self.url = url
        self.thumbnail = thumbnail
        self.resource = resource
    }
}
