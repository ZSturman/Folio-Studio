//
//  SwiftDataCoordinator.swift
//  Folio
//
//  Created by Zachary Sturman on 11/5/25.
//

import Foundation
import SwiftData
import Combine

// MARK: - Background store actor

actor SDStore {
    private let ctx: ModelContext

    private func slog(_ message: String, function: String = #function) {
        print("[SDStore] \(function): \(message)")
    }

    init(container: ModelContainer) {
        let c = ModelContext(container)
        c.autosaveEnabled = false
        self.ctx = c
    }

    /// Run work on the isolated context and return a value.
    func perform<T>(_ work: (ModelContext) throws -> T) rethrows -> T {
        slog("perform begin")
        let result = try work(ctx)
        slog("perform end")
        return result
    }
}

// MARK: - Protocol

protocol SwiftDataCoordinating {
    /// Reconcile or create the ProjectDoc at open time.
    func reconcileOnOpen(from doc: FolioDocument, fileURL: URL) async -> Result<Void, SwiftDataError>

    /// Debounced title update. Succeeds if enqueued. Use `flushTitleChange` to force persistence.
    func enqueueTitleChange(_ title: String, for docID: UUID) -> Result<Void, SwiftDataError>
    
    func enqueueIsPublicChange(_ isPublic: Bool, for docID: UUID) -> Result<Void, SwiftDataError>
    
    func enqueueDomainChange(_ domain: String, for docID: UUID) -> Result<Void, SwiftDataError>
    
    func enqueueCategoryChange(_ category: String, for docID: UUID) -> Result<Void, SwiftDataError>
    
    func enqueueStatusChange(_ status: String, for docID: UUID) -> Result<Void, SwiftDataError>
    
    func enqueueStatusPhaseChange(_ statusPhase: String, for docID: UUID) -> Result<Void, SwiftDataError>
    
    func enqueueTagChange(added: [String], removed: [String], for docID:UUID) -> Result<Void, SwiftDataError>
    
    func enqueueMediumsChange(added: [String], removed: [String], for docID:UUID) -> Result<Void, SwiftDataError>
    
    func enqueueGenresChange(added: [String], removed: [String], for docID:UUID) -> Result<Void, SwiftDataError>
    
    func enqueueTopicsChange(added: [String], removed: [String], for docID:UUID) -> Result<Void, SwiftDataError>
    
    func enqueueSubjectsChange(added: [String], removed: [String], for docID:UUID) -> Result<Void, SwiftDataError>
    

    /// Immediately persist any pending change for this doc.
    func flushSwiftDataChange(for docID: UUID) async -> Result<Void, SwiftDataError>

    /// Create if missing, else upsert and return the stored object.
    func createNewProjectDoc(from doc: FolioDocument, fileURL: URL) async -> Result<Void, SwiftDataError>

}

// MARK: - Coordinator
final class SwiftDataCoordinator: ObservableObject, SwiftDataCoordinating {
    private var store: SDStore?

    // Debounce storage for small deltas
    private var changeTimers: [UUID: DispatchSourceTimer] = [:]
    private struct PendingChange {
        var title: String?
        var isPublic: Bool?
        var domain: String?
        var category: String?
        var status: String?
        var phase: String?
        var tagsAdded: [String] = []
        var tagsRemoved: [String] = []
        var mediumsAdded: [String] = []
        var mediumsRemoved: [String] = []
        var genresAdded: [String] = []
        var genresRemoved: [String] = []
        var topicsAdded: [String] = []
        var topicsRemoved: [String] = []
        var subjectsAdded: [String] = []
        var subjectsRemoved: [String] = []
        var hasAnyChange: Bool {
            return title != nil || isPublic != nil || domain != nil || category != nil || status != nil || phase != nil ||
            !tagsAdded.isEmpty || !tagsRemoved.isEmpty || !mediumsAdded.isEmpty || !mediumsRemoved.isEmpty ||
            !genresAdded.isEmpty || !genresRemoved.isEmpty || !topicsAdded.isEmpty || !topicsRemoved.isEmpty ||
            !subjectsAdded.isEmpty || !subjectsRemoved.isEmpty
        }
    }
    private var pending: [UUID: PendingChange] = [:]
    let objectWillChange = ObservableObjectPublisher()

    private func log(_ message: String, function: String = #function) {
        print("[SDC] \(function): \(message)")
    }

    @MainActor func bind(using envContext: ModelContext) {
        log("bind called. store exists? \(store != nil)")
        if store == nil { store = SDStore(container: envContext.container) }
        log("bind finished. store exists? \(store != nil)")
    }

    // MARK: - Helpers

    // Detach helpers
    private enum AssocKind { case tag, medium, genre, topic, subject }

