//
//  DataPersistenceIntegrationTests.swift
//  UnitTests
//
//  Created by GitHub Copilot on 12/2/25.
//

import Testing
import Foundation
import SwiftData
@testable import Folio

// MARK: - Full Document Persistence Tests

@Suite("Full Document Persistence with Recent Changes")
struct FullDocumentPersistenceTests {
    
    @Test("Document with multiple collection item resources persists")
    func testDocumentWithCollectionItemResources() throws {
        var doc = FolioDocument()
        doc.title = "Full Test Document"
        doc.subtitle = "Testing all recent changes"
        
        // Add collection with items that have multiple resources
        doc.collection = [
            "Test Collection": CollectionSection(
           
                items: [
                    JSONCollectionItem(
                        type: .file,
                        label: "Multi-Resource Item",
                        summary: "Has multiple resources",
                        thumbnail: AssetPath(id: UUID(), path: "thumbnails/item.png"),
                        resources: [
                            JSONResource(label: "Docs", category: "documentation", type: "web", url: "https://docs.example.com"),
                            JSONResource(label: "API", category: "api", type: "rest", url: "https://api.example.com"),
                            JSONResource(label: "Code", category: "code", type: "github", url: "https://github.com/example")
                        ]
                    ),
                    JSONCollectionItem(
                        type: .folio,
                        label: "Folio Reference",
                        url: "folio://some-project-id",
                        resources: [],
                        useFolioTitle: true,
                        useFolioSummary: true,
                        useFolioThumbnail: false
                    )
                ]
            )
        ]
        
        // Add document-level resources
        doc.resources = [
            JSONResource(label: "Main Site", category: "website", type: "landing", url: "https://example.com"),
            JSONResource(label: "Blog", category: "blog", type: "article", url: "https://example.com/blog")
        ]
        
        // Add images with new thumbnail aspect
        doc.images[.thumbnail] = AssetPath(id: UUID(), path: "images/thumb.png")
        doc.images[.banner] = AssetPath(id: UUID(), path: "images/banner.png")
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        // Verify everything persisted correctly
        #expect(decoded.title == "Full Test Document")
        #expect(decoded.collection.count == 1)
        let testSection = decoded.collection["Test Collection"]
        #expect(testSection?.items.count == 2)
        
        // Verify first item's resources
        let firstItem = try #require(testSection?.items.first)
        #expect(firstItem.resources.count == 3)
        #expect(firstItem.resources[0].label == "Docs")
        #expect(firstItem.resources[1].label == "API")
        #expect(firstItem.resources[2].label == "Code")
        
        // Verify folio item toggles
        let folioItem = try #require(testSection?.items.dropFirst().first)
        #expect(folioItem.type == .folio)
        #expect(folioItem.useFolioTitle == true)
        #expect(folioItem.useFolioSummary == true)
        #expect(folioItem.useFolioThumbnail == false)
        
        // Verify document resources
        #expect(decoded.resources.count == 2)
        #expect(decoded.resources[0].label == "Main Site")
        
        // Verify images
        #expect(decoded.images[.thumbnail]?.path == "images/thumb.png")
        #expect(decoded.images[.banner]?.path == "images/banner.png")
    }
    
    @Test("Document with status and phase persists with display names")
    func testDocumentStatusPhasePersistence() async throws {
        let schema = Schema([ProjectDoc.self, ProjectStatus.self, ProjectStatusPhase.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // Create status and phase
        let status = try ProjectStatus(name: "inProgress", in: context, addedVia: .system)
        let phase = try ProjectStatusPhase(name: "needsRefactor", status: status, in: context, addedVia: .system)
        
        context.insert(status)
        context.insert(phase)
        try context.save()
        
        // Create document with status/phase
        var doc = FolioDocument()
        doc.title = "Status Test"
        doc.status = status.name
        doc.phase = phase.name
        
        // Encode and decode
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.status == "inProgress")
        #expect(decoded.phase == "needsRefactor")
        
        // Verify display names work
        #expect(status.displayName == "In Progress")
        #expect(phase.displayName == "Needs Refactor")
    }
    
    @Test("Assets folder location persists without bookmark data")
    func testAssetsFolderPersistence() throws {
        var doc = FolioDocument()
        doc.assetsFolder = AssetsFolderLocation(path: "/Users/test/ProjectAssets")
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.assetsFolder?.path == "/Users/test/ProjectAssets")
        
        // Bookmark data should always be nil (managed separately)
        #expect(decoded.assetsFolder?.bookmarkData == nil)
    }
}

