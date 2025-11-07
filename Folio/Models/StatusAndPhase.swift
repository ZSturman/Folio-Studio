//
//  ProjectStatusModels.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import Foundation
import SwiftData

// MARK: - Models

@Model
final class ProjectStatus {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) private(set) var slug: String
    var name: String
    @Relationship(deleteRule: .cascade) var phases: [ProjectStatusPhase] = []

    var addedVia: AddedViaOption

    init(name: String, in context: ModelContext, addedVia: AddedViaOption = .manual) throws {
        self.id = UUID()
        self.name = name
        self.addedVia = addedVia
        self.slug = try Self.uniqueSlug(for: name, in: context)
    }

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

    fileprivate static func slugExists(_ slug: String, in context: ModelContext) throws -> Bool {
        let fd = FetchDescriptor<ProjectStatus>(
            predicate: #Predicate<ProjectStatus> { $0.slug == slug }
        )
        return try context.fetch(fd).isEmpty == false
    }
}

@Model
final class ProjectStatusPhase {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) private(set) var slug: String
    var name: String
    @Relationship(deleteRule: .nullify) var status: ProjectStatus

    var addedVia: AddedViaOption

    init(name: String, status: ProjectStatus, in context: ModelContext, addedVia: AddedViaOption = .manual) throws {
        self.id = UUID()
        self.name = name
        self.status = status
        self.addedVia = addedVia
        self.slug = try Self.uniqueSlug(for: name, in: context)
    }

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

    fileprivate static func slugExists(_ slug: String, in context: ModelContext) throws -> Bool {
        let fd = FetchDescriptor<ProjectStatusPhase>(
            predicate: #Predicate<ProjectStatusPhase> { $0.slug == slug }
        )
        return try context.fetch(fd).isEmpty == false
    }
}

// MARK: - Seeder

/// Seeds ProjectStatusItem and ProjectPhaseItem. Safe to call multiple times.
@MainActor
func seedProjectStatusCatalog(
    in context: ModelContext,
    addedVia: AddedViaOption = .system
) throws {
    let catalog: [String: [String]] = [
        "idea": [
            "referenceOnly",
            "scribble",
            "doodle",
            "hook",
            "concept",
            "inspiration",
            "jumpingOffPoint",
            "roughSketch",
            "potentialFeature",
            "potentialApp",
            "potentialMarket",
            "researchQuestion",
            "whiteBoardNote",
            "tentativeHypothesis",
            "thoughtExperiment",
            "problemStatementDraft",
            "speculativeAngle",
            "protoTheory",
            "causalGuess",
            "speculation",
            "roughPlan",
            "other"
        ],
        "onHold": [
            "notStarted",
            "needsRefactor",
            "researching",
            "other"
        ],
        "inProgress": [],
        "done": [
            "onDisplay",
            "published",
            "released",
            "submitted",
            "live",
            "other"
        ],
        "archived": [
            "notShared",
            "abandoned",
            "onHoldIndefinitely",
            "scrapForParts",
            "migrated",
            "other"
        ]
    ]

    for (statusName, phaseNames) in catalog {
        let statusSlug = statusName.slugified()

        // Fetch or create status
        let existingStatus: ProjectStatus? = try {
            let fd = FetchDescriptor<ProjectStatus>(
                predicate: #Predicate<ProjectStatus> { $0.slug == statusSlug }
            )
            return try context.fetch(fd).first
        }()

        let status: ProjectStatus
        if let s = existingStatus {
            status = s
        } else {
            status = try ProjectStatus(name: statusName, in: context, addedVia: addedVia)
            context.insert(status)
        }

        // Seed phases for this status
        for phaseName in phaseNames {
            let phaseSlug = phaseName.slugified()

            let existingPhase: ProjectStatusPhase? = try {
                let fd = FetchDescriptor<ProjectStatusPhase>(
                    predicate: #Predicate<ProjectStatusPhase> { $0.slug == phaseSlug }
                )
                return try context.fetch(fd).first
            }()

            if let p = existingPhase {
                if p.status.id != status.id {
                    p.status = status
                }
            } else {
                let p = try ProjectStatusPhase(
                    name: phaseName,
                    status: status,
                    in: context,
                    addedVia: addedVia
                )
                context.insert(p)
            }
        }
    }

    try context.save()
}
