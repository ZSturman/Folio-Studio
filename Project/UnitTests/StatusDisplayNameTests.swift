//
//  StatusDisplayNameTests.swift
//  UnitTests
//
//  Created by GitHub Copilot on 12/2/25.
//

import Testing
import Foundation
import SwiftData
@testable import Folio

// MARK: - CamelCase to Title Case Conversion Tests

@Suite("CamelCase to Title Case Tests")
struct CamelCaseToTitleCaseTests {
    
    @Test("Simple camelCase conversion")
    func testSimpleCamelCase() {
        #expect("inProgress".camelCaseToTitleCase() == "In Progress")
        #expect("onHold".camelCaseToTitleCase() == "On Hold")
        #expect("notStarted".camelCaseToTitleCase() == "Not Started")
    }
    
    @Test("Single word conversion")
    func testSingleWord() {
        #expect("idea".camelCaseToTitleCase() == "Idea")
        #expect("done".camelCaseToTitleCase() == "Done")
        #expect("archived".camelCaseToTitleCase() == "Archived")
    }
    
    @Test("PascalCase conversion")
    func testPascalCase() {
        #expect("InProgress".camelCaseToTitleCase() == "In Progress")
        #expect("OnHold".camelCaseToTitleCase() == "On Hold")
    }
    
    @Test("Multiple words conversion")
    func testMultipleWords() {
        #expect("needsRefactor".camelCaseToTitleCase() == "Needs Refactor")
        #expect("scrapForParts".camelCaseToTitleCase() == "Scrap For Parts")
        #expect("onHoldIndefinitely".camelCaseToTitleCase() == "On Hold Indefinitely")
    }
    
    @Test("Acronyms and abbreviations")
    func testAcronyms() {
        #expect("URLPath".camelCaseToTitleCase() == "URL Path")
        #expect("APIKey".camelCaseToTitleCase() == "API Key")
        #expect("HTTPSConnection".camelCaseToTitleCase() == "HTTPS Connection")
    }
    
    @Test("Empty string")
    func testEmptyString() {
        #expect("".camelCaseToTitleCase() == "")
    }
    
    @Test("Already has spaces")
    func testAlreadyHasSpaces() {
        // Should capitalize first letter but not add extra spaces
        #expect("in progress".camelCaseToTitleCase() == "In progress")
    }
    
    @Test("All lowercase")
    func testAllLowercase() {
        #expect("hello".camelCaseToTitleCase() == "Hello")
    }
    
    @Test("All uppercase")
    func testAllUppercase() {
        #expect("HELLO".camelCaseToTitleCase() == "HELLO")
    }
    
    @Test("Numbers in camelCase")
    func testNumbersInCamelCase() {
        #expect("version2Update".camelCaseToTitleCase() == "Version2 Update")
        #expect("phase1Complete".camelCaseToTitleCase() == "Phase1 Complete")
    }
    
    @Test("Special characters")
    func testSpecialCharacters() {
        #expect("test-case".camelCaseToTitleCase() == "Test-case")
        #expect("test_case".camelCaseToTitleCase() == "Test_case")
    }
}

// MARK: - Status DisplayName Tests

@Suite("Status DisplayName Tests")
struct StatusDisplayNameTests {
    