    /// Immediately detach the given names from the doc, and delete the association object if it becomes orphaned.
    private func detachIfPresent(_ kind: AssocKind, names: [String], for docID: UUID) {
        guard let store else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await store.perform { ctx in
                    guard let pd = try self.fetchProjectDoc(id: docID, in: ctx) else { return }
                    var touched = false

                    func maybeDeleteOrphan<T>(_ value: T, docsCount: Int) where T: PersistentModel {
                        if docsCount == 0 { ctx.delete(value) }
                    }

                    for raw in names {
                        let slug = raw.slugified()
                        switch kind {
                        case .tag:
                            if let v = try self.fetchTag(slug: slug, in: ctx) {
                                let before = pd.tags.count
                                pd.tags.removeAll { $0.id == v.id }
                                if pd.tags.count != before {
                                    touched = true
                                    maybeDeleteOrphan(v, docsCount: v.docs.count)
                                }
                            }
                        case .medium:
                            if let v = try self.fetchMedium(slug: slug, in: ctx) {
                                let before = pd.mediums.count
                                pd.mediums.removeAll { $0.id == v.id }
                                if pd.mediums.count != before {
                                    touched = true
                                    maybeDeleteOrphan(v, docsCount: v.docs.count)
                                }
                            }
                        case .genre:
                            if let v = try self.fetchGenre(slug: slug, in: ctx) {
                                let before = pd.genres.count
                                pd.genres.removeAll { $0.id == v.id }
                                if pd.genres.count != before {
                                    touched = true
                                    maybeDeleteOrphan(v, docsCount: v.docs.count)
                                }
                            }
                        case .topic:
                            if let v = try self.fetchTopic(slug: slug, in: ctx) {
                                let before = pd.topics.count
                                pd.topics.removeAll { $0.id == v.id }
                                if pd.topics.count != before {
                                    touched = true
                                    maybeDeleteOrphan(v, docsCount: v.docs.count)
                                }
                            }
                        case .subject:
                            if let v = try self.fetchSubject(slug: slug, in: ctx) {
                                let before = pd.subjects.count
                                pd.subjects.removeAll { $0.id == v.id }
                                if pd.subjects.count != before {
                                    touched = true
                                    maybeDeleteOrphan(v, docsCount: v.docs.count)
                                }
                            }
                        }
                    }

                    if touched {
                        // Removed pd.updatedAt assignment here per instructions
                        try? ctx.save()
                    }
                }
            } catch {
                // detach errors are intentionally non-fatal in enqueue path
            }
        }
    }

    private func scheduleDebounce(for docID: UUID) {
        if let t = changeTimers[docID] { t.cancel() }
        let q = DispatchQueue(label: "sd.change.\(docID.uuidString)")
        let timer = DispatchSource.makeTimerSource(queue: q)
        changeTimers[docID] = timer
        timer.schedule(deadline: .now() + 0.75)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.log("debounce timer fired id=\(docID)")
            let change = self.pending.removeValue(forKey: docID)
            self.changeTimers.removeValue(forKey: docID)
            guard let change, change.hasAnyChange, let store = self.store else { return }
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await store.perform { ctx in
                        try self.applyPendingChange(change, to: docID, in: ctx)
                    }
                } catch {
                    // debounced path swallows errors by design
                }
            }
        }
        timer.resume()
    }

    private func applyPendingChange(_ change: PendingChange, to docID: UUID, in ctx: ModelContext) throws {
        guard let pd = try fetchProjectDoc(id: docID, in: ctx) else { return }
        var changed = false

        if let title = change.title, pd.title != title { pd.title = title; changed = true }
        if let isPublic = change.isPublic, pd.isPublic != isPublic { pd.isPublic = isPublic; changed = true }

        // singletons via upsert
        if let d = change.domain {
            let domain = try upsertDomain(name: d, in: ctx)
            if pd.domain?.id != domain?.id { pd.domain = domain; changed = true }
        }
        if let c = change.category {
            let category = try upsertCategory(name: c, domain: pd.domain, in: ctx)
            if pd.category?.id != category?.id { pd.category = category; changed = true }
        }
        if let s = change.status {
            let status = try upsertProjectStatus(name: s, in: ctx, addedVia: .manual)
            if pd.status?.id != status?.id { pd.status = status; changed = true }
        }
        if let p = change.phase {
            let phase = try upsertProjectStatusPhase(name: p, status: pd.status, in: ctx, addedVia: .manual)
            if pd.phase?.id != phase?.id { pd.phase = phase; changed = true }
        }

        // helpers for arrays
        func ensureUniqueAppend<T: Identifiable>(_ item: T, into array: inout [T]) where T.ID == UUID {
            if !array.contains(where: { $0.id == item.id }) { array.append(item) }
        }
        // tags
        if !change.tagsAdded.isEmpty || !change.tagsRemoved.isEmpty {
            // add
            for name in change.tagsAdded {
                let tag = try upsertTag(name: name, in: ctx)
                let before = pd.tags.count
                ensureUniqueAppend(tag, into: &pd.tags)
                if pd.tags.count != before { changed = true }
            }
            // remove
            for name in change.tagsRemoved {
                let slug = name.slugified()
                if let existing = try fetchTag(slug: slug, in: ctx) {
                    let before = pd.tags.count
                    pd.tags.removeAll { $0.id == existing.id }
                    if pd.tags.count != before { changed = true }
                }
            }
        }
        // mediums
        if !change.mediumsAdded.isEmpty || !change.mediumsRemoved.isEmpty {
            for name in change.mediumsAdded { let v = try upsertMedium(name: name, in: ctx); let b = pd.mediums.count; ensureUniqueAppend(v, into: &pd.mediums); if pd.mediums.count != b { changed = true } }
            for name in change.mediumsRemoved { if let v = try fetchMedium(slug: name.slugified(), in: ctx) { let b = pd.mediums.count; pd.mediums.removeAll { $0.id == v.id }; if pd.mediums.count != b { changed = true } } }
        }
        // genres
        if !change.genresAdded.isEmpty || !change.genresRemoved.isEmpty {
            for name in change.genresAdded { let v = try upsertGenre(name: name, in: ctx); let b = pd.genres.count; ensureUniqueAppend(v, into: &pd.genres); if pd.genres.count != b { changed = true } }
            for name in change.genresRemoved { if let v = try fetchGenre(slug: name.slugified(), in: ctx) { let b = pd.genres.count; pd.genres.removeAll { $0.id == v.id }; if pd.genres.count != b { changed = true } } }
        }
        // topics
        if !change.topicsAdded.isEmpty || !change.topicsRemoved.isEmpty {
            for name in change.topicsAdded { let v = try upsertTopic(name: name, in: ctx); let b = pd.topics.count; ensureUniqueAppend(v, into: &pd.topics); if pd.topics.count != b { changed = true } }
            for name in change.topicsRemoved { if let v = try fetchTopic(slug: name.slugified(), in: ctx) { let b = pd.topics.count; pd.topics.removeAll { $0.id == v.id }; if pd.topics.count != b { changed = true } } }
        }
        // subjects
        if !change.subjectsAdded.isEmpty || !change.subjectsRemoved.isEmpty {
            for name in change.subjectsAdded { let v = try upsertSubject(name: name, in: ctx); let b = pd.subjects.count; ensureUniqueAppend(v, into: &pd.subjects); if pd.subjects.count != b { changed = true } }
            for name in change.subjectsRemoved { if let v = try fetchSubject(slug: name.slugified(), in: ctx) { let b = pd.subjects.count; pd.subjects.removeAll { $0.id == v.id }; if pd.subjects.count != b { changed = true } } }
        }

        if changed {
            // Removed pd.updatedAt assignment here per instructions
            do { try ctx.save() } catch { throw SwiftDataError.unknown("Save failed: \(error)") }
        }
    }

    private func fetchProjectDoc(id: UUID, in ctx: ModelContext) throws -> ProjectDoc? {
        log("fetchProjectDoc id=\(id)")
        let d = FetchDescriptor<ProjectDoc>(predicate: #Predicate { $0.id == id })
        let result = try ctx.fetch(d).first
        log("fetchProjectDoc -> \(result != nil ? "found" : "nil")")
        return result
    }

    // MARK: - API

    func createNewProjectDoc(from doc: FolioDocument, fileURL: URL) async -> Result<Void, SwiftDataError> {
        log("createNewProjectDoc begin id=\(doc.id) title=\"\(doc.title)\" path=\(fileURL.path)")
        guard let store else { return .failure(.unknown("Store not bound")) }
        do {
            try await store.perform { ctx in
                log("createNewProjectDoc: checking existing ProjectDoc")
                if let existing = try self.fetchProjectDoc(id: doc.id, in: ctx) {
                    var changed = false
                    if existing.filePath != fileURL.path { existing.filePath = fileURL.path; changed = true }
                    if existing.title != doc.title { existing.title = doc.title; changed = true }
                    if existing.isPublic != doc.isPublic { existing.isPublic = doc.isPublic; changed = true }
                    if changed {
                        // Removed existing.updatedAt assignment here per instructions
                        do { try ctx.save() } catch { throw SwiftDataError.unknown("Save failed: \(error)") }
                        log("createNewProjectDoc: updated existing doc id=\(existing.id)")
                    }
                } else {
                    // Create new ProjectDoc
                    let pd = ProjectDoc(
                        id: doc.id,
                        title: doc.title,
                        filePath: fileURL.path,
                        updatedAt: Date(),
                        isPublic: doc.isPublic,
                        status: nil,
                        phase: nil,
                        domain: nil,
                        category: nil,
                        tags: [],
                        mediums: [],
                        genres: [],
                        topics: [],
                        subjects: []
                    )
                    log("createNewProjectDoc: inserting new ProjectDoc id=\(pd.id)")
                    ctx.insert(pd)
                    do { try ctx.save() } catch { throw SwiftDataError.unknown("Save failed: \(error)") }
                    log("createNewProjectDoc: inserted and saved id=\(pd.id)")
                }
            }
            log("createNewProjectDoc success id=\(doc.id)")
            return .success(())
        } catch let e as SwiftDataError {
            log("createNewProjectDoc failure \(e)")
            return .failure(e)
        } catch {
            log("createNewProjectDoc unexpected error \(error)")
            return .failure(.unknown("Unexpected error: \(error)"))
        }
    }

    
    // A value container for what we resolved in SwiftData
    private struct Associations {
        let status: ProjectStatus?
        let phase: ProjectStatusPhase?
        let domain: ProjectDomain?
        let category: ProjectCategory?
        let tags: [ProjectTag]
        let mediums: [ProjectMedium]
        let genres: [ProjectGenre]
        let topics: [ProjectTopic]
        let subjects: [ProjectSubject]
    }

    /// Build or reuse all related models by name, using unique slug creation.
    /// Runs in the SwiftData context. Does not touch UI objects.
    private func resolveAssociations(from doc: FolioDocument,
                                     in context: ModelContext) throws -> Associations {
        log("resolveAssociations begin id=\(doc.id) tags=\(doc.tags.count) mediums=\(doc.mediums.count) genres=\(doc.genres.count) topics=\(doc.topics.count) subjects=\(doc.subjects.count)")
        let statusName = doc.status
        let phaseName  = doc.phase
        let domainName = doc.domain
        let categoryName = doc.category

        let domain = try upsertDomain(name: domainName, in: context)
        let category = try upsertCategory(name: categoryName, domain: domain, in: context)
        let status = try upsertProjectStatus(name: statusName, in: context, addedVia: .docImport)
        let phase = try upsertProjectStatusPhase(name: phaseName, status: status, in: context, addedVia: .docImport)

        let tags     = try doc.tags.map     { try upsertTag(name: $0, in: context) }
        let mediums  = try doc.mediums.map  { try upsertMedium(name: $0, in: context) }
        let genres   = try doc.genres.map   { try upsertGenre(name: $0, in: context) }
        let topics   = try doc.topics.map   { try upsertTopic(name: $0, in: context) }
        let subjects = try doc.subjects.map { try upsertSubject(name: $0, in: context) }

        log("resolveAssociations resolved status=\(String(describing: status?.name)) phase=\(String(describing: phase?.name)) domain=\(String(describing: domain?.name)) category=\(String(describing: category?.name))")
        return Associations(status: status,
                            phase: phase,
                            domain: domain,
                            category: category,
                            tags: tags,
                            mediums: mediums,
                            genres: genres,
                            topics: topics,
                            subjects: subjects)
    }
    

    func reconcileOnOpen(from doc: FolioDocument, fileURL: URL) async -> Result<Void, SwiftDataError> {
        log("reconcileOnOpen begin id=\(doc.id) title=\"\(doc.title)\" path=\(fileURL.path)")
        guard let store else { return .failure(.unknown("Store not bound")) }
        do {
            try await store.perform { ctx in
                // Build or reuse all associations from the document first
                let assoc = try self.resolveAssociations(from: doc, in: ctx)
                log("reconcileOnOpen: associations ready")

                if let pd = try self.fetchProjectDoc(id: doc.id, in: ctx) {
                    log("reconcileOnOpen: updating existing ProjectDoc id=\(pd.id)")
                    var changed = false

                    // Basic fields
                    if pd.title != doc.title { pd.title = doc.title; changed = true }
                    if pd.filePath != fileURL.path { pd.filePath = fileURL.path; changed = true }
                    if pd.isPublic != doc.isPublic { pd.isPublic = doc.isPublic; changed = true }

                    // Associations: singletons
                    if pd.domain?.id != assoc.domain?.id { pd.domain = assoc.domain; changed = true }
                    if pd.category?.id != assoc.category?.id { pd.category = assoc.category; changed = true }
                    if pd.status?.id != assoc.status?.id { pd.status = assoc.status; changed = true }
                    if pd.phase?.id != assoc.phase?.id { pd.phase = assoc.phase; changed = true }

                    // Associations: arrays (compare by id order-insensitively preserving canonical order from resolver)
                    let tagsChanged: Bool = {
                        if pd.tags.count != assoc.tags.count { return true }
                        let a = pd.tags.map { $0.id }
                        let b = assoc.tags.map { $0.id }
                        return a != b
                    }()
                    if tagsChanged { pd.tags = assoc.tags; changed = true }

                    let mediumsChanged: Bool = {
                        if pd.mediums.count != assoc.mediums.count { return true }
                        let a = pd.mediums.map { $0.id }
                        let b = assoc.mediums.map { $0.id }
                        return a != b
                    }()
                    if mediumsChanged { pd.mediums = assoc.mediums; changed = true }

                    let genresChanged: Bool = {
                        if pd.genres.count != assoc.genres.count { return true }
                        let a = pd.genres.map { $0.id }
                        let b = assoc.genres.map { $0.id }
                        return a != b
                    }()
                    if genresChanged { pd.genres = assoc.genres; changed = true }

                    let topicsChanged: Bool = {
                        if pd.topics.count != assoc.topics.count { return true }
                        let a = pd.topics.map { $0.id }
                        let b = assoc.topics.map { $0.id }
                        return a != b
                    }()
                    if topicsChanged { pd.topics = assoc.topics; changed = true }

                    let subjectsChanged: Bool = {
                        if pd.subjects.count != assoc.subjects.count { return true }
                        let a = pd.subjects.map { $0.id }
                        let b = assoc.subjects.map { $0.id }
                        return a != b
                    }()
                    if subjectsChanged { pd.subjects = assoc.subjects; changed = true }

                    if changed {
                        // Removed pd.updatedAt assignment here per instructions
                        log("reconcileOnOpen: changes detected. saving")
                        do { try ctx.save() } catch { throw SwiftDataError.unknown("Save failed: \(error)") }
                    }
                } else {
                    // Create new ProjectDoc with associations materialized
                    let pd = ProjectDoc(
                        id: doc.id,
                        title: doc.title,
                        filePath: fileURL.path,
                        updatedAt: Date(),
                        isPublic: doc.isPublic,
                        status: assoc.status,
                        phase: assoc.phase,
                        domain: assoc.domain,
                        category: assoc.category,
                        tags: assoc.tags,
                        mediums: assoc.mediums,
                        genres: assoc.genres,
                        topics: assoc.topics,
                        subjects: assoc.subjects
                    )
                    log("reconcileOnOpen: creating new ProjectDoc id=\(pd.id)")
                    ctx.insert(pd)
                    do { try ctx.save() } catch { throw SwiftDataError.unknown("Save failed: \(error)") }
                    log("reconcileOnOpen: created and saved id=\(pd.id)")
                }
            }
            log("reconcileOnOpen success id=\(doc.id)")
            return .success(())
        } catch let e as SwiftDataError {
            log("reconcileOnOpen failure \(e)")
            return .failure(e)
        } catch {
            log("reconcileOnOpen unexpected error \(error)")
            return .failure(.unknown("Unexpected error: \(error)"))
        }
    }

    func enqueueTitleChange(_ title: String, for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueTitleChange id=\(docID) title=\"\(title)\"")
        var c = pending[docID] ?? PendingChange()
        c.title = title
        pending[docID] = c
        scheduleDebounce(for: docID)
        return .success(())
    }

    func enqueueIsPublicChange(_ isPublic: Bool, for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueIsPublicChange id=\(docID) isPublic=\(isPublic)")
        var c = pending[docID] ?? PendingChange(); c.isPublic = isPublic; pending[docID] = c; scheduleDebounce(for: docID); return .success(())
    }

    func enqueueDomainChange(_ domain: String, for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueDomainChange id=\(docID) domain=\"\(domain)\"")
        var c = pending[docID] ?? PendingChange(); c.domain = domain; pending[docID] = c; scheduleDebounce(for: docID); return .success(())
    }

    func enqueueCategoryChange(_ category: String, for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueCategoryChange id=\(docID) category=\"\(category)\"")
        var c = pending[docID] ?? PendingChange(); c.category = category; pending[docID] = c; scheduleDebounce(for: docID); return .success(())
    }

    func enqueueStatusChange(_ status: String, for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueStatusChange id=\(docID) status=\"\(status)\"")
        var c = pending[docID] ?? PendingChange(); c.status = status; pending[docID] = c; scheduleDebounce(for: docID); return .success(())
    }

    func enqueueStatusPhaseChange(_ statusPhase: String, for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueStatusPhaseChange id=\(docID) phase=\"\(statusPhase)\"")
        var c = pending[docID] ?? PendingChange(); c.phase = statusPhase; pending[docID] = c; scheduleDebounce(for: docID); return .success(())
    }

    func enqueueTagChange(added: [String], removed: [String], for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueTagChange id=\(docID) +\(added.count) -\(removed.count)")
        var c = pending[docID] ?? PendingChange()
        c.tagsAdded += added
        c.tagsRemoved += removed
        pending[docID] = c
        if !removed.isEmpty { detachIfPresent(.tag, names: removed, for: docID) }
        scheduleDebounce(for: docID)
        return .success(())
    }

    func enqueueMediumsChange(added: [String], removed: [String], for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueMediumsChange id=\(docID) +\(added.count) -\(removed.count)")
        var c = pending[docID] ?? PendingChange()
        c.mediumsAdded += added
        c.mediumsRemoved += removed
        pending[docID] = c
        if !removed.isEmpty { detachIfPresent(.medium, names: removed, for: docID) }
        scheduleDebounce(for: docID)
        return .success(())
    }

    func enqueueGenresChange(added: [String], removed: [String], for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueGenresChange id=\(docID) +\(added.count) -\(removed.count)")
        var c = pending[docID] ?? PendingChange()
        c.genresAdded += added
        c.genresRemoved += removed
        pending[docID] = c
        if !removed.isEmpty { detachIfPresent(.genre, names: removed, for: docID) }
        scheduleDebounce(for: docID)
        return .success(())
    }

    func enqueueTopicsChange(added: [String], removed: [String], for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueTopicsChange id=\(docID) +\(added.count) -\(removed.count)")
        var c = pending[docID] ?? PendingChange()
        c.topicsAdded += added
        c.topicsRemoved += removed
        pending[docID] = c
        if !removed.isEmpty { detachIfPresent(.topic, names: removed, for: docID) }
        scheduleDebounce(for: docID)
        return .success(())
    }

    func enqueueSubjectsChange(added: [String], removed: [String], for docID: UUID) -> Result<Void, SwiftDataError> {
        log("enqueueSubjectsChange id=\(docID) +\(added.count) -\(removed.count)")
        var c = pending[docID] ?? PendingChange()
        c.subjectsAdded += added
        c.subjectsRemoved += removed
        pending[docID] = c
        if !removed.isEmpty { detachIfPresent(.subject, names: removed, for: docID) }
        scheduleDebounce(for: docID)
        return .success(())
    }

    func flushSwiftDataChange(for docID: UUID) async -> Result<Void, SwiftDataError> {
        log("flushSwiftDataChange begin id=\(docID)")
        guard let store else { return .failure(.unknown("Store not bound")) }

        if let t = changeTimers[docID] { t.cancel() }
        changeTimers.removeValue(forKey: docID)

        guard let change = pending.removeValue(forKey: docID), change.hasAnyChange else {
            log("flushSwiftDataChange nothing pending id=\(docID)")
            return .success(())
        }
        do {
            try await store.perform { ctx in
                try self.applyPendingChange(change, to: docID, in: ctx)
            }
            log("flushSwiftDataChange success id=\(docID)")
            return .success(())
        } catch let e as SwiftDataError {
            log("flushSwiftDataChange failure \(e)")
            return .failure(e)
        } catch {
            log("flushSwiftDataChange unexpected error \(error)")
            return .failure(.unknown("Unexpected error: \(error)"))
        }
    }
}


