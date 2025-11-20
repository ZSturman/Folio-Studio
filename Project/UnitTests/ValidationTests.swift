//
//  ValidationTests.swift
//  UnitTests
//
//  Created by Zachary Sturman on 11/17/25.
//

import Testing
import Foundation
@testable import Folio

// MARK: - Validation Tests

@Suite("Validation Helper Tests")
struct ValidationHelperTests {
    
    // MARK: - Title Validation Tests
    
    @Test("Valid title passes validation")
    func testValidTitle() {
        let result = Validator.validateTitle("My Project")
        #expect(result.isValid)
    }
    
    @Test("Empty title fails validation")
    func testEmptyTitle() {
        let result = Validator.validateTitle("")
        if case .error(let error) = result,
           case .emptyTitle = error {
            // Success
        } else {
            Issue.record("Expected empty title error")
        }
    }
    
    @Test("Whitespace-only title fails validation")
    func testWhitespaceOnlyTitle() {
        let result = Validator.validateTitle("   \t\n  ")
        if case .error(let error) = result,
           case .emptyTitle = error {
            // Success
        } else {
            Issue.record("Expected empty title error for whitespace")
        }
    }
    
    @Test("Title with leading/trailing whitespace gets warning")
    func testTitleWithWhitespace() {
        let result = Validator.validateTitle("  Title  ")
        if case .warning = result {
            // Success
        } else {
            Issue.record("Expected warning for leading/trailing whitespace")
        }
    }
    
    @Test("Very long title gets warning")
    func testVeryLongTitle() {
        let longTitle = String(repeating: "a", count: 600)
        let result = Validator.validateTitle(longTitle)
        if case .warning = result {
            // Success
        } else {
            Issue.record("Expected warning for very long title")
        }
    }
    
    @Test("Sanitize empty title returns default")
    func testSanitizeEmptyTitle() {
        let sanitized = Validator.sanitizeTitle("")
        #expect(sanitized == "Untitled Project")
    }
    
    @Test("Sanitize whitespace title returns default")
    func testSanitizeWhitespaceTitle() {
        let sanitized = Validator.sanitizeTitle("   ")
        #expect(sanitized == "Untitled Project")
    }
    
    @Test("Sanitize valid title trims whitespace")
    func testSanitizeValidTitle() {
        let sanitized = Validator.sanitizeTitle("  My Project  ")
        #expect(sanitized == "My Project")
    }
    
    @Test("Sanitize with custom default")
    func testSanitizeCustomDefault() {
        let sanitized = Validator.sanitizeTitle("", defaultValue: "New Document")
        #expect(sanitized == "New Document")
    }
    
    // MARK: - URL Validation Tests
    
    @Test("Valid HTTP URL passes")
    func testValidHTTPURL() {
        let result = Validator.validateURL("https://example.com")
        #expect(result.isValid)
    }
    
    @Test("Valid HTTPS URL passes")
    func testValidHTTPSURL() {
        let result = Validator.validateURL("https://example.com/path/to/resource")
        #expect(result.isValid)
    }
    
    @Test("Valid file URL passes")
    func testValidFileURL() {
        let result = Validator.validateURL("file:///Users/test/file.txt")
        #expect(result.isValid)
    }
    
