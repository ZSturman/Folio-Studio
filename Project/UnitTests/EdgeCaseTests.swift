//
//  EdgeCaseTests.swift
//  UnitTests
//
//  Created by Zachary Sturman on 11/17/25.
//

import Testing
import Foundation
@testable import Folio

// MARK: - Document Edge Case Tests

@Suite("Document Edge Case Tests")
struct DocumentEdgeCaseTests {
    
    // MARK: - Corrupt Data Tests
    
    @Test("Handle completely empty JSON")
    func testEmptyJSON() throws {
        let jsonString = "{}"
        let data = jsonString.data(using: .utf8)!
        
        // Should successfully decode with defaults (graceful handling)
        let doc = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        // Verify defaults are applied
        #expect(doc.title == "")
        #expect(doc.subtitle == "")
        #expect(doc.isPublic == false)
        #expect(doc.featured == false)
    }
    
    @Test("Handle malformed JSON")
    func testMalformedJSON() throws {
        let jsonString = "{invalid json"
        let data = jsonString.data(using: .utf8)!
        
        #expect(throws: Error.self) {
            try JSONDecoder().decode(FolioDocument.self, from: data)
        }
    }
    
    @Test("Handle JSON with wrong types for required fields")
    func testWrongTypes() throws {
        let jsonString = """
        {
            "id": "00000000-0000-0000-0000-000000000000",
            "title": 123,
            "subtitle": false,
            "isPublic": "not a boolean",
            "summary": [],
            "featured": "yes",
            "requiresFollowUp": 1,
            "values": {}
        }
        """
        let data = jsonString.data(using: .utf8)!
        
        #expect(throws: Error.self) {
            try JSONDecoder().decode(FolioDocument.self, from: data)
        }
    }
    
    @Test("Handle array fields with wrong item types")
    func testArrayWithWrongItemTypes() throws {
        let jsonString = """
        {
            "id": "00000000-0000-0000-0000-000000000000",
            "title": "Test",
            "subtitle": "",
            "isPublic": false,
            "summary": "",
            "featured": false,
            "requiresFollowUp": false,
            "tags": ["valid", 123, true, null],
            "values": {}
        }
        """
        let data = jsonString.data(using: .utf8)!
        
        // Should fail or skip invalid items
        #expect(throws: Error.self) {
            try JSONDecoder().decode(FolioDocument.self, from: data)
        }
    }
    
    // MARK: - Boundary Value Tests
    
    @Test("Handle maximum integer values")
    func testMaxIntegerValues() throws {
        let detail = DetailItem(key: "max", value: .number(Double(Int.max)))
        
        let data = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        #expect(decoded.value.number != nil)
    }
    
    @Test("Handle very small decimal values")
    func testVerySmallDecimals() throws {
        let detail = DetailItem(key: "tiny", value: .number(0.00000000001))
        
        let data = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        #expect(decoded.value.number != nil)
    }
    
    @Test("Handle negative numbers")
    func testNegativeNumbers() throws {
        let detail = DetailItem(key: "negative", value: .number(-999.999))
        
        let data = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        #expect(decoded.value.number == -999.999)
    }
    
    @Test("Handle infinity and NaN")
    func testSpecialFloatingValues() throws {
        // JSON doesn't support Infinity or NaN
        // These should be handled gracefully
        let detail = DetailItem(key: "special", value: .number(.infinity))
        
        #expect(throws: Error.self) {
            let _ = try JSONEncoder().encode(detail)
        }
    }
    
    // MARK: - String Edge Cases
    
    @Test("Handle newlines and special whitespace")
    func testSpecialWhitespace() throws {
        var doc = FolioDocument()
        doc.title = "Line1\nLine2\tTabbed\r\nWindows"
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.title.contains("\n"))
        #expect(decoded.title.contains("\t"))
    }
    
    @Test("Handle null characters in strings")
    func testNullCharacters() throws {
        var doc = FolioDocument()
        doc.title = "Test\u{0000}Null"
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        // Should preserve or handle gracefully
        #expect(!decoded.title.isEmpty)
    }
    
    @Test("Handle control characters")
    func testControlCharacters() throws {
        var doc = FolioDocument()
        doc.title = "Test\u{0001}\u{0002}\u{001F}"
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(!decoded.title.isEmpty)
    }
    
    @Test("Handle RTL and mixed direction text")
    func testRTLText() throws {
        var doc = FolioDocument()
        doc.title = "English עברית العربية Mixed"
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.title == "English עברית العربية Mixed")
    }
    
    @Test("Handle zero-width characters")
    func testZeroWidthCharacters() throws {
        var doc = FolioDocument()
        doc.title = "Test\u{200B}Zero\u{200C}Width\u{200D}Chars"
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(!decoded.title.isEmpty)
    }
    
    // MARK: - Collection Edge Cases
    
    @Test("Handle empty collection sections")
    func testEmptyCollectionSections() throws {
        var doc = FolioDocument()
        doc.collection["EmptySection"] = CollectionSection()
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.collection["EmptySection"]?.items.isEmpty == true)
    }
    
    @Test("Handle collection with duplicate item IDs")
    func testDuplicateCollectionItemIDs() throws {
        let sharedID = UUID()
        let item1 = JSONCollectionItem(id: sharedID, type: .file, thumbnail: AssetPath())
        let item2 = JSONCollectionItem(id: sharedID, type: .urlLink, thumbnail: AssetPath())
        
        var section = CollectionSection()
        section.items = [item1, item2]
        
        // Should encode/decode but IDs will be same
        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(CollectionSection.self, from: data)
        
        #expect(decoded.items.count == 2)
        #expect(decoded.items[0].id == decoded.items[1].id)
    }
    
    @Test("Handle collection section with special characters in name")
    func testCollectionSectionSpecialChars() throws {
        var doc = FolioDocument()
        doc.collection["Section/With\\Special:Chars*?"] = CollectionSection()
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.collection.keys.contains("Section/With\\Special:Chars*?"))
    }
    
    @Test("Handle very long collection section names")
    func testVeryLongSectionNames() throws {
        var doc = FolioDocument()
        let longName = String(repeating: "a", count: 1000)
        doc.collection[longName] = CollectionSection()
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.collection.keys.contains(longName))
    }
    
    // MARK: - Asset Path Edge Cases
    
    @Test("Handle asset paths with URL encoding")
    func testAssetPathURLEncoding() throws {
        let asset = AssetPath(
            pathToOriginal: "/path/with spaces/and&special.jpg",
            pathToEdited: "/path/with%20encoded.jpg"
        )
        
        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(AssetPath.self, from: data)
        
        #expect(decoded.pathToOriginal.contains(" "))
        #expect(decoded.pathToOriginal.contains("&"))
    }
    
    @Test("Handle very long file paths")
    func testVeryLongFilePaths() throws {
        let longPath = "/Users/" + String(repeating: "a/", count: 500) + "file.jpg"
        let asset = AssetPath(pathToOriginal: longPath, pathToEdited: "")
        
        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(AssetPath.self, from: data)
        
        #expect(decoded.pathToOriginal.count > 1000)
    }
    
    @Test("Handle paths with null bytes")
    func testPathsWithNullBytes() throws {
        // macOS paths shouldn't contain null bytes, but test handling
        let asset = AssetPath(pathToOriginal: "/path\0/file.jpg", pathToEdited: "")
        
        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(AssetPath.self, from: data)
        
        #expect(!decoded.pathToOriginal.isEmpty)
    }
    
    // MARK: - UUID Edge Cases
    
    @Test("Handle nil UUID")
    func testNilUUID() throws {
        let jsonString = """
        {
            "id": null,
            "title": "Test",
            "subtitle": "",
            "isPublic": false,
            "summary": "",
            "featured": false,
            "requiresFollowUp": false,
            "values": {}
        }
        """
        let data = jsonString.data(using: .utf8)!
        
        // Should successfully decode with a generated UUID (graceful handling)
        let doc = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        // Verify a UUID was generated and other fields decoded correctly
        #expect(doc.title == "Test")
        #expect(doc.subtitle == "")
    }
    
    @Test("Handle invalid UUID string")
    func testInvalidUUIDString() throws {
        let jsonString = """
        {
            "id": "not-a-valid-uuid",
            "title": "Test",
            "subtitle": "",
            "isPublic": false,
            "summary": "",
            "featured": false,
            "requiresFollowUp": false,
            "values": {}
        }
        """
        let data = jsonString.data(using: .utf8)!
        
        #expect(throws: Error.self) {
            try JSONDecoder().decode(FolioDocument.self, from: data)
        }
    }
    
    // MARK: - Date Edge Cases
    
    @Test("Handle dates before Unix epoch")
    func testDatesBeforeEpoch() throws {
        var doc = FolioDocument()
        doc.createdAt = Date(timeIntervalSince1970: -86400) // 1 day before epoch
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.createdAt != nil)
    }
    
    @Test("Handle very far future dates")
    func testFarFutureDates() throws {
        var doc = FolioDocument()
        doc.updatedAt = Date(timeIntervalSince1970: 4102444800) // Year 2100
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.updatedAt != nil)
    }
    
    // MARK: - Resource Edge Cases
    
    @Test("Handle resource with empty URL")
    func testResourceEmptyURL() throws {
        let resource = JSONResource(label: "Test", category: "Cat", type: "Type", url: "")
        
        let data = try JSONEncoder().encode(resource)
        let decoded = try JSONDecoder().decode(JSONResource.self, from: data)
        
        #expect(decoded.url == "")
    }
    
    @Test("Handle resource with invalid URL")
    func testResourceInvalidURL() throws {
        let resource = JSONResource(label: "Test", category: "Cat", type: "Type", url: "not a url")
        
        let data = try JSONEncoder().encode(resource)
        let decoded = try JSONDecoder().decode(JSONResource.self, from: data)
        
        // Should preserve even if invalid
        #expect(decoded.url == "not a url")
    }
    
    @Test("Handle resource with very long URL")
    func testResourceVeryLongURL() throws {
        let longURL = "https://example.com/" + String(repeating: "path/", count: 1000)
        let resource = JSONResource(label: "Test", category: "Cat", type: "Type", url: longURL)
        
        let data = try JSONEncoder().encode(resource)
        let decoded = try JSONDecoder().decode(JSONResource.self, from: data)
        
        #expect(decoded.url.count > 5000)
    }
    
    // MARK: - Nested Structure Edge Cases
    
    @Test("Handle deeply nested JSONValue objects")
    func testDeeplyNestedJSONValue() throws {
        // Create deeply nested structure
        var nested: JSONValue = .string("deep")
        for _ in 0..<100 {
            nested = .array([nested])
        }
        
        let detail = DetailItem(key: "nested", value: nested)
        
        let data = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        // Should handle deep nesting
        #expect(decoded.key == "nested")
    }
    
    @Test("Handle circular reference detection in collections")
    func testCircularFolioReferences() throws {
        // Create two folio items that reference each other
        let id1 = UUID()
        let id2 = UUID()
        
        let item1 = JSONCollectionItem(
            type: .folio,
            label: "Item1",
            url: id2.uuidString,
            thumbnail: AssetPath()
        )
        
        let item2 = JSONCollectionItem(
            type: .folio,
            label: "Item2",
            url: id1.uuidString,
            thumbnail: AssetPath()
        )
        
        // Should encode without error (detection happens at runtime)
        let data1 = try JSONEncoder().encode(item1)
        let data2 = try JSONEncoder().encode(item2)
        
        let decoded1 = try JSONDecoder().decode(JSONCollectionItem.self, from: data1)
        let decoded2 = try JSONDecoder().decode(JSONCollectionItem.self, from: data2)
        
        #expect(decoded1.url == id2.uuidString)
        #expect(decoded2.url == id1.uuidString)
    }
    
    // MARK: - Image Label Edge Cases
    
    @Test("Handle custom image label with reserved prefix")
    func testCustomLabelWithReservedPrefix() throws {
        let label = ImageLabel.custom("custom:nested")
        
        let data = try JSONEncoder().encode(label)
        let decoded = try JSONDecoder().decode(ImageLabel.self, from: data)
        
        if case .custom(let name) = decoded {
            #expect(name == "custom:nested")
        } else {
            Issue.record("Should preserve custom label")
        }
    }
    
    @Test("Handle custom image label with special characters")
    func testCustomLabelSpecialChars() throws {
        let label = ImageLabel.custom("My Image! @#$%")
        
        let data = try JSONEncoder().encode(label)
        let decoded = try JSONDecoder().decode(ImageLabel.self, from: data)
        
        if case .custom(let name) = decoded {
            #expect(name.contains("!"))
            #expect(name.contains("@"))
        } else {
            Issue.record("Should preserve custom label")
        }
    }
    
    @Test("Handle empty custom image label")
    func testEmptyCustomLabel() throws {
        let label = ImageLabel.custom("")
        
        let data = try JSONEncoder().encode(label)
        let decoded = try JSONDecoder().decode(ImageLabel.self, from: data)
        
        if case .custom(let name) = decoded {
            #expect(name == "")
        } else {
            Issue.record("Should preserve empty custom label")
        }
    }
}