    @Test("Status displayName returns formatted name")
    func testStatusDisplayName() async throws {
        let schema = Schema([ProjectStatus.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let status = try ProjectStatus(name: "inProgress", in: context, addedVia: .system)
        
        #expect(status.name == "inProgress")
        #expect(status.displayName == "In Progress")
    }
    
    @Test("Multiple status displayNames")
    func testMultipleStatusDisplayNames() async throws {
        let schema = Schema([ProjectStatus.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let status1 = try ProjectStatus(name: "idea", in: context, addedVia: .system)
        let status2 = try ProjectStatus(name: "onHold", in: context, addedVia: .system)
        let status3 = try ProjectStatus(name: "done", in: context, addedVia: .system)
        
        #expect(status1.displayName == "Idea")
        #expect(status2.displayName == "On Hold")
        #expect(status3.displayName == "Done")
    }
    
    @Test("Status with custom name")
    func testStatusCustomName() async throws {
        let schema = Schema([ProjectStatus.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let status = try ProjectStatus(name: "customWorkflowState", in: context, addedVia: .manual)
        
        #expect(status.displayName == "Custom Workflow State")
    }
    
    @Test("Status displayName updates when renamed")
    func testStatusRenameUpdatesDisplayName() async throws {
        let schema = Schema([ProjectStatus.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let status = try ProjectStatus(name: "draft", in: context, addedVia: .manual)
        #expect(status.displayName == "Draft")
        
        try status.rename(to: "inReview", in: context)
        #expect(status.name == "inReview")
        #expect(status.displayName == "In Review")
    }
}

// MARK: - Phase DisplayName Tests

@Suite("Phase DisplayName Tests")
struct PhaseDisplayNameTests {
    
    @Test("Phase displayName returns formatted name")
    func testPhaseDisplayName() async throws {
        let schema = Schema([ProjectStatus.self, ProjectStatusPhase.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let status = try ProjectStatus(name: "inProgress", in: context, addedVia: .system)
        let phase = try ProjectStatusPhase(name: "needsRefactor", status: status, in: context, addedVia: .system)
        
        #expect(phase.name == "needsRefactor")
        #expect(phase.displayName == "Needs Refactor")
    }
    
    @Test("Multiple phase displayNames")
    func testMultiplePhaseDisplayNames() async throws {
        let schema = Schema([ProjectStatus.self, ProjectStatusPhase.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let status = try ProjectStatus(name: "idea", in: context, addedVia: .system)
        let phase1 = try ProjectStatusPhase(name: "roughSketch", status: status, in: context, addedVia: .system)
        let phase2 = try ProjectStatusPhase(name: "jumpingOffPoint", status: status, in: context, addedVia: .system)
        let phase3 = try ProjectStatusPhase(name: "whiteBoardNote", status: status, in: context, addedVia: .system)
        
        #expect(phase1.displayName == "Rough Sketch")
        #expect(phase2.displayName == "Jumping Off Point")
        #expect(phase3.displayName == "White Board Note")
    }
    
    @Test("Phase with single word name")
    func testPhaseSingleWord() async throws {
        let schema = Schema([ProjectStatus.self, ProjectStatusPhase.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let status = try ProjectStatus(name: "done", in: context, addedVia: .system)
        let phase = try ProjectStatusPhase(name: "published", status: status, in: context, addedVia: .system)
        
        #expect(phase.displayName == "Published")
    }
    
    @Test("Phase displayName updates when renamed")
    func testPhaseRenameUpdatesDisplayName() async throws {
        let schema = Schema([ProjectStatus.self, ProjectStatusPhase.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let status = try ProjectStatus(name: "archived", in: context, addedVia: .system)
        let phase = try ProjectStatusPhase(name: "abandoned", status: status, in: context, addedVia: .system)
        
        #expect(phase.displayName == "Abandoned")
        
        try phase.rename(to: "scrapForParts", in: context)
        #expect(phase.name == "scrapForParts")
        #expect(phase.displayName == "Scrap For Parts")
    }
    
    @Test("Seeded catalog phases have correct display names")
    func testSeededCatalogDisplayNames() async throws {
        let schema = Schema([ProjectStatus.self, ProjectStatusPhase.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // Seed the catalog
        try await seedProjectStatusCatalog(in: context, addedVia: .system)
        
        // Fetch a specific phase
        let fd = FetchDescriptor<ProjectStatusPhase>(
            predicate: #Predicate<ProjectStatusPhase> { $0.slug == "rough-sketch" }
        )
        let phases = try context.fetch(fd)
        
        #expect(!phases.isEmpty)
        let phase = phases[0]
        #expect(phase.name == "roughSketch")
        #expect(phase.displayName == "Rough Sketch")
    }
}

// MARK: - Slugify Consistency Tests

@Suite("Slugify Consistency with DisplayName Tests")
struct SlugifyConsistencyTests {
    
    @Test("Slug and displayName are consistent")
    func testSlugDisplayNameConsistency() async throws {
        let schema = Schema([ProjectStatus.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let status = try ProjectStatus(name: "inProgress", in: context, addedVia: .manual)
        
        // Slug should be kebab-case, displayName should be Title Case
        #expect(status.slug == "in-progress")
        #expect(status.displayName == "In Progress")
    }
    
    @Test("DisplayName does not affect slug")
    func testDisplayNameDoesNotAffectSlug() async throws {
        let schema = Schema([ProjectStatus.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // Create status with camelCase
        let status = try ProjectStatus(name: "myCustomStatus", in: context, addedVia: .manual)
        
        #expect(status.slug == "my-custom-status")
        #expect(status.displayName == "My Custom Status")
        
        // DisplayName is computed, shouldn't affect slug
        #expect(status.slug == "my-custom-status")
    }
}