extension SwiftDataCoordinator {
    // MARK: Upsert functions

    private func upsertTag(name: String, in context: ModelContext) throws -> ProjectTag {
        log("upsertTag name=\"\(name)\"")
        if let existing = try fetchTag(slug: name.slugified(), in: context) {
            log("upsertTag -> \(String(describing: (try? fetchTag(slug: name.slugified(), in: context))?.id))")
            return existing
        }
        let created = try ProjectTag(name: name, in: context)
        context.insert(created)
        log("upsertTag -> \(String(describing: (try? fetchTag(slug: name.slugified(), in: context))?.id))")
        return created
    }

    private func upsertTopic(name: String, in context: ModelContext) throws -> ProjectTopic {
        log("upsertTopic name=\"\(name)\"")
        if let existing = try fetchTopic(slug: name.slugified(), in: context) {
            log("upsertTopic done")
            return existing
        }
        let created = try ProjectTopic(name: name, in: context)
        context.insert(created)
        log("upsertTopic done")
        return created
    }

    private func upsertSubject(name: String, in context: ModelContext) throws -> ProjectSubject {
        log("upsertSubject name=\"\(name)\"")
        if let existing = try fetchSubject(slug: name.slugified(), in: context) {
            log("upsertSubject done")
            return existing
        }
        let created = try ProjectSubject(name: name, in: context)
        context.insert(created)
        log("upsertSubject done")
        return created
    }