// MARK: - Validation Tests

@Suite("Validation Tests")
struct ValidationTests {
    
    @Test("Empty title validation")
    func testEmptyTitleValidation() {
        let doc = FolioDocument()
        
        // Currently no validation - empty title is allowed
        #expect(doc.title == "")
        
        // TODO: Should empty titles be validated?
    }
    
    @Test("Whitespace-only fields validation")
    func testWhitespaceValidation() {
        var doc = FolioDocument()
        doc.title = "   "
        doc.subtitle = "\t\n"
        
        // Currently no trimming - whitespace is preserved
        #expect(doc.title == "   ")
        
        // TODO: Should whitespace be trimmed?
    }
    
    @Test("URL format validation")
    func testURLFormatValidation() {
        let resource = JSONResource(label: "Test", category: "Cat", type: "Type", url: "not-a-url")
        
        // Currently no URL validation
        #expect(resource.url == "not-a-url")
        
        // TODO: Should URLs be validated?
    }
    
    @Test("File path format validation")
    func testFilePathValidation() {
        let asset = AssetPath(pathToOriginal: "invalid<>path", pathToEdited: "")
        
        // Currently no path validation
        #expect(asset.pathToOriginal.contains("<"))
        
        // TODO: Should file paths be validated?
    }
    
    @Test("UUID uniqueness validation")
    func testUUIDUniqueness() {
        let id = UUID()
        let item1 = JSONCollectionItem(id: id, type: .file, thumbnail: AssetPath())
        let item2 = JSONCollectionItem(id: id, type: .urlLink, thumbnail: AssetPath())
        
        // Currently no uniqueness check
        #expect(item1.id == item2.id)
        
        // TODO: Should duplicate UUIDs be prevented?
    }
}
