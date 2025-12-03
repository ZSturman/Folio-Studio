//
//  SeedDefaults.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import Foundation
import SwiftData


@MainActor
func seedIfNeeded_ResourceCatalog(in context: ModelContext) throws {
    // Strict one-time behavior. Never reseed unless ledger is removed.
    let key = "resourceCatalog.v1"

    if try ledgerExists(key: key, in: context) {
        return
    }

    try seedResourceCatalog(in: context, addedVia: .system)

    // Record success only after a successful seed.
    context.insert(SeedLedger(key: key, version: 1))
    try context.save()
}

@MainActor
func seedIfNeeded_ProjectStatusCatalog(in context: ModelContext) throws {
    let key = "projectStatusCatalog.v2"

    if try ledgerExists(key: key, in: context) {
        return
    }

    try seedProjectStatusCatalog(in: context, addedVia: .system)

    context.insert(SeedLedger(key: key, version: 2))
    try context.save()
}

@MainActor
func seedIfNeeded_DomainCatalog(in context: ModelContext) throws {
    let key = "domainCatalog.v1"

    if try ledgerExists(key: key, in: context) {
        return
    }

    try seedDomainCatalog(in: context, addedVia: .system)

    context.insert(SeedLedger(key: key, version: 1))
    try context.save()
}

private func ledgerExists(key: String, in context: ModelContext) throws -> Bool {
    let fd = FetchDescriptor<SeedLedger>(
        predicate: #Predicate<SeedLedger> { $0.key == key }
    )
    return try context.fetch(fd).isEmpty == false
}



@MainActor
func resetPresets(in context: ModelContext) throws {
    let systemCase = AddedViaOption.system

    // 1) Delete system-created Resource catalog
    let rTypes = try context.fetch(FetchDescriptor<ResourceItemType>(
        predicate: #Predicate<ResourceItemType> { $0.addedVia == systemCase }
    ))
    rTypes.forEach(context.delete)

    let rCats = try context.fetch(FetchDescriptor<ResourceItemCategory>(
        predicate: #Predicate<ResourceItemCategory> { $0.addedVia == systemCase }
    ))
    rCats.forEach(context.delete)

    // 2) Delete system-created Project Status/Phase
    let phases = try context.fetch(FetchDescriptor<ProjectStatusPhase>(
        predicate: #Predicate<ProjectStatusPhase> { $0.addedVia == systemCase }
    ))
    phases.forEach(context.delete)

    let statuses = try context.fetch(FetchDescriptor<ProjectStatus>(
        predicate: #Predicate<ProjectStatus> { $0.addedVia == systemCase }
    ))
    statuses.forEach(context.delete)

    // 3) Delete system-created Domains/Categories
    // Delete categories first (nullify rule on ProjectCategory.domain)
    let pCats = try context.fetch(FetchDescriptor<ProjectCategory>(
        predicate: #Predicate<ProjectCategory> { $0.addedVia == systemCase }
    ))
    pCats.forEach(context.delete)

    // Then delete domains (cascade rule also handles any remaining children)
    let pDomains = try context.fetch(FetchDescriptor<ProjectDomain>(
        predicate: #Predicate<ProjectDomain> { $0.addedVia == systemCase }
    ))
    pDomains.forEach(context.delete)

    // 4) Remove ledgers for these seeds
    let ledgers = try context.fetch(FetchDescriptor<SeedLedger>())
    for l in ledgers where
        l.key.hasPrefix("resourceCatalog.") ||
        l.key.hasPrefix("projectStatusCatalog.") ||
        l.key.hasPrefix("domainCatalog.")
    {
        context.delete(l)
    }

    try context.save()

    // 5) Rerun guarded seeds
    try seedIfNeeded_ResourceCatalog(in: context)
    try seedIfNeeded_ProjectStatusCatalog(in: context)
    try seedIfNeeded_DomainCatalog(in: context)
}