    private func upsertMedium(name: String, in context: ModelContext) throws -> ProjectMedium {
        log("upsertMedium name=\"\(name)\"")
        if let existing = try fetchMedium(slug: name.slugified(), in: context) {
            log("upsertMedium done")
            return existing
        }
        let created = try ProjectMedium(name: name, in: context)
        context.insert(created)
        log("upsertMedium done")
        return created
    }

    private func upsertGenre(name: String, in context: ModelContext) throws -> ProjectGenre {
        log("upsertGenre name=\"\(name)\"")
        if let existing = try fetchGenre(slug: name.slugified(), in: context) {
            log("upsertGenre done")
            return existing
        }
        let created = try ProjectGenre(name: name, in: context)
        context.insert(created)
        log("upsertGenre done")
        return created
    }

    private func upsertDomain(name: String?, in context: ModelContext) throws -> ProjectDomain? {
        log("upsertDomain name=\(String(describing: name))")
        guard let name, !name.isEmpty else { log("upsertDomain -> \(String(describing: name))"); return nil }
        if let existing = try fetchDomain(slug: name.slugified(), in: context) { log("upsertDomain -> \(String(describing: name))"); return existing }
        let created = try ProjectDomain(name: name, in: context)
        context.insert(created)
        log("upsertDomain -> \(String(describing: name))")
        return created
    }

