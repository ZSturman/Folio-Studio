//
//  ProjectDomain.swift
//  Folio
//
//  Created by Zachary Sturman on 11/3/25.
//

import Foundation
import SwiftData

@Model
final class ProjectDomain {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) private(set) var slug: String
    var name: String
    
    @Relationship(deleteRule: .cascade, inverse: \ProjectCategory.domain)
    var categories: [ProjectCategory] = []
    
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
        let fd = FetchDescriptor<ProjectDomain>(
            predicate: #Predicate<ProjectDomain> { $0.slug == slug }
        )
        return try context.fetch(fd).isEmpty == false
    }
}


@Model
final class ProjectCategory {
    @Attribute(.unique) var id: UUID
    private(set) var slug: String
    var name: String
    var domain: ProjectDomain
    
    var addedVia: AddedViaOption
    
    // Force correct slug creation at construction time
    init(name: String, domain: ProjectDomain, in context: ModelContext, addedVia: AddedViaOption = .manual) throws {
        self.id = UUID()
        self.name = name
        self.domain = domain
        self.addedVia = addedVia
        self.slug = try Self.uniqueSlug(for: name, in: context, domain: domain)
    }
    
    // Optional: safe rename that re-slugifies and preserves uniqueness
    func rename(to newName: String, in context: ModelContext) throws {
        self.name = newName
        self.slug = try Self.uniqueSlug(for: newName, in: context, domain: domain)
    }
    
    private static func uniqueSlug(for name: String, in context: ModelContext, domain: ProjectDomain) throws -> String {
        let base = name.slugified()
        var candidate = base
        var n = 2

        while try slugExists(candidate, in: context, domain: domain) {
            candidate = "\(base)-\(n)"
            n += 1
        }
        return candidate
    }
    
    private static func slugExists(_ slug: String, in context: ModelContext, domain: ProjectDomain) throws -> Bool {
        let domainID = domain.id
        let fd = FetchDescriptor<ProjectCategory>(
            predicate: #Predicate<ProjectCategory> { $0.slug == slug && $0.domain.id == domainID }
        )
        return try context.fetch(fd).isEmpty == false
    }
}


// MARK: - Domain/Category Seeder

@MainActor
func seedDomainCatalog(
    in context: ModelContext,
    addedVia: AddedViaOption = .system
) throws {
    // Domain -> Categories
    let catalog: [String: [String]] = [
        "Technology": ["Software", "Hardware", "System"],
        "Creative":   ["Story", "Game", "Article", "Other"],
        "Expository": ["Article", "Essay", "Research", "Report", "Tutorial", "WhitePaper"]
    ]

    for (domainName, categoryNames) in catalog {
        let domainSlug = domainName.slugified()

        // Fetch or create domain by slug
        let existingDomain: ProjectDomain? = try {
            let fd = FetchDescriptor<ProjectDomain>(
                predicate: #Predicate<ProjectDomain> { $0.slug == domainSlug }
            )
            return try context.fetch(fd).first
        }()

        let domain: ProjectDomain
        if let d = existingDomain {
            domain = d
        } else {
            let d = try ProjectDomain(name: domainName, in: context, addedVia: addedVia)
            context.insert(d)
            domain = d
        }

        // Seed categories for this domain
        for catName in categoryNames {
            let catSlug = catName.slugified()
            
            let domainID = domain.id

            let existingCategory: ProjectCategory? = try {
                let fd = FetchDescriptor<ProjectCategory>(
                    predicate: #Predicate<ProjectCategory> { $0.slug == catSlug && $0.domain.id == domainID }
                )
                return try context.fetch(fd).first
            }()

            if let _ = existingCategory {
                // Already present for this domain
            } else {
                let c = try ProjectCategory(name: catName, domain: domain, in: context, addedVia: addedVia)
                context.insert(c)
            }
        }
    }

    try context.save()
}

