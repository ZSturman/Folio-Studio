//
//  FolioApp.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct FolioApp: App {
    var body: some Scene {
        DocumentGroup(editing: .itemDocument, migrationPlan: FolioMigrationPlan.self) {
            ContentView()
        }
    }
}

extension UTType {
    static var itemDocument: UTType {
        UTType(importedAs: "com.example.item-document")
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
        Item.self,
    ]
}
