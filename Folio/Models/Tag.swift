//
//  ProjectTag.swift
//  Folio
//
//  Created by Zachary Sturman on 11/3/25.
//

import Foundation
import SwiftData

@Model
final class ProjectTag {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) private(set) var slug: String
    
    @Relationship(deleteRule: .nullify, inverse: \ProjectDoc.tags)
     var docs: [ProjectDoc] = []

    var name: String
    var addedVia: AddedViaOption

    // Force correct slug creation at construction time
    init(name: String, in context: ModelContext, addedVia: AddedViaOption = .manual) throws {
        self.id = UUID()
        self.name = name
        self.addedVia = addedVia
        self.slug = try Self.uniqueSlug(for: name, in: context)
    }

    // Optional: safe rename that re-slugifies and preserves uniqueness
    func rename(to newName: String, in context: ModelContext) throws {
        self.name = newName
        self.slug = try Self.uniqueSlug(for: newName, in: context)
    }

    private static func uniqueSlug(for name: String, in context: ModelContext) throws -> String {
        let base = name.slugified()
        var candidate = base
        var n = 2

        while try slugExists(candidate, in: context) {
            candidate = "\(base)-\(n)"
            n += 1
        }
        return candidate
    }

    private static func slugExists(_ slug: String, in context: ModelContext) throws -> Bool {
        let fd = FetchDescriptor<ProjectTag>(
            predicate: #Predicate<ProjectTag> { $0.slug == slug }
        )
        return try context.fetch(fd).isEmpty == false
    }
}
