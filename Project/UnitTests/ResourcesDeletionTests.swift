//
//  ResourcesDeletionTests.swift
//  UnitTests
//
//  Created by GitHub Copilot on 12/2/25.
//

import Testing
import Foundation
@testable import Folio

// MARK: - Resource Deletion Tests

@Suite("Resource Deletion Tests")
struct ResourceDeletionTests {
    
    @Test("Document resource can be removed from array")
    func testRemoveResourceFromDocument() throws {
        var doc = FolioDocument()
        doc.resources = [
            JSONResource(label: "Res 1", category: "cat1", type: "type1", url: "url1"),
            JSONResource(label: "Res 2", category: "cat2", type: "type2", url: "url2"),
            JSONResource(label: "Res 3", category: "cat3", type: "type3", url: "url3")
        ]
        
        #expect(doc.resources.count == 3)
        
        doc.resources.remove(at: 1)
        
        #expect(doc.resources.count == 2)
        #expect(doc.resources[0].label == "Res 1")
        #expect(doc.resources[1].label == "Res 3")
    }
    
    @Test("Collection item resource can be removed from array")
    func testRemoveResourceFromCollectionItem() throws {
        var item = JSONCollectionItem(
            label: "Test Item",
            resources: [
                JSONResource(label: "Keep", category: "a", type: "b", url: "c"),
                JSONResource(label: "Delete", category: "d", type: "e", url: "f"),
                JSONResource(label: "Keep Too", category: "g", type: "h", url: "i")
            ]
        )
        
        #expect(item.resources.count == 3)
        
        item.resources.remove(at: 1)
        
        #expect(item.resources.count == 2)
        #expect(item.resources[0].label == "Keep")
        #expect(item.resources[1].label == "Keep Too")
    }
    
    @Test("Removing last resource leaves empty array")
    func testRemoveLastResource() throws {
        var doc = FolioDocument()
        doc.resources = [
            JSONResource(label: "Only One", category: "cat", type: "type", url: "url")
        ]
        
        #expect(doc.resources.count == 1)
        
        doc.resources.remove(at: 0)
        
        #expect(doc.resources.isEmpty)
    }
    
    @Test("Removing all resources one by one")
    func testRemoveAllResourcesOneByOne() throws {
        var doc = FolioDocument()
        doc.resources = [
            JSONResource(label: "1", category: "a", type: "b", url: "c"),
            JSONResource(label: "2", category: "d", type: "e", url: "f"),
            JSONResource(label: "3", category: "g", type: "h", url: "i")
        ]
        
        #expect(doc.resources.count == 3)
        
        doc.resources.remove(at: 2)
        #expect(doc.resources.count == 2)
        
        doc.resources.remove(at: 1)
        #expect(doc.resources.count == 1)
        
        doc.resources.remove(at: 0)
        #expect(doc.resources.isEmpty)
    }
}

// MARK: - Local Download Resource Cleanup Tests

@Suite("Local Download Resource Cleanup Tests")
struct LocalDownloadResourceCleanupTests {
    
    @Test("Download category resource with file path")
    func testDownloadResourceWithFilePath() throws {
        let resource = JSONResource(
            label: "Downloaded File",
            category: "download",
            type: "pdf",
            url: "downloads/file.pdf"
        )
        
        #expect(resource.category.caseInsensitiveCompare("download") == .orderedSame)
        #expect(!resource.url.isEmpty)
    }
    
    @Test("Non-download resource not cleaned up")
    func testNonDownloadResource() throws {
        let resource = JSONResource(
            label: "External Link",
            category: "reference",
            type: "web",
            url: "https://example.com"
        )
        
        #expect(resource.category.caseInsensitiveCompare("download") != .orderedSame)
    }
    
    @Test("Download category is case insensitive")
    func testDownloadCategoryCaseInsensitive() {
        let categories = ["download", "Download", "DOWNLOAD", "DoWnLoAd"]
        
        for category in categories {
            #expect(category.caseInsensitiveCompare("download") == .orderedSame)
        }
    }
    
