//
//  FolioMigrationPlan.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static var folioDoc: UTType {
        UTType(exportedAs: "com.zachary-sturman.folio")
    }
}

struct FolioMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] = [
        FolioVersionedSchema.self,
    ]

    static var stages: [MigrationStage] = [
        // Stages of migration between VersionedSchema, if required.
    ]
}

struct FolioVersionedSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        ProjectDoc.self,
        ProjectDomain.self,
        ProjectGenre.self,
        ProjectMedium.self,
        ProjectSubject.self,
        ProjectTag.self,
        ProjectTopic.self,
        ResourceItemCategory.self,
        ResourceItemType.self,
        ProjectStatus.self,
        ProjectStatusPhase.self,
        SeedLedger.self
    ]
}