    private func upsertCategory(name: String?, domain: ProjectDomain?, in context: ModelContext) throws -> ProjectCategory? {
        log("upsertCategory name=\(String(describing: name)) domain=\(String(describing: domain?.name))")
        guard let name, !name.isEmpty else { log("upsertCategory -> \(String(describing: name))"); return nil }
        if let existing = try fetchCategory(slug: name.slugified(), in: context) { log("upsertCategory -> \(String(describing: name))"); return existing }
        // If a category is provided without a domain, create it unattached
        let created = try ProjectCategory(name: name, domain: domain ?? (try ProjectDomain(name: "uncategorized", in: context)), in: context)
        context.insert(created)
        log("upsertCategory -> \(String(describing: name))")
        return created
    }
    
    
    // MARK: Upserts: Resource

    private func upsertResourceCategory(name: String, in context: ModelContext, addedVia: AddedViaOption) throws -> ResourceItemCategory {
        log("upsertResourceCategory name=\"\(name)\"")
        let slug = name.slugified()
        if let existing = try fetchResourceCategory(slug: slug, in: context) { log("upsertResourceCategory -> \(name)"); return existing }
        let created = try ResourceItemCategory(name: name, in: context, addedVia: addedVia)
        context.insert(created)
        log("upsertResourceCategory -> \(name)")
        return created
    }

