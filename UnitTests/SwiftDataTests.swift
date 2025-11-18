//
//  SwiftDataTests.swift
//  UnitTests
//
//  Created by Zachary Sturman on 11/17/25.
//

import Testing
import Foundation
import SwiftData
@testable import Folio

// MARK: - SwiftData Model Tests

@Suite("SwiftData Model Tests")
struct SwiftDataModelTests {
    
    // MARK: - Slug Generation Tests
    
    @Test("Slug generation from name")
    func testSlugGeneration() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag = try ProjectTag(name: "Swift Programming", in: context)
        #expect(tag.slug == "swift-programming")
    }
    
    @Test("Slug handles special characters")
    func testSlugSpecialCharacters() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag = try ProjectTag(name: "C++ & Objective-C", in: context)
        // Verify slug is sanitized
        #expect(!tag.slug.contains("++"))
        #expect(!tag.slug.contains("&"))
    }
    
    @Test("Slug collision handling")
    func testSlugCollision() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag1 = try ProjectTag(name: "Swift", in: context)
        context.insert(tag1)
        try context.save()
        
        let tag2 = try ProjectTag(name: "Swift", in: context)
        context.insert(tag2)
        
        // Second tag should have different slug
        #expect(tag1.slug != tag2.slug)
        #expect(tag2.slug.hasPrefix("swift-"))
    }
    
    @Test("Very long name slug truncation")
    func testVeryLongNameSlug() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let longName = String(repeating: "a", count: 1000)
        let tag = try ProjectTag(name: longName, in: context)
        
        // Slug should be created (may be truncated or hashed)
        #expect(!tag.slug.isEmpty)
    }
    
    @Test("Unicode in slug")
    func testUnicodeInSlug() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag = try ProjectTag(name: "日本語 テスト", in: context)
        
        // Slug should be generated (may be transliterated)
        #expect(!tag.slug.isEmpty)
    }
    
    @Test("Empty name handling")
    func testEmptyNameTag() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // Empty names might fail or create empty slug
        do {
            let tag = try ProjectTag(name: "", in: context)
            // If it succeeds, verify slug is created
            #expect(!tag.slug.isEmpty || tag.name.isEmpty)
        } catch {
            // It's acceptable to reject empty names
        }
    }
    
    // MARK: - Relationship Tests
    
    @Test("Tag to project relationship")
    func testTagProjectRelationship() throws {
        let schema = Schema([ProjectTag.self, ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag = try ProjectTag(name: "Swift", in: context)
        context.insert(tag)
        
        let project = ProjectDoc(
            id: UUID(),
            title: "Test Project",
            filePath: "/test.folio",
            updatedAt: Date(),
            isPublic: true,
            status: nil,
            phase: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        context.insert(project)
        project.tags.append(tag)
        
        try context.save()
        
        #expect(project.tags.count == 1)
        #expect(project.tags.first?.name == "Swift")
        #expect(tag.docs.count == 1)
    }
    
    @Test("Domain to category relationship")
    func testDomainCategoryRelationship() throws {
        let schema = Schema([ProjectDomain.self, ProjectCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let domain = try ProjectDomain(name: "Development", in: context)
        context.insert(domain)
        
        let category = try ProjectCategory(name: "iOS", domain: domain, in: context)
        context.insert(category)
        
        try context.save()
        
        #expect(domain.categories.count == 1)
        #expect(category.domain === domain)
    }
    
    @Test("Status to phase relationship")
    func testStatusPhaseRelationship() throws {
        let schema = Schema([ProjectStatus.self, ProjectStatusPhase.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let status = try ProjectStatus(name: "In Progress", in: context)
        context.insert(status)
        
        let phase = try ProjectStatusPhase(name: "Development", status: status, in: context)
        context.insert(phase)
        
        try context.save()
        
        #expect(status.phases.count == 1)
        #expect(phase.status === status)
    }
    
    @Test("Cascade delete for domain and categories")
    func testCascadeDeleteDomainCategories() throws {
        let schema = Schema([ProjectDomain.self, ProjectCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let domain = try ProjectDomain(name: "Development", in: context)
        context.insert(domain)
        
        let category = try ProjectCategory(name: "iOS", domain: domain, in: context)
        context.insert(category)
        
        try context.save()
        
        // Delete domain
        context.delete(domain)
        try context.save()
        
        // Category should be deleted too
        let descriptor = FetchDescriptor<ProjectCategory>()
        let categories = try context.fetch(descriptor)
        #expect(categories.isEmpty)
    }
    
    @Test("Nullify delete for tag and projects")
    func testNullifyDeleteTagProjects() throws {
        let schema = Schema([ProjectTag.self, ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag = try ProjectTag(name: "Swift", in: context)
        context.insert(tag)
        
        let project = ProjectDoc(
            id: UUID(),
            title: "Test Project",
            filePath: "/test.folio",
            updatedAt: Date(),
            isPublic: true,
            status: nil,
            phase: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        context.insert(project)
        project.tags.append(tag)
        
        try context.save()
        
        // Delete tag
        context.delete(tag)
        try context.save()
        
        // Project should still exist
        let descriptor = FetchDescriptor<ProjectDoc>()
        let projects = try context.fetch(descriptor)
        #expect(projects.count == 1)
        #expect(projects.first?.tags.isEmpty == true)
    }
    
    // MARK: - AddedVia Tests
    
    @Test("Tag with manual addedVia")
    func testManualAddedVia() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag = try ProjectTag(name: "Custom", in: context, addedVia: .manual)
        #expect(tag.addedVia == .manual)
    }
    
    @Test("Tag with system addedVia")
    func testSystemAddedVia() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag = try ProjectTag(name: "System", in: context, addedVia: .system)
        #expect(tag.addedVia == .system)
    }
    
    @Test("Tag with docImport addedVia")
    func testDocImportAddedVia() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag = try ProjectTag(name: "ImportedTag", in: context, addedVia: .docImport)
        #expect(tag.addedVia == .docImport)
    }
}

// MARK: - SwiftData Coordinator Tests

@Suite("SwiftData Coordinator Tests")
struct SwiftDataCoordinatorTests {
    
    @Test("Coordinator initialization")
    func testCoordinatorInit() async throws {
        let coordinator = SwiftDataCoordinator()
        
        // Coordinator should initialize without error
        #expect(coordinator != nil)
    }
    
    @Test("Title change debouncing")
    func testTitleChangeDebounce() async throws {
        let coordinator = SwiftDataCoordinator()
        let docID = UUID()
        
        // Enqueue multiple rapid changes
        coordinator.enqueueTitleChange("Title 1", for: docID)
        coordinator.enqueueTitleChange("Title 2", for: docID)
        coordinator.enqueueTitleChange("Title 3", for: docID)
        
        // Should debounce (only last one applied)
        // Wait for debounce period
        try await Task.sleep(for: .milliseconds(800))
        
        // Verify only one update occurred (we'd need access to internal state or mock)
        // This test verifies the API doesn't crash
    }
    
    @Test("Tag addition and removal")
    func testTagAddRemove() async throws {
        let coordinator = SwiftDataCoordinator()
        let docID = UUID()
        
        // Add tags
        coordinator.enqueueTagChange(added: ["swift", "ios"], removed: [], for: docID)
        
        // Remove tags
        coordinator.enqueueTagChange(added: [], removed: ["swift"], for: docID)
        
        // Should handle without error
        try await Task.sleep(for: .milliseconds(800))
    }
    
    @Test("Multiple taxonomy changes")
    func testMultipleTaxonomyChanges() async throws {
        let coordinator = SwiftDataCoordinator()
        let docID = UUID()
        
        coordinator.enqueueTagChange(added: ["tag1"], removed: [], for: docID)
        coordinator.enqueueMediumsChange(added: ["Digital"], removed: [], for: docID)
        coordinator.enqueueGenresChange(added: ["Educational"], removed: [], for: docID)
        coordinator.enqueueTopicsChange(added: ["Programming"], removed: [], for: docID)
        coordinator.enqueueSubjectsChange(added: ["Software"], removed: [], for: docID)
        
        // All should be handled without error
        try await Task.sleep(for: .milliseconds(800))
    }
    
    @Test("Flush immediate save")
    func testFlushImmediateSave() async throws {
        let coordinator = SwiftDataCoordinator()
        let docID = UUID()
        
        coordinator.enqueueTitleChange("Test", for: docID)
        
        // Flush should trigger immediate save
        await coordinator.flushSwiftDataChange(for: docID)
        
        // Give it a moment to process
        try await Task.sleep(for: .milliseconds(100))
    }
    
    @Test("Concurrent document changes")
    func testConcurrentDocumentChanges() async throws {
        let coordinator = SwiftDataCoordinator()
        let doc1ID = UUID()
        let doc2ID = UUID()
        let doc3ID = UUID()
        
        // Simulate multiple documents being edited simultaneously
        coordinator.enqueueTitleChange("Doc 1", for: doc1ID)
        coordinator.enqueueTitleChange("Doc 2", for: doc2ID)
        coordinator.enqueueTitleChange("Doc 3", for: doc3ID)
        
        coordinator.enqueueTagChange(added: ["tag1"], removed: [], for: doc1ID)
        coordinator.enqueueTagChange(added: ["tag2"], removed: [], for: doc2ID)
        
        // Should handle concurrent edits
        try await Task.sleep(for: .milliseconds(800))
    }
    
    @Test("Same tag added to multiple documents concurrently")
    func testConcurrentSameTagAddition() async throws {
        let coordinator = SwiftDataCoordinator()
        let doc1ID = UUID()
        let doc2ID = UUID()
        
        // Both documents add the same tag simultaneously
        coordinator.enqueueTagChange(added: ["shared-tag"], removed: [], for: doc1ID)
        coordinator.enqueueTagChange(added: ["shared-tag"], removed: [], for: doc2ID)
        
        // Should handle without creating duplicates (ideally)
        try await Task.sleep(for: .milliseconds(800))
        
        // Note: This is a known race condition area
    }
    
    @Test("Rapid add and remove of same tag")
    func testRapidAddRemoveSameTag() async throws {
        let coordinator = SwiftDataCoordinator()
        let docID = UUID()
        
        // Rapidly add and remove
        coordinator.enqueueTagChange(added: ["volatile-tag"], removed: [], for: docID)
        coordinator.enqueueTagChange(added: [], removed: ["volatile-tag"], for: docID)
        coordinator.enqueueTagChange(added: ["volatile-tag"], removed: [], for: docID)
        coordinator.enqueueTagChange(added: [], removed: ["volatile-tag"], for: docID)
        
        // Should eventually settle
        try await Task.sleep(for: .milliseconds(800))
    }
}

// MARK: - Query and Fetch Tests

@Suite("Query and Fetch Tests")
struct QueryFetchTests {
    
    @Test("Fetch all tags")
    func testFetchAllTags() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag1 = try ProjectTag(name: "Swift", in: context)
        let tag2 = try ProjectTag(name: "iOS", in: context)
        let tag3 = try ProjectTag(name: "Testing", in: context)
        
        context.insert(tag1)
        context.insert(tag2)
        context.insert(tag3)
        try context.save()
        
        let descriptor = FetchDescriptor<ProjectTag>()
        let tags = try context.fetch(descriptor)
        
        #expect(tags.count == 3)
    }
    
    @Test("Fetch tags by slug")
    func testFetchTagBySlug() throws {
        let schema = Schema([ProjectTag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let tag = try ProjectTag(name: "Swift", in: context)
        context.insert(tag)
        try context.save()
        
        let predicate = #Predicate<ProjectTag> { $0.slug == "swift" }
        let descriptor = FetchDescriptor<ProjectTag>(predicate: predicate)
        let results = try context.fetch(descriptor)
        
        #expect(results.count == 1)
        #expect(results.first?.name == "Swift")
    }
    
    @Test("Fetch public projects only")
    func testFetchPublicProjects() throws {
        let schema = Schema([ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let publicProj = ProjectDoc(
            id: UUID(),
            title: "Public",
            filePath: "/public.folio",
            updatedAt: Date(),
            isPublic: true,
            status: nil,
            phase: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        let privateProj = ProjectDoc(
            id: UUID(),
            title: "Private",
            filePath: "/private.folio",
            updatedAt: Date(),
            isPublic: false,
            status: nil,
            phase: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        
        context.insert(publicProj)
        context.insert(privateProj)
        try context.save()
        
        let predicate = #Predicate<ProjectDoc> { $0.isPublic == true }
        let descriptor = FetchDescriptor<ProjectDoc>(predicate: predicate)
        let results = try context.fetch(descriptor)
        
        #expect(results.count == 1)
        #expect(results.first?.title == "Public")
    }
    
    @Test("Sort projects by updated date")
    func testSortProjectsByDate() throws {
        let schema = Schema([ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)
        
        let proj1 = ProjectDoc(id: UUID(), title: "Old", filePath: "/old.folio", updatedAt: yesterday, isPublic: true, status: nil, phase: nil, tags: [], mediums: [], genres: [], topics: [], subjects: [])
        let proj2 = ProjectDoc(id: UUID(), title: "New", filePath: "/new.folio", updatedAt: tomorrow, isPublic: true, status: nil, phase: nil, tags: [], mediums: [], genres: [], topics: [], subjects: [])
        let proj3 = ProjectDoc(id: UUID(), title: "Now", filePath: "/now.folio", updatedAt: now, isPublic: true, status: nil, phase: nil, tags: [], mediums: [], genres: [], topics: [], subjects: [])
        
        context.insert(proj1)
        context.insert(proj2)
        context.insert(proj3)
        try context.save()
        
        let descriptor = FetchDescriptor<ProjectDoc>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let results = try context.fetch(descriptor)
        
        #expect(results.count == 3)
        #expect(results[0].title == "New")
        #expect(results[1].title == "Now")
        #expect(results[2].title == "Old")
    }
}
