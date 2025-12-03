//
//  CollectionItemResourceTests.swift
//  UnitTests
//
//  Created by GitHub Copilot on 12/2/25.
//

import Testing
import Foundation
@testable import Folio

// MARK: - Collection Item Resource Migration Tests

@Suite("Collection Item Resource Migration Tests")
struct CollectionItemResourceMigrationTests {
    
    @Test("Empty resources array encodes correctly")
    func testEmptyResourcesArray() throws {
        let item = JSONCollectionItem(
            label: "Test Item",
            resources: []
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.resources.isEmpty)
        #expect(decoded.label == "Test Item")
    }
    
    @Test("Multiple resources encode and decode correctly")
    func testMultipleResources() throws {
        let resources = [
            JSONResource(label: "Documentation", category: "reference", type: "external", url: "https://example.com/docs"),
            JSONResource(label: "API", category: "api", type: "rest", url: "https://api.example.com"),
            JSONResource(label: "Source Code", category: "code", type: "github", url: "https://github.com/example")
        ]
        
        let item = JSONCollectionItem(
            label: "Project Resources",
            resources: resources
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.resources.count == 3)
        #expect(decoded.resources[0].label == "Documentation")
        #expect(decoded.resources[1].category == "api")
        #expect(decoded.resources[2].url == "https://github.com/example")
    }
    
    @Test("Migration from old single resource format")
    func testMigrationFromSingleResource() throws {
        // Simulate old JSON with single 'resource' field
        let oldJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "type": "File",
            "label": "Old Item",
            "thumbnail": {"id": "87654321-4321-4321-4321-210987654321", "path": ""},
            "resource": {
                "label": "Old Resource",
                "category": "download",
                "type": "file",
                "url": "https://example.com/file.zip"
            },
            "order": 0,
            "useFolioTitle": false,
            "useFolioSummary": false,
            "useFolioThumbnail": false
        }
        """
        
        let data = oldJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        // Old single resource should be migrated to array
        #expect(decoded.resources.count == 1)
        #expect(decoded.resources[0].label == "Old Resource")
        #expect(decoded.resources[0].category == "download")
    }
    
    @Test("Migration handles empty old resource gracefully")
    func testMigrationEmptyOldResource() throws {
        let oldJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "type": "File",
            "label": "Item with Empty Resource",
            "thumbnail": {"id": "87654321-4321-4321-4321-210987654321", "path": ""},
            "resource": {
                "label": "",
                "category": "",
                "type": "",
                "url": ""
            },
            "order": 0,
            "useFolioTitle": false,
            "useFolioSummary": false,
            "useFolioThumbnail": false
        }
        """
        