// MARK: - Migration Path Tests

@Suite("Migration Path Tests")
struct MigrationPathTests {
    
    @Test("Old document with single resource migrates to array")
    func testOldDocumentMigration() throws {
        // Simulate old JSON format
        let oldJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "title": "Legacy Document",
            "subtitle": "",
            "isPublic": true,
            "featured": false,
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:00:00Z",
            "tags": [],
            "topics": [],
            "subjects": [],
            "genres": [],
            "media": [],
            "languages": [],
            "resources": [],
            "images": {},
            "details": [],
            "collection": [
                {
                    "name": "Old Collection",
                    "items": [
                        {
                            "id": "87654321-4321-4321-4321-210987654321",
                            "type": "File",
                            "label": "Old Item",
                            "thumbnail": {"id": "11111111-1111-1111-1111-111111111111", "path": ""},
                            "resource": {
                                "label": "Single Resource",
                                "category": "legacy",
                                "type": "old",
                                "url": "https://old.com"
                            },
                            "order": 0,
                            "useFolioTitle": false,
                            "useFolioSummary": false,
                            "useFolioThumbnail": false
                        }
                    ]
                }
            ]
        }
        """
        
        let data = oldJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.collection.count == 1)
        let oldSection = decoded.collection["Old Collection"]
        #expect(oldSection?.items.count == 1)
        
        let item = try #require(oldSection?.items.first)
        #expect(item.resources.count == 1)
        #expect(item.resources[0].label == "Single Resource")
        #expect(item.resources[0].url == "https://old.com")
    }
    
    @Test("New document encodes without legacy fields")
    func testNewDocumentNoLegacyFields() throws {
        var doc = FolioDocument()
        doc.collection = [
            "New Collection": CollectionSection(
               
                items: [
                    JSONCollectionItem(
                        label: "New Item",
                        resources: [
                            JSONResource(label: "New Resource", category: "new", type: "modern", url: "https://new.com")
                        ]
                    )
                ]
            )
        ]
        
        let data = try JSONEncoder().encode(doc)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Should have "resources" array
        #expect(jsonString.contains("\"resources\":["))
        
        // Should NOT have old single "resource" field
        #expect(!jsonString.contains("\"resource\":{"))
    }
}

// MARK: - Round-Trip Integration Tests

@Suite("Round-Trip Integration Tests")
struct RoundTripIntegrationTests {
    
    @Test("Complete document round-trip preserves all data")
    func testCompleteRoundTrip() throws {
        var doc = FolioDocument()
        doc.title = "Complete Integration Test"
        doc.subtitle = "Testing all features"
        doc.isPublic = true
        doc.featured = true
        doc.status = "inProgress"
        doc.phase = "needsRefactor"
        
        doc.tags = ["swift", "testing", "integration"]
        doc.topics = ["Software Development"]
        
        doc.assetsFolder = AssetsFolderLocation(path: "/Users/test/Assets")
        
        doc.images[.thumbnail] = AssetPath(id: UUID(), path: "thumb.png")
        doc.images[.banner] = AssetPath(id: UUID(), path: "banner.png")
        doc.images[.icon] = AssetPath(id: UUID(), path: "icon.png")
        
        doc.resources = [
            JSONResource(label: "Res1", category: "cat1", type: "type1", url: "url1"),
            JSONResource(label: "Res2", category: "cat2", type: "type2", url: "url2")
        ]
        
        doc.collection = [
            "Section 1": CollectionSection(
            
                items: [
                    JSONCollectionItem(
                        type: .file,
                        label: "File Item",
                        filePath: AssetPath(id: UUID(), path: "files/doc.pdf"),
                        thumbnail: AssetPath(id: UUID(), path: "thumbs/doc.png"),
                        resources: [
                            JSONResource(label: "R1", category: "c1", type: "t1", url: "u1"),
                            JSONResource(label: "R2", category: "c2", type: "t2", url: "u2")
                        ]
                    ),
                    JSONCollectionItem(
                        type: .urlLink,
                        label: "URL Item",
                        url: "https://example.com",
                        thumbnail: AssetPath(id: UUID(), path: "thumbs/url.png"),
                        resources: []
                    ),
                    JSONCollectionItem(
                        type: .folio,
                        label: "Folio Item",
                        url: "folio://project-id",
                        thumbnail: AssetPath(id: UUID(), path: "thumbs/folio.png"),
                        resources: [
                            JSONResource(label: "FR", category: "fc", type: "ft", url: "fu")
                        ],
                        useFolioTitle: true,
                        useFolioSummary: false,
                        useFolioThumbnail: true
                    )
                ]
            )
        ]
        
        // First round-trip
        let data1 = try JSONEncoder().encode(doc)
        let decoded1 = try JSONDecoder().decode(FolioDocument.self, from: data1)
        
        // Second round-trip
        let data2 = try JSONEncoder().encode(decoded1)
        let decoded2 = try JSONDecoder().decode(FolioDocument.self, from: data2)
        
        // Verify all data preserved through two round-trips
        #expect(decoded2.title == doc.title)
        #expect(decoded2.subtitle == doc.subtitle)
        #expect(decoded2.isPublic == doc.isPublic)
        #expect(decoded2.featured == doc.featured)
        #expect(decoded2.status == doc.status)
        #expect(decoded2.phase == doc.phase)
        #expect(decoded2.tags == doc.tags)
        #expect(decoded2.topics == doc.topics)
        #expect(decoded2.assetsFolder?.path == doc.assetsFolder?.path)
        #expect(decoded2.resources.count == doc.resources.count)
        #expect(decoded2.collection.count == doc.collection.count)
        let section1_v2 = try #require(decoded2.collection["Section 1"])
        #expect(section1_v2.items.count == 3)
        #expect(section1_v2.items[0].resources.count == 2)
        #expect(section1_v2.items[1].resources.count == 0)
        #expect(section1_v2.items[2].resources.count == 1)
        #expect(section1_v2.items[2].useFolioTitle == true)
        #expect(section1_v2.items[2].useFolioThumbnail == true)
    }
}

// MARK: - Edge Case Integration Tests

@Suite("Edge Case Integration Tests")
struct EdgeCaseIntegrationTests {
    
    @Test("Document with empty resources arrays everywhere")
    func testEmptyResourcesEverywhere() throws {
        var doc = FolioDocument()
        doc.resources = []
        doc.collection = [
            "Empty Resources": CollectionSection(
               
                items: [
                    JSONCollectionItem(label: "Item 1", resources: []),
                    JSONCollectionItem(label: "Item 2", resources: []),
                    JSONCollectionItem(label: "Item 3", resources: [])
                ]
            )
        ]
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.resources.isEmpty)
        let emptySection = decoded.collection["Empty Resources"]
        #expect(emptySection?.items.count == 3)
        for item in emptySection?.items ?? [] {
            #expect(item.resources.isEmpty)
        }
    }
    
    @Test("Document with maximum resources")
    func testMaximumResources() throws {
        var doc = FolioDocument()
        
        // Add 50 document-level resources
        doc.resources = (0..<50).map { i in
            JSONResource(label: "Doc Res \(i)", category: "cat\(i)", type: "type\(i)", url: "url\(i)")
        }
        
        // Add collection with items having many resources
        doc.collection = [
            "Many Resources": CollectionSection(
                items: [
                    JSONCollectionItem(
                        label: "Item 1",
                        resources: (0..<20).map { i in
                            JSONResource(label: "Item1 Res \(i)", category: "c\(i)", type: "t\(i)", url: "u\(i)")
                        }
                    )
                ]
            )
        ]
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.resources.count == 50)
        let manySection = try #require(decoded.collection["Many Resources"])
        #expect(manySection.items.first?.resources.count == 20)
    }
    
    @Test("Folio item with all toggles and multiple resources")
    func testFolioItemFullyLoaded() throws {
        let item = JSONCollectionItem(
            type: .folio,
            label: "Complete Folio Item",
            summary: "Summary text",
            url: "folio://complete-id",
            thumbnail: AssetPath(id: UUID(), path: "thumb.png"),
            resources: [
                JSONResource(label: "R1", category: "c1", type: "t1", url: "u1"),
                JSONResource(label: "R2", category: "c2", type: "t2", url: "u2"),
                JSONResource(label: "R3", category: "c3", type: "t3", url: "u3")
            ],
            useFolioTitle: true,
            useFolioSummary: true,
            useFolioThumbnail: true
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.type == .folio)
        #expect(decoded.resources.count == 3)
        #expect(decoded.useFolioTitle == true)
        #expect(decoded.useFolioSummary == true)
        #expect(decoded.useFolioThumbnail == true)
    }
}