    private func upsertResourceType(name: String, category: ResourceItemCategory, in context: ModelContext, addedVia: AddedViaOption) throws -> ResourceItemType {
        log("upsertResourceType name=\"\(name)\" category=\"\(category.name)\"")
        let slug = name.slugified()
        if let existing = try fetchResourceType(slug: slug, in: context) {
            // Ensure association is correct
            if existing.category.id != category.id { existing.category = category }
            log("upsertResourceType -> \(name)")
            return existing
        }
        let created = try ResourceItemType(name: name, category: category, in: context, addedVia: addedVia)
        context.insert(created)
        log("upsertResourceType -> \(name)")
        return created
    }

    // MARK: Upserts: Status

    private func upsertProjectStatus(name: String?, in context: ModelContext, addedVia: AddedViaOption) throws -> ProjectStatus? {
        log("upsertProjectStatus name=\(String(describing: name))")
        guard let name, !name.isEmpty else { log("upsertProjectStatus -> \(String(describing: name))"); return nil }
        let slug = name.slugified()
        if let existing = try fetchProjectStatus(slug: slug, in: context) { log("upsertProjectStatus -> \(String(describing: name))"); return existing }
        let created = try ProjectStatus(name: name, in: context, addedVia: addedVia)
        context.insert(created)
        log("upsertProjectStatus -> \(String(describing: name))")
        return created
    }

