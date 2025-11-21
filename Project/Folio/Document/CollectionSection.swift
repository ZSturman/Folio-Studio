//
//  CollectionSection.swift
//  Folio
//
//  Created by Zachary Sturman on 11/11/25.
//


struct CollectionSection: Codable, Equatable {
    var images: [String: AssetPath]
    var items: [JSONCollectionItem]

    init(images: [String: AssetPath] = [:], items: [JSONCollectionItem] = []) {
        self.images = images
        self.items = items
    }
}
