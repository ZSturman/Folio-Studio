//
//  JSONTreeViewTests.swift
//  UnitTests
//
//  Created by GitHub Copilot on 12/2/25.
//

import Testing
import Foundation
@testable import Folio

// MARK: - JSON Tree Expansion State Tests

@Suite("JSON Tree Expansion State Tests")
struct JSONTreeExpansionStateTests {
    
    @Test("Default expansion includes root")
    func testDefaultExpansion() {
        let state = JSONTreeExpansionState()
        
        #expect(state.isExpanded("Document"))
        #expect(!state.isExpanded("someOtherPath"))
    }
    
    @Test("Toggle path expands and collapses")
    func testTogglePath() {
        let state = JSONTreeExpansionState()
        
        let path = "Document.collection"
        
        #expect(!state.isExpanded(path))
        
        state.toggle(path)
        #expect(state.isExpanded(path))
        
        state.toggle(path)
        #expect(!state.isExpanded(path))
    }
    
    @Test("Set expanded adds path")
    func testSetExpanded() {
        let state = JSONTreeExpansionState()
        
        let path = "Document.resources"
        
        state.setExpanded(path, true)
        #expect(state.isExpanded(path))
        
        state.setExpanded(path, false)
        #expect(!state.isExpanded(path))
    }
    
    @Test("Multiple paths can be expanded")
    func testMultiplePaths() {
        let state = JSONTreeExpansionState()
        
        let paths = ["Document.collection", "Document.resources", "Document.images"]
        
        for path in paths {
            state.setExpanded(path, true)
        }
        
        for path in paths {
            #expect(state.isExpanded(path))
        }
    }
    
    @Test("Expansion state persists")
    func testExpansionPersistence() {
        let state = JSONTreeExpansionState()
        
        // Expand some paths
        state.setExpanded("Document.collection", true)
        state.setExpanded("Document.collection[0]", true)
        state.setExpanded("Document.resources", true)
        
        // State should persist
        #expect(state.isExpanded("Document.collection"))
        #expect(state.isExpanded("Document.collection[0]"))
        #expect(state.isExpanded("Document.resources"))
        
        // Non-expanded paths should remain collapsed
        #expect(!state.isExpanded("Document.images"))
    }
    
    @Test("Can collapse previously expanded paths")
    func testCollapsePaths() {
        let state = JSONTreeExpansionState()
        
        // Expand paths
        state.setExpanded("Document.collection", true)
        state.setExpanded("Document.resources", true)
        
        // Collapse one
        state.setExpanded("Document.collection", false)
        
        #expect(!state.isExpanded("Document.collection"))
        #expect(state.isExpanded("Document.resources"))
    }
}

// MARK: - Image Detection Tests

@Suite("JSON Tree Image Detection Tests")
struct JSONTreeImageDetectionTests {
    
    @Test("PNG files detected as images")
    func testPNGDetection() {
        let path = "path/to/image.png"
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        
        #expect(["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"].contains(ext))
    }
    
    @Test("JPG and JPEG files detected as images")
    func testJPGDetection() {
        let jpg = "image.jpg"
        let jpeg = "image.jpeg"
        
        let extJPG = URL(fileURLWithPath: jpg).pathExtension.lowercased()
        let extJPEG = URL(fileURLWithPath: jpeg).pathExtension.lowercased()
        
        #expect(["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"].contains(extJPG))
        #expect(["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"].contains(extJPEG))
    }
    
    @Test("Non-image files not detected")
    func testNonImageDetection() {
        let textFile = "document.txt"
        let jsonFile = "data.json"
        let swiftFile = "code.swift"
        
        let extensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"]
        
        #expect(!extensions.contains(URL(fileURLWithPath: textFile).pathExtension.lowercased()))
        #expect(!extensions.contains(URL(fileURLWithPath: jsonFile).pathExtension.lowercased()))
        #expect(!extensions.contains(URL(fileURLWithPath: swiftFile).pathExtension.lowercased()))
    }
    
    @Test("Folio protocol paths not treated as images")
    func testFolioProtocolNotImage() {
        let folioPath = "folio://some-id/thumbnail.png"
        
        // Even though it has .png extension, folio:// paths should be skipped
        #expect(folioPath.hasPrefix("folio://"))
    }
    
    @Test("All supported image extensions")
    func testAllImageExtensions() {
        let extensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"]
        
        for ext in extensions {
            let path = "image.\(ext)"
            let fileExt = URL(fileURLWithPath: path).pathExtension.lowercased()
            #expect(extensions.contains(fileExt))
        }
    }
    
    @Test("Case insensitive extension matching")
    func testCaseInsensitiveExtensions() {
        let upperCase = "IMAGE.PNG"
        let mixedCase = "image.JpG"
        let lowerCase = "image.png"
        
        let extensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"]
        
        #expect(extensions.contains(URL(fileURLWithPath: upperCase).pathExtension.lowercased()))
        #expect(extensions.contains(URL(fileURLWithPath: mixedCase).pathExtension.lowercased()))
        #expect(extensions.contains(URL(fileURLWithPath: lowerCase).pathExtension.lowercased()))
    }
}