    private func upsertProjectStatusPhase(name: String?, status: ProjectStatus?, in context: ModelContext, addedVia: AddedViaOption) throws -> ProjectStatusPhase? {
        log("upsertProjectStatusPhase name=\(String(describing: name)) status=\(String(describing: status?.name))")
        guard let name, !name.isEmpty else { log("upsertProjectStatusPhase -> \(String(describing: name))"); return nil }
        let slug = name.slugified()
        
        if let existing = try fetchProjectStatusPhase(slug: slug, in: context) {
            log("upsertProjectStatusPhase -> \(String(describing: name))")
            return existing
        }
        let created = try ProjectStatusPhase(name: name, status: status ?? (try ProjectStatus(name: "uncategorized", in: context)), in: context)
        context.insert(created)
        log("upsertProjectStatusPhase -> \(String(describing: name))")
        return created
    }

    // MARK: Fetch-by-slug helpers

    private func fetchTag(slug: String, in context: ModelContext) throws -> ProjectTag? {
        log("fetchTag slug=\(slug)")
        let fd = FetchDescriptor<ProjectTag>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchTag -> \(r != nil ? "found" : "nil")")
        return r
    }

    private func fetchTopic(slug: String, in context: ModelContext) throws -> ProjectTopic? {
        log("fetchTopic slug=\(slug)")
        let fd = FetchDescriptor<ProjectTopic>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchTopic -> \(r != nil ? "found" : "nil")")
        return r
    }

    private func fetchSubject(slug: String, in context: ModelContext) throws -> ProjectSubject? {
        log("fetchSubject slug=\(slug)")
        let fd = FetchDescriptor<ProjectSubject>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchSubject -> \(r != nil ? "found" : "nil")")
        return r
    }

