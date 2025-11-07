//
//  Resource.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import Foundation
import SwiftData

@Model
final class ResourceItemCategory {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) private(set) var slug: String
    var name: String
    @Relationship(deleteRule: .cascade) var types: [ResourceItemType] = []
    
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
        let fd = FetchDescriptor<ResourceItemCategory>(
                   predicate: #Predicate<ResourceItemCategory> { $0.slug == slug }
               )
               return try context.fetch(fd).isEmpty == false
    }
}


@Model
final class ResourceItemType {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) private(set) var slug: String
    var name: String
    @Relationship(deleteRule: .nullify) var category: ResourceItemCategory
    
    var addedVia: AddedViaOption
    
    // Force correct slug creation at construction time
    init(name: String, category: ResourceItemCategory, in context: ModelContext, addedVia: AddedViaOption = .manual) throws {
        self.id = UUID()
        self.name = name
        self.category = category
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
        let fd = FetchDescriptor<ResourceItemType>(
            predicate: #Predicate<ResourceItemType> { $0.slug == slug }
        )
        return try context.fetch(fd).isEmpty == false
    }
}



/// Seeds ResourceItemCategory and ResourceItemType into SwiftData.
/// Call once during app startup after ModelContainer is ready.
@MainActor
func seedResourceCatalog(
    in context: ModelContext,
    addedVia: AddedViaOption = .system // or .manual if you prefer
) throws {
    // Source of truth. No enums.
    // key = category name, value = subtype names
    let catalog: [String: [String]] = [
        "repository": ["github", "gitlab", "bitbucket", "other"],
        "localDownload": [],
        "localLink": [],
        "app": ["windows", "macAppStore", "iosAppStore", "googlePlay", "steam", "other"],
        "url": ["none", "blog", "youtube", "overleaf", "docs", "slides", "dataset", "website", "other"],
        "other": ["email", "contactForm", "drive", "dropbox", "oneDrive", "notion", "figma", "arxiv", "zenodo", "kaggle", "huggingface", "other"]
    ]
    
    // Create/find categories, then create/find types under each
    for (categoryName, subtypeNames) in catalog {
        let categorySlug = categoryName.slugified()
        
        // Fetch existing category by slug
        let existingCategory: ResourceItemCategory? = try {
            let fd = FetchDescriptor<ResourceItemCategory>(
                predicate: #Predicate<ResourceItemCategory> { $0.slug == categorySlug },
                sortBy: []
            )
            return try context.fetch(fd).first
        }()
        
        let category: ResourceItemCategory
        if let found = existingCategory {
            category = found
        } else {
            // Create new category
            category = try ResourceItemCategory(name: categoryName, in: context, addedVia: addedVia)
            context.insert(category)
        }
        
        // Seed subtypes
        for subtypeName in subtypeNames {
            let typeSlug = subtypeName.slugified()
            
            // Check if a type with this slug already exists under any category
            let existingType: ResourceItemType? = try {
                let fd = FetchDescriptor<ResourceItemType>(
                    predicate: #Predicate<ResourceItemType> { $0.slug == typeSlug },
                    sortBy: []
                )
                return try context.fetch(fd).first
            }()
            
            if let t = existingType {
                // If it exists but is not linked to this category, relink
                if t.category.id != category.id {
                    t.category = category
                }
            } else {
                // Create new type under this category
                let t = try ResourceItemType(
                    name: subtypeName,
                    category: category,
                    in: context,
                    addedVia: addedVia
                )
                context.insert(t)
            }
        }
    }
    
    try context.save()
}