        let data = oldJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        // Empty old resource should result in empty array
        #expect(decoded.resources.isEmpty)
    }
    
    @Test("New format with resources array takes precedence")
    func testNewFormatPrecedence() throws {
        // JSON with both old and new fields (new should win)
        let mixedJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "type": "File",
            "label": "Mixed Format",
            "thumbnail": {"id": "87654321-4321-4321-4321-210987654321", "path": ""},
            "resource": {
                "label": "Old Resource",
                "category": "old",
                "type": "old",
                "url": "old.com"
            },
            "resources": [
                {
                    "label": "New Resource 1",
                    "category": "new",
                    "type": "new",
                    "url": "new1.com"
                },
                {
                    "label": "New Resource 2",
                    "category": "new",
                    "type": "new",
                    "url": "new2.com"
                }
            ],
            "order": 0,
            "useFolioTitle": false,
            "useFolioSummary": false,
            "useFolioThumbnail": false
        }
        """
        
        let data = mixedJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        // New resources array should take precedence
        #expect(decoded.resources.count == 2)
        #expect(decoded.resources[0].label == "New Resource 1")
        #expect(decoded.resources[1].label == "New Resource 2")
    }
    
    @Test("Encoded output uses new resources key only")
    func testEncodingUsesNewKey() throws {
        let item = JSONCollectionItem(
            label: "Test",
            resources: [JSONResource(label: "Res", category: "cat", type: "type", url: "url")]
        )
        
        let data = try JSONEncoder().encode(item)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Should contain "resources" key
        #expect(jsonString.contains("\"resources\""))
        
        // Should NOT contain old "resource" key (without 's')
        // Note: This is tricky because "resources" contains "resource"
        // We check that it's not "resource":[{ but rather "resources":[{
        #expect(!jsonString.contains("\"resource\":{"))
    }
}

// MARK: - Folio Toggle Tests

@Suite("Folio Collection Item Toggle Tests")
struct FolioCollectionItemToggleTests {
    
    @Test("Default toggle values are false")
    func testDefaultToggleValues() throws {
        let item = JSONCollectionItem(label: "Test")
        
        #expect(item.useFolioTitle == false)
        #expect(item.useFolioSummary == false)
        #expect(item.useFolioThumbnail == false)
    }
    
    @Test("Toggles encode and decode correctly")
    func testTogglesEncodeDecode() throws {
        let item = JSONCollectionItem(
            label: "Folio Item",
            useFolioTitle: true,
            useFolioSummary: true,
            useFolioThumbnail: false
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.useFolioTitle == true)
        #expect(decoded.useFolioSummary == true)
        #expect(decoded.useFolioThumbnail == false)
    }
    
    @Test("Missing toggle fields default to false")
    func testMissingTogglesDefaultToFalse() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "type": "Folio",
            "label": "Legacy Item",
            "thumbnail": {"id": "87654321-4321-4321-4321-210987654321", "path": ""},
            "resources": [],
            "order": 0
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.useFolioTitle == false)
        #expect(decoded.useFolioSummary == false)
        #expect(decoded.useFolioThumbnail == false)
    }
    
    @Test("Folio type with all toggles enabled")
    func testFolioTypeWithAllToggles() throws {
        let item = JSONCollectionItem(
            type: .folio,
            label: "Referenced Project",
            url: "folio://some-id",
            useFolioTitle: true,
            useFolioSummary: true,
            useFolioThumbnail: true
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.type == .folio)
        #expect(decoded.useFolioTitle == true)
        #expect(decoded.useFolioSummary == true)
        #expect(decoded.useFolioThumbnail == true)
        #expect(decoded.url == "folio://some-id")
    }
    
    @Test("Non-folio types can have toggles (for flexibility)")
    func testNonFolioTypesWithToggles() throws {
        // Toggles should persist even on non-folio types (defensive)
        let item = JSONCollectionItem(
            type: .file,
            label: "File Item",
            useFolioTitle: true
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.type == .file)
        #expect(decoded.useFolioTitle == true)  // Should persist
    }
}

// MARK: - Resource Array Functionality Tests

@Suite("Resource Array Functionality Tests")
struct ResourceArrayFunctionalityTests {
    
    @Test("Can add resources dynamically")
    func testAddResources() throws {
        var item = JSONCollectionItem(label: "Dynamic")
        #expect(item.resources.isEmpty)
        
        item.resources.append(JSONResource(label: "First", category: "docs", type: "web", url: "url1"))
        #expect(item.resources.count == 1)
        
        item.resources.append(JSONResource(label: "Second", category: "api", type: "rest", url: "url2"))
        #expect(item.resources.count == 2)
        
        #expect(item.resources[0].label == "First")
        #expect(item.resources[1].label == "Second")
    }
    
    @Test("Can remove resources")
    func testRemoveResources() throws {
        var item = JSONCollectionItem(
            label: "Test",
            resources: [
                JSONResource(label: "Keep", category: "a", type: "b", url: "c"),
                JSONResource(label: "Delete", category: "d", type: "e", url: "f")
            ]
        )
        
        #expect(item.resources.count == 2)
        
        item.resources.remove(at: 1)
        #expect(item.resources.count == 1)
        #expect(item.resources[0].label == "Keep")
    }
    
    @Test("Resources maintain order")
    func testResourcesOrder() throws {
        let resources = [
            JSONResource(label: "First", category: "1", type: "1", url: "1"),
            JSONResource(label: "Second", category: "2", type: "2", url: "2"),
            JSONResource(label: "Third", category: "3", type: "3", url: "3")
        ]
        
        let item = JSONCollectionItem(label: "Ordered", resources: resources)
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.resources.count == 3)
        #expect(decoded.resources[0].label == "First")
        #expect(decoded.resources[1].label == "Second")
        #expect(decoded.resources[2].label == "Third")
    }
    
    @Test("Empty resource in array is valid")
    func testEmptyResourceInArray() throws {
        let item = JSONCollectionItem(
            label: "Test",
            resources: [JSONResource()]  // Empty resource
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.resources.count == 1)
        #expect(decoded.resources[0].label.isEmpty)
    }
    
    @Test("Large number of resources")
    func testManyResources() throws {
        var resources: [JSONResource] = []
        for i in 0..<100 {
            resources.append(JSONResource(
                label: "Resource \(i)",
                category: "cat\(i)",
                type: "type\(i)",
                url: "url\(i)"
            ))
        }
        
        let item = JSONCollectionItem(label: "Many Resources", resources: resources)
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.resources.count == 100)
        #expect(decoded.resources[0].label == "Resource 0")
        #expect(decoded.resources[99].label == "Resource 99")
    }
}

// MARK: - Document Resource Array Tests

@Suite("Document Resource Array Tests")
struct DocumentResourceArrayTests {
    
    @Test("Document with collection items and multiple resources")
    func testDocumentWithResourceArrays() throws {
        var doc = FolioDocument()
        doc.collection = [
            "Resources": CollectionSection(
         
                items: [
                    JSONCollectionItem(
                        label: "Item 1",
                        resources: [
                            JSONResource(label: "Res 1A", category: "a", type: "b", url: "c"),
                            JSONResource(label: "Res 1B", category: "d", type: "e", url: "f")
                        ]
                    ),
                    JSONCollectionItem(
                        label: "Item 2",
                        resources: [
                            JSONResource(label: "Res 2A", category: "g", type: "h", url: "i")
                        ]
                    )
                ]
            )
        ]
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.collection.count == 1)
        let section = try #require(decoded.collection["Resources"])
        #expect(section.items.count == 2)
        #expect(section.items[0].resources.count == 2)
        #expect(section.items[1].resources.count == 1)
    }
}