    private func fetchMedium(slug: String, in context: ModelContext) throws -> ProjectMedium? {
        log("fetchMedium slug=\(slug)")
        let fd = FetchDescriptor<ProjectMedium>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchMedium -> \(r != nil ? "found" : "nil")")
        return r
    }

    private func fetchGenre(slug: String, in context: ModelContext) throws -> ProjectGenre? {
        log("fetchGenre slug=\(slug)")
        let fd = FetchDescriptor<ProjectGenre>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchGenre -> \(r != nil ? "found" : "nil")")
        return r
    }

    private func fetchDomain(slug: String, in context: ModelContext) throws -> ProjectDomain? {
        log("fetchDomain slug=\(slug)")
        let fd = FetchDescriptor<ProjectDomain>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchDomain -> \(r != nil ? "found" : "nil")")
        return r
    }

    private func fetchCategory(slug: String, in context: ModelContext) throws -> ProjectCategory? {
        log("fetchCategory slug=\(slug)")
        let fd = FetchDescriptor<ProjectCategory>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchCategory -> \(r != nil ? "found" : "nil")")
        return r
    }

    private func fetchResourceCategory(slug: String, in context: ModelContext) throws -> ResourceItemCategory? {
        log("fetchResourceCategory slug=\(slug)")
        let fd = FetchDescriptor<ResourceItemCategory>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchResourceCategory -> \(r != nil ? "found" : "nil")")
        return r
    }

    private func fetchResourceType(slug: String, in context: ModelContext) throws -> ResourceItemType? {
        log("fetchResourceType slug=\(slug)")
        let fd = FetchDescriptor<ResourceItemType>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchResourceType -> \(r != nil ? "found" : "nil")")
        return r
    }

    private func fetchProjectStatus(slug: String, in context: ModelContext) throws -> ProjectStatus? {
        log("fetchProjectStatus slug=\(slug)")
        let fd = FetchDescriptor<ProjectStatus>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchProjectStatus -> \(r != nil ? "found" : "nil")")
        return r
    }

    private func fetchProjectStatusPhase(slug: String, in context: ModelContext) throws -> ProjectStatusPhase? {
        log("fetchProjectStatusPhase slug=\(slug)")
        let fd = FetchDescriptor<ProjectStatusPhase>(predicate: #Predicate { $0.slug == slug })
        let r = try context.fetch(fd).first
        log("fetchProjectStatusPhase -> \(r != nil ? "found" : "nil")")
        return r
    }
    
    
    
}




//
//
///// Resolve string `doc.tags` to `ProjectTag` models using slug lookup. Create missing tags. Apply to `ProjectDoc.tags` and mirror to `doc.sdTags`.
//func syncTagsOnOpen(from doc: FolioDocument) async -> Result<Void, SwiftDataError> {
//    log("syncTagsOnOpen begin id=\(doc.id) tagsIn=\(doc.tags.count)")
//    guard let store else { return .failure(.unknown("Store not bound")) }
//    do {
//        var resolved: [ProjectTag] = []
//        try await store.perform { ctx in
//            guard let pd = try self.fetchProjectDoc(id: doc.id, in: ctx) else {
//                throw SwiftDataError.unknown("ProjectDoc not found")
//            }
//            log("syncTagsOnOpen: ProjectDoc found id=\(pd.id)")
//
//            // De-duplicate by slug preserving order
//            var seen: Set<String> = []
//            var unique: [String] = []
//            for raw in doc.tags {
//                let slug = raw.slugified()
//                if seen.insert(slug).inserted { unique.append(raw) }
//            }
//            log("syncTagsOnOpen: unique tag strings=\(unique.count)")
//
//            resolved.removeAll(keepingCapacity: true)
//            for raw in unique {
//                let slug = raw.slugified()
//                if let existing = try self.fetchTag(slug: slug, in: ctx) {
//                    resolved.append(existing)
//                } else {
//                    let created = try ProjectTag(name: raw, in: ctx)
//                    ctx.insert(created)
//                    resolved.append(created)
//                }
//            }
//            log("syncTagsOnOpen: resolved tags=\(resolved.count)")
//
//            // Apply to ProjectDoc if changed
//            var changed = false
//            if pd.tags.count != resolved.count {
//                changed = true
//            } else {
//                let a = pd.tags.map { $0.id }
//                let b = resolved.map { $0.id }
//                changed = a != b
//            }
//            if changed {
//                log("syncTagsOnOpen: tags changed. saving")
//                pd.tags = resolved
//                pd.updatedAt = Date()
//                do { try ctx.save() } catch { throw SwiftDataError.unknown("Save failed: \(error)") }
//            }
//        }
//        log("syncTagsOnOpen success id=\(doc.id)")
//        return .success(())
//    } catch let e as SwiftDataError {
//        log("syncTagsOnOpen failure \(e)")
//        return .failure(e)
//    } catch {
//        log("syncTagsOnOpen unexpected error \(error)")
//        return .failure(.unknown("Unexpected error: \(error)"))
//    }
//}
//