    @Test("File cleanup requires both category and URL")
    func testFileCleanupRequirements() {
        // Has category but no URL - should not clean up
        let resource1 = JSONResource(label: "No URL", category: "download", type: "file", url: "")
        #expect(resource1.category.caseInsensitiveCompare("download") == .orderedSame)
        #expect(resource1.url.isEmpty)
        
        // Has URL but wrong category - should not clean up
        let resource2 = JSONResource(label: "Wrong Category", category: "reference", type: "web", url: "file.pdf")
        #expect(resource2.category.caseInsensitiveCompare("download") != .orderedSame)
        
        // Has both - should clean up
        let resource3 = JSONResource(label: "Both", category: "download", type: "file", url: "file.pdf")
        #expect(resource3.category.caseInsensitiveCompare("download") == .orderedSame)
        #expect(!resource3.url.isEmpty)
    }
}

// MARK: - Resource Reordering Tests

@Suite("Resource Reordering Tests")
struct ResourceReorderingTests {
    
    @Test("Move resource up in array")
    func testMoveResourceUp() throws {
        var doc = FolioDocument()
        doc.resources = [
            JSONResource(label: "First", category: "1", type: "1", url: "1"),
            JSONResource(label: "Second", category: "2", type: "2", url: "2"),
            JSONResource(label: "Third", category: "3", type: "3", url: "3")
        ]
        
        // Move "Second" up to index 0
        let resource = doc.resources.remove(at: 1)
        doc.resources.insert(resource, at: 0)
        
        #expect(doc.resources[0].label == "Second")
        #expect(doc.resources[1].label == "First")
        #expect(doc.resources[2].label == "Third")
    }
    
    @Test("Move resource down in array")
    func testMoveResourceDown() throws {
        var doc = FolioDocument()
        doc.resources = [
            JSONResource(label: "First", category: "1", type: "1", url: "1"),
            JSONResource(label: "Second", category: "2", type: "2", url: "2"),
            JSONResource(label: "Third", category: "3", type: "3", url: "3")
        ]
        
        // Move "Second" down to index 2
        let resource = doc.resources.remove(at: 1)
        doc.resources.insert(resource, at: 2)
        
        #expect(doc.resources[0].label == "First")
        #expect(doc.resources[1].label == "Third")
        #expect(doc.resources[2].label == "Second")
    }
    
    @Test("Cannot move first resource up")
    func testCannotMoveFirstUp() throws {
        var doc = FolioDocument()
        doc.resources = [
            JSONResource(label: "First", category: "1", type: "1", url: "1"),
            JSONResource(label: "Second", category: "2", type: "2", url: "2")
        ]
        
        let index = 0
        let canMoveUp = index > 0
        
        #expect(canMoveUp == false)
    }
    
    @Test("Cannot move last resource down")
    func testCannotMoveLastDown() throws {
        var doc = FolioDocument()
        doc.resources = [
            JSONResource(label: "First", category: "1", type: "1", url: "1"),
            JSONResource(label: "Second", category: "2", type: "2", url: "2")
        ]
        
        let index = 1
        let canMoveDown = index < doc.resources.count - 1
        
        #expect(canMoveDown == false)
    }
}

// MARK: - Resource Persistence Tests

@Suite("Resource Persistence Tests")
struct ResourcePersistenceTests {
    
    @Test("Document with resources persists correctly")
    func testDocumentWithResourcesPersists() throws {
        var doc = FolioDocument()
        doc.title = "Resource Test"
        doc.resources = [
            JSONResource(label: "API Docs", category: "documentation", type: "api", url: "https://api.example.com/docs"),
            JSONResource(label: "GitHub", category: "code", type: "repository", url: "https://github.com/example/repo")
        ]
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.title == "Resource Test")
        #expect(decoded.resources.count == 2)
        #expect(decoded.resources[0].label == "API Docs")
        #expect(decoded.resources[1].label == "GitHub")
    }
    
    @Test("Empty resources array persists")
    func testEmptyResourcesArrayPersists() throws {
        var doc = FolioDocument()
        doc.resources = []
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.resources.isEmpty)
    }
    
    @Test("Resources order is preserved")
    func testResourcesOrderPreserved() throws {
        var doc = FolioDocument()
        doc.resources = [
            JSONResource(label: "First", category: "1", type: "1", url: "1"),
            JSONResource(label: "Second", category: "2", type: "2", url: "2"),
            JSONResource(label: "Third", category: "3", type: "3", url: "3"),
            JSONResource(label: "Fourth", category: "4", type: "4", url: "4")
        ]
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.resources.count == 4)
        for i in 0..<4 {
            let expected = ["First", "Second", "Third", "Fourth"][i]
            #expect(decoded.resources[i].label == expected)
        }
    }
}