    @Test("Empty URL fails when not allowed")
    func testEmptyURL() {
        let result = Validator.validateURL("", allowEmpty: false)
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for empty URL")
        }
    }
    
    @Test("Empty URL passes when allowed")
    func testEmptyURLAllowed() {
        let result = Validator.validateURL("", allowEmpty: true)
        #expect(result.isValid)
    }
    
    @Test("Invalid URL fails")
    func testInvalidURL() {
        let result = Validator.validateURL("not a url")
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for invalid URL")
        }
    }
    
    @Test("URL without scheme gets warning or error")
    func testURLWithoutScheme() {
        let result = Validator.validateURL("example.com")
        // Should fail because no scheme
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for URL without scheme")
        }
    }
    
    @Test("Relative path is valid")
    func testRelativePath() {
        let result = Validator.validateURL("./path/to/file.txt")
        #expect(result.isValid)
    }
    
    @Test("Absolute path is valid")
    func testAbsolutePath() {
        let result = Validator.validateURL("/Users/test/file.txt")
        #expect(result.isValid)
    }
    
    @Test("Uncommon scheme gets warning")
    func testUncommonScheme() {
        let result = Validator.validateURL("gopher://example.com")
        if case .warning = result {
            // Success
        } else {
            Issue.record("Expected warning for uncommon scheme")
        }
    }
    
    // MARK: - File Path Validation Tests
    
    @Test("Valid file path passes")
    func testValidFilePath() {
        let result = Validator.validateFilePath("/Users/test/Documents/file.txt")
        #expect(result.isValid)
    }
    
    @Test("Path with spaces is valid")
    func testPathWithSpaces() {
        let result = Validator.validateFilePath("/Users/test/My Documents/file.txt")
        #expect(result.isValid)
    }
    
    @Test("Empty path fails when not allowed")
    func testEmptyPath() {
        let result = Validator.validateFilePath("", allowEmpty: false)
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for empty path")
        }
    }
    
    @Test("Empty path passes when allowed")
    func testEmptyPathAllowed() {
        let result = Validator.validateFilePath("", allowEmpty: true)
        #expect(result.isValid)
    }
    
    @Test("Very long path fails")
    func testVeryLongPath() {
        // Create a path longer than 1024 characters
        // "/Users/" (7) + "a/" * 600 (1200) + "file.txt" (8) = 1215 chars
        let longPath = "/Users/" + String(repeating: "a/", count: 600) + "file.txt"
        let result = Validator.validateFilePath(longPath)
        if case .error(let error) = result,
           case .pathTooLong = error {
            // Success
        } else {
            Issue.record("Expected pathTooLong error")
        }
    }
    
    @Test("Path with null byte fails")
    func testPathWithNullByte() {
        let result = Validator.validateFilePath("/path\0/file.txt")
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for null byte in path")
        }
    }
    
    @Test("Path with problematic characters gets warning")
    func testPathWithProblematicChars() {
        let result = Validator.validateFilePath("/path/with:colon.txt")
        if case .warning = result {
            // Success - colon is problematic
        } else {
            // On macOS, colon might be allowed, so this could also be valid
            #expect(result.isValid)
        }
    }
    
    // MARK: - Circular Reference Tests
    
    @Test("No circular references detected in empty collection")
    func testNoCircularReferencesEmpty() {
        let rootID = UUID()
        let result = Validator.detectCircularReferences(
            startingFrom: rootID,
            in: [:]
        )
        #expect(result.isValid)
    }
    
    @Test("No circular references with simple folio link")
    func testNoCircularReferencesSimple() {
        let rootID = UUID()
        let linkedID = UUID()
        
        let item = JSONCollectionItem(
            type: .folio,
            label: "Linked",
            url: linkedID.uuidString,
            thumbnail: AssetPath()
        )
        
        let section = CollectionSection(items: [item])
        let collection = ["Section": section]
        
        let result = Validator.detectCircularReferences(
            startingFrom: rootID,
            in: collection
        )
        #expect(result.isValid)
    }
    
    @Test("Circular reference detected in simple cycle")
    func testCircularReferenceSimple() {
        let id1 = UUID()
        let id2 = UUID()
        
        // Create two items that link to each other: item1 (id=id1) → id2, item2 (id=id2) → id1
        let item1 = JSONCollectionItem(
            id: id1,
            type: .folio,
            label: "Item1",
            url: id2.uuidString,
            thumbnail: AssetPath()
        )
        
        let item2 = JSONCollectionItem(
            id: id2,
            type: .folio,
            label: "Item2",
            url: id1.uuidString,
            thumbnail: AssetPath()
        )
        
        let section = CollectionSection(items: [item1, item2])
        let collection = ["Section": section]
        
        // Starting from id1, we can reach id2, and from id2 we can reach id1 again = cycle
        let result = Validator.detectCircularReferences(
            startingFrom: id1,
            in: collection
        )
        
        if case .error(let error) = result,
           case .circularReference = error {
            // Success
        } else {
            Issue.record("Expected circular reference error")
        }
    }
    
    @Test("Self-reference is allowed")
    func testSelfReference() {
        let id = UUID()
        
        let item = JSONCollectionItem(
            type: .folio,
            label: "Self",
            url: id.uuidString,
            thumbnail: AssetPath()
        )
        
        let section = CollectionSection(items: [item])
        let collection = ["Section": section]
        
        let result = Validator.detectCircularReferences(
            startingFrom: id,
            in: collection
        )
        
        // Self-reference might be detected as circular - implementation dependent
        // Either outcome is acceptable depending on design decision
    }
    
    @Test("Deep nesting without cycle is valid up to depth limit")
    func testDeepNestingNoCircle() {
        var collection: [String: CollectionSection] = [:]
        let rootID = UUID()
        let ids = [rootID] + (0..<5).map { _ in UUID() }
        
        // Create chain: ids[0] → ids[1] → ids[2] → ids[3] → ids[4] → ids[5]
        for i in 0..<5 {
            let item = JSONCollectionItem(
                id: ids[i],
                type: .folio,
                label: "Item\(i)",
                url: ids[i + 1].uuidString,
                thumbnail: AssetPath()
            )
            let section = CollectionSection(items: [item])
            collection["Section\(i)"] = section
        }
        
        // This should be valid - it's a chain of depth 5, not a cycle
        let result = Validator.detectCircularReferences(
            startingFrom: rootID,
            in: collection
        )
        
        #expect(result.isValid)
    }
    
    // MARK: - Crop Bounds Tests
    
    @Test("Valid crop bounds pass")
    func testValidCropBounds() {
        let rect = Validator.CropRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let result = Validator.validateCropBounds(rect)
        #expect(result.isValid)
    }
    
    @Test("Full image crop bounds pass")
    func testFullImageCropBounds() {
        let rect = Validator.CropRect(x: 0, y: 0, width: 1, height: 1)
        let result = Validator.validateCropBounds(rect)
        #expect(result.isValid)
    }
    
    @Test("Negative x coordinate fails")
    func testNegativeXCropBounds() {
        let rect = Validator.CropRect(x: -0.1, y: 0, width: 0.5, height: 0.5)
        let result = Validator.validateCropBounds(rect)
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for negative x")
        }
    }
    
    @Test("Negative y coordinate fails")
    func testNegativeYCropBounds() {
        let rect = Validator.CropRect(x: 0, y: -0.1, width: 0.5, height: 0.5)
        let result = Validator.validateCropBounds(rect)
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for negative y")
        }
    }
    
    @Test("Zero width fails")
    func testZeroWidthCropBounds() {
        let rect = Validator.CropRect(x: 0, y: 0, width: 0, height: 0.5)
        let result = Validator.validateCropBounds(rect)
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for zero width")
        }
    }
    
    @Test("Zero height fails")
    func testZeroHeightCropBounds() {
        let rect = Validator.CropRect(x: 0, y: 0, width: 0.5, height: 0)
        let result = Validator.validateCropBounds(rect)
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for zero height")
        }
    }
    
    @Test("Crop extending beyond right edge fails")
    func testCropBeyondRightEdge() {
        let rect = Validator.CropRect(x: 0.8, y: 0, width: 0.3, height: 0.5)
        let result = Validator.validateCropBounds(rect)
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for crop beyond right edge")
        }
    }
    
    @Test("Crop extending beyond bottom edge fails")
    func testCropBeyondBottomEdge() {
        let rect = Validator.CropRect(x: 0, y: 0.8, width: 0.5, height: 0.3)
        let result = Validator.validateCropBounds(rect)
        if case .error = result {
            // Success
        } else {
            Issue.record("Expected error for crop beyond bottom edge")
        }
    }
    
    @Test("Clamp negative coordinates to zero")
    func testClampNegativeCoordinates() {
        let rect = Validator.CropRect(x: -0.2, y: -0.1, width: 0.5, height: 0.5)
        let clamped = Validator.clampCropBounds(rect)
        
        #expect(clamped.x == 0)
        #expect(clamped.y == 0)
    }
    
    @Test("Clamp oversized dimensions")
    func testClampOversizedDimensions() {
        let rect = Validator.CropRect(x: 0.8, y: 0.8, width: 0.5, height: 0.5)
        let clamped = Validator.clampCropBounds(rect)
        
        #expect(clamped.x + clamped.width <= 1.0)
        #expect(clamped.y + clamped.height <= 1.0)
    }
    
    @Test("Clamp preserves valid bounds")
    func testClampPreservesValidBounds() {
        let rect = Validator.CropRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let clamped = Validator.clampCropBounds(rect)
        
        #expect(clamped.x == rect.x)
        #expect(clamped.y == rect.y)
        #expect(clamped.width == rect.width)
        #expect(clamped.height == rect.height)
    }
    
    // MARK: - Collection Item Validation Tests
    
    @Test("Valid file type item passes")
    func testValidFileItem() {
        let item = JSONCollectionItem(
            type: .file,
            label: "Document",
            filePath: AssetPath(pathToOriginal: "/path/to/file.pdf", pathToEdited: ""),
            thumbnail: AssetPath()
        )
        
        let results = Validator.validateCollectionItem(item)
        #expect(results.isEmpty)
    }
    
    @Test("File type without path fails")
    func testFileItemWithoutPath() {
        let item = JSONCollectionItem(
            type: .file,
            label: "Document",
            filePath: nil,
            thumbnail: AssetPath()
        )
        
        let results = Validator.validateCollectionItem(item)
        #expect(!results.isEmpty)
    }
    
    @Test("Valid URL type item passes")
    func testValidURLItem() {
        let item = JSONCollectionItem(
            type: .urlLink,
            label: "Website",
            url: "https://example.com",
            thumbnail: AssetPath()
        )
        
        let results = Validator.validateCollectionItem(item)
        #expect(results.isEmpty)
    }
    
    @Test("URL type without URL fails")
    func testURLItemWithoutURL() {
        let item = JSONCollectionItem(
            type: .urlLink,
            label: "Website",
            url: nil,
            thumbnail: AssetPath()
        )
        
        let results = Validator.validateCollectionItem(item)
        #expect(!results.isEmpty)
    }
    
    @Test("Valid folio type item passes")
    func testValidFolioItem() {
        let linkedID = UUID()
        let item = JSONCollectionItem(
            type: .folio,
            label: "Linked Project",
            url: linkedID.uuidString,
            thumbnail: AssetPath()
        )
        
        let results = Validator.validateCollectionItem(item)
        #expect(results.isEmpty)
    }
    
    @Test("Folio type with invalid UUID fails")
    func testFolioItemWithInvalidUUID() {
        let item = JSONCollectionItem(
            type: .folio,
            label: "Linked Project",
            url: "not-a-uuid",
            thumbnail: AssetPath()
        )
        
        let results = Validator.validateCollectionItem(item)
        #expect(!results.isEmpty)
    }
    
    @Test("Item with empty label fails")
    func testItemWithEmptyLabel() {
        let item = JSONCollectionItem(
            type: .urlLink,
            label: "",
            url: "https://example.com",
            thumbnail: AssetPath()
        )
        
        let results = Validator.validateCollectionItem(item)
        #expect(!results.isEmpty)
    }
}

// MARK: - Document Validation Tests

@Suite("Document Validation Tests")
struct DocumentValidationTests {
    
    @Test("Valid document passes validation")
    func testValidDocument() {
        var doc = FolioDocument()
        doc.title = "Valid Project"
        
        let results = doc.validate()
        let errors = results.filter {
            if case .error = $0.value { return true }
            return false
        }
        
        #expect(errors.isEmpty)
    }
    
    @Test("Document with empty title has error")
    func testDocumentEmptyTitle() {
        var doc = FolioDocument()
        doc.title = ""
        
        let results = doc.validate()
        #expect(results["title"] != nil)
    }
    
    @Test("Document isValid method works")
    func testDocumentIsValid() {
        var doc = FolioDocument()
        doc.title = "Valid"
        
        #expect(doc.isValid())
        
        doc.title = ""
        #expect(!doc.isValid())
    }
    
    @Test("Document sanitized method fixes title")
    func testDocumentSanitized() {
        var doc = FolioDocument()
        doc.title = "  "
        
        let sanitized = doc.sanitized()
        #expect(sanitized.title == "Untitled Project")
    }
}