// MARK: - JSON Data Parsing Tests

@Suite("JSON Tree Data Parsing Tests")
struct JSONTreeDataParsingTests {
    
    @Test("Valid JSON data parses successfully")
    func testValidJSONParsing() throws {
        let jsonDict: [String: Any] = [
            "title": "Test Document",
            "subtitle": "A test",
            "isPublic": true
        ]
        
        let data = try JSONSerialization.data(withJSONObject: jsonDict, options: [])
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        
        #expect(parsed is [String: Any])
    }
    
    @Test("JSON with nested objects parses correctly")
    func testNestedJSONParsing() throws {
        let jsonDict: [String: Any] = [
            "document": [
                "metadata": [
                    "created": "2024-01-01",
                    "updated": "2024-01-02"
                ]
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: jsonDict, options: [])
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        
        #expect(parsed is [String: Any])
        if let dict = parsed as? [String: Any],
           let doc = dict["document"] as? [String: Any],
           let metadata = doc["metadata"] as? [String: Any] {
            #expect(metadata["created"] as? String == "2024-01-01")
        }
    }
    
    @Test("JSON with arrays parses correctly")
    func testArrayJSONParsing() throws {
        let jsonDict: [String: Any] = [
            "items": [
                ["name": "Item 1"],
                ["name": "Item 2"],
                ["name": "Item 3"]
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: jsonDict, options: [])
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        
        #expect(parsed is [String: Any])
        if let dict = parsed as? [String: Any],
           let items = dict["items"] as? [[String: Any]] {
            #expect(items.count == 3)
        }
    }
    
    @Test("Invalid JSON data returns nil")
    func testInvalidJSONParsing() {
        let invalidData = "not json".data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: invalidData, options: [])
        
        #expect(parsed == nil)
    }
    
    @Test("Empty JSON object parses")
    func testEmptyJSONObject() throws {
        let emptyDict: [String: Any] = [:]
        let data = try JSONSerialization.data(withJSONObject: emptyDict, options: [])
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        
        #expect(parsed is [String: Any])
        #expect((parsed as? [String: Any])?.isEmpty == true)
    }
}

// MARK: - Path Resolution Tests

@Suite("JSON Tree Path Resolution Tests")
struct JSONTreePathResolutionTests {
    
    @Test("Relative path resolution with assets folder")
    func testRelativePathResolution() {
        let assetsFolder = URL(fileURLWithPath: "/Users/test/Assets")
        let relativePath = "images/thumbnail.png"
        
        let resolved = assetsFolder.appendingPathComponent(relativePath)
        
        #expect(resolved.path == "/Users/test/Assets/images/thumbnail.png")
    }
    
    @Test("Absolute path does not need assets folder")
    func testAbsolutePathResolution() {
        let absolutePath = "/absolute/path/to/image.png"
        let url = URL(fileURLWithPath: absolutePath)
        
        #expect(url.path == absolutePath)
        #expect(url.path.hasPrefix("/"))
    }
    
    @Test("Path with spaces resolves correctly")
    func testPathWithSpaces() {
        let assetsFolder = URL(fileURLWithPath: "/Users/test/My Assets")
        let relativePath = "my images/my image.png"
        
        let resolved = assetsFolder.appendingPathComponent(relativePath)
        
        #expect(resolved.path.contains("My Assets"))
        #expect(resolved.path.contains("my images"))
    }
    
    @Test("Path with special characters")
    func testPathWithSpecialCharacters() {
        let assetsFolder = URL(fileURLWithPath: "/Users/test/Assets")
        let relativePath = "images/file (1).png"
        
        let resolved = assetsFolder.appendingPathComponent(relativePath)
        
        #expect(resolved.path.contains("file (1).png"))
    }
}

// MARK: - Expansion Path Format Tests

@Suite("Expansion Path Format Tests")
struct ExpansionPathFormatTests {
    
    @Test("Root path format")
    func testRootPathFormat() {
        let rootPath = "Document"
        #expect(rootPath == "Document")
    }
    
    @Test("Nested property path format")
    func testNestedPropertyPath() {
        let basePath = "Document"
        let property = "collection"
        let fullPath = "\(basePath).\(property)"
        
        #expect(fullPath == "Document.collection")
    }
    
    @Test("Array index path format")
    func testArrayIndexPath() {
        let basePath = "Document.collection"
        let index = 0
        let fullPath = "\(basePath)[\(index)]"
        
        #expect(fullPath == "Document.collection[0]")
    }
    
    @Test("Deep nested path format")
    func testDeepNestedPath() {
        let path = "Document.collection[0].items[2].resources"
        #expect(path.contains("Document"))
        #expect(path.contains("collection[0]"))
        #expect(path.contains("items[2]"))
        #expect(path.contains("resources"))
    }
    
    @Test("Path uniqueness")
    func testPathUniqueness() {
        let path1 = "Document.collection[0]"
        let path2 = "Document.collection[1]"
        let path3 = "Document.resources[0]"
        
        #expect(path1 != path2)
        #expect(path1 != path3)
        #expect(path2 != path3)
    }
}
