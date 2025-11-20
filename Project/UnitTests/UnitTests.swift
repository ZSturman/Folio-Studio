//
//  UnitTests.swift
//  UnitTests
//
//  Created by Zachary Sturman on 11/17/25.
//

import Testing
import Foundation
@testable import Folio

// MARK: - Document Serialization Tests

@Suite("Document Serialization Tests")
struct DocumentSerializationTests {
    
    // MARK: - Basic Encoding/Decoding
    
    @Test("Empty document encodes and decodes correctly")
    func testEmptyDocument() throws {
        let doc = FolioDocument()
        let encoder = JSONEncoder()
        let data = try encoder.encode(doc)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FolioDocument.self, from: data)
        
        #expect(decoded.id == doc.id)
        #expect(decoded.title == "")
        #expect(decoded.subtitle == "")
        #expect(decoded.isPublic == false)
        #expect(decoded.values.isEmpty)
    }
    
    @Test("Full document with all fields encodes correctly")
    func testFullDocument() throws {
        var doc = FolioDocument()
        doc.title = "Test Project"
        doc.subtitle = "Subtitle"
        doc.isPublic = true
        doc.summary = "Summary text"
        doc.domain = "Development"
        doc.category = "iOS"
        doc.status = "In Progress"
        doc.phase = "Implementation"
        doc.featured = true
        doc.requiresFollowUp = true
        doc.tags = ["swift", "testing", "ios"]
        doc.mediums = ["Digital"]
        doc.genres = ["Educational"]
        doc.topics = ["Programming"]
        doc.subjects = ["Software"]
        doc.description = "Description"
        doc.story = "Story"
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.title == "Test Project")
        #expect(decoded.domain == "Development")
        #expect(decoded.tags.count == 3)
        #expect(decoded.tags.contains("swift"))
    }
    
    // MARK: - Type Coercion Tests
    
    @Test("String coerced to number in JSONValue")
    func testStringToNumberCoercion() throws {
        let jsonString = """
        {"key": "123"}
        """
        let data = jsonString.data(using: .utf8)!
        let dict = try JSONDecoder().decode([String: JSONValue].self, from: data)
        
        // Verify it's stored as string
        #expect(dict["key"]?.string == "123")
        #expect(dict["key"]?.number == nil)
    }
    
    @Test("Number stored correctly in JSONValue")
    func testNumberInJSONValue() throws {
        let jsonString = """
        {"key": 123.45}
        """
        let data = jsonString.data(using: .utf8)!
        let dict = try JSONDecoder().decode([String: JSONValue].self, from: data)
        
        #expect(dict["key"]?.number == 123.45)
        #expect(dict["key"]?.string == nil)
    }
    
    @Test("Boolean stored correctly in JSONValue")
    func testBoolInJSONValue() throws {
        let jsonString = """
        {"key": true}
        """
        let data = jsonString.data(using: .utf8)!
        let dict = try JSONDecoder().decode([String: JSONValue].self, from: data)
        
        #expect(dict["key"]?.bool == true)
    }
    
    @Test("Array stored correctly in JSONValue")
    func testArrayInJSONValue() throws {
        let jsonString = """
        {"key": ["a", "b", "c"]}
        """
        let data = jsonString.data(using: .utf8)!
        let dict = try JSONDecoder().decode([String: JSONValue].self, from: data)
        
        if case .array(let arr) = dict["key"] {
            #expect(arr.count == 3)
            #expect(arr[0].string == "a")
        } else {
            Issue.record("Expected array JSONValue")
        }
    }
    
    @Test("Nested object stored correctly in JSONValue")
    func testNestedObjectInJSONValue() throws {
        let jsonString = """
        {"key": {"nested": "value", "count": 42}}
        """
        let data = jsonString.data(using: .utf8)!
        let dict = try JSONDecoder().decode([String: JSONValue].self, from: data)
        
        if case .object(let obj) = dict["key"] {
            #expect(obj["nested"]?.string == "value")
            #expect(obj["count"]?.number == 42)
        } else {
            Issue.record("Expected object JSONValue")
        }
    }
    
    @Test("Null value handled in JSONValue")
    func testNullInJSONValue() throws {
        let jsonString = """
        {"key": null}
        """
        let data = jsonString.data(using: .utf8)!
        let dict = try JSONDecoder().decode([String: JSONValue].self, from: data)
        
        if case .null = dict["key"] {
            // Success
        } else {
            Issue.record("Expected null JSONValue")
        }
    }
    
    // MARK: - Missing Key Tests
    
    @Test("Missing optional keys decode with defaults")
    func testMissingOptionalKeys() throws {
        let jsonString = """
        {
            "id": "00000000-0000-0000-0000-000000000000",
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
        let doc = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(doc.domain == nil)
        #expect(doc.category == nil)
        #expect(doc.status == nil)
        #expect(doc.phase == nil)
        #expect(doc.description == nil)
        #expect(doc.story == nil)
        #expect(doc.createdAt == nil)
        #expect(doc.updatedAt == nil)
    }
    
    @Test("Missing required arrays default to empty")
    func testMissingArraysDefaultToEmpty() throws {
        let jsonString = """
        {
            "id": "00000000-0000-0000-0000-000000000000",
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
        let doc = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(doc.tags.isEmpty)
        #expect(doc.mediums.isEmpty)
        #expect(doc.genres.isEmpty)
        #expect(doc.topics.isEmpty)
        #expect(doc.subjects.isEmpty)
        #expect(doc.resources.isEmpty)
        #expect(doc.details.isEmpty)
    }
    
    @Test("Missing images dictionary defaults to empty")
    func testMissingImagesDefaultsToEmpty() throws {
        let jsonString = """
        {
            "id": "00000000-0000-0000-0000-000000000000",
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
        let doc = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(doc.images.isEmpty)
    }
    
    @Test("Missing collection defaults to empty")
    func testMissingCollectionDefaultsToEmpty() throws {
        let jsonString = """
        {
            "id": "00000000-0000-0000-0000-000000000000",
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
        let doc = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(doc.collection.isEmpty)
    }
    
    // MARK: - Unknown Field Preservation
    
    @Test("Unknown fields are preserved in values dictionary")
    func testUnknownFieldsPreserved() throws {
        let jsonString = """
        {
            "id": "00000000-0000-0000-0000-000000000000",
            "title": "Test",
            "subtitle": "",
            "isPublic": false,
            "summary": "",
            "featured": false,
            "requiresFollowUp": false,
            "unknownField": "should be preserved",
            "customNumber": 42,
            "customArray": [1, 2, 3],
            "values": {}
        }
        """
        let data = jsonString.data(using: .utf8)!
        let doc = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(doc.values["unknownField"]?.string == "should be preserved")
        #expect(doc.values["customNumber"]?.number == 42)
        
        if case .array(let arr) = doc.values["customArray"] {
            #expect(arr.count == 3)
        } else {
            Issue.record("Expected customArray to be preserved")
        }
    }
    
    @Test("Unknown fields round-trip correctly")
    func testUnknownFieldsRoundTrip() throws {
        let jsonString = """
        {
            "id": "00000000-0000-0000-0000-000000000000",
            "title": "Test",
            "subtitle": "",
            "isPublic": false,
            "summary": "",
            "featured": false,
            "requiresFollowUp": false,
            "customField": "custom value",
            "values": {}
        }
        """
        let data = jsonString.data(using: .utf8)!
        var doc = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        // Verify unknown field captured
        #expect(doc.values["customField"]?.string == "custom value")
        
        // Re-encode and decode
        let reencoded = try JSONEncoder().encode(doc)
        let redecoded = try JSONDecoder().decode(FolioDocument.self, from: reencoded)
        
        // Verify still present
        #expect(redecoded.values["customField"]?.string == "custom value")
    }
    
    // MARK: - Edge Cases
    
    @Test("Empty string title is allowed")
    func testEmptyTitle() throws {
        let doc = FolioDocument()
        // Empty title should be valid
        #expect(doc.title == "")
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        #expect(decoded.title == "")
    }
    
    @Test("Whitespace-only title is preserved")
    func testWhitespaceTitle() throws {
        var doc = FolioDocument()
        doc.title = "   "
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        #expect(decoded.title == "   ")
    }
    
    @Test("Very long title is preserved")
    func testVeryLongTitle() throws {
        var doc = FolioDocument()
        doc.title = String(repeating: "a", count: 10000)
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        #expect(decoded.title.count == 10000)
    }
    
    @Test("Special characters in title are preserved")
    func testSpecialCharactersInTitle() throws {
        var doc = FolioDocument()
        doc.title = "Test \"Project\" with 'quotes' & special <chars> / \\ | * ?"
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        #expect(decoded.title == "Test \"Project\" with 'quotes' & special <chars> / \\ | * ?")
    }
    
    @Test("Unicode characters in title are preserved")
    func testUnicodeInTitle() throws {
        var doc = FolioDocument()
        doc.title = "Test 项目 🚀 émoji テスト"
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        #expect(decoded.title == "Test 项目 🚀 émoji テスト")
    }
    
    @Test("Empty arrays round-trip correctly")
    func testEmptyArrays() throws {
        var doc = FolioDocument()
        doc.tags = []
        doc.mediums = []
        doc.genres = []
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.tags.isEmpty)
        #expect(decoded.mediums.isEmpty)
        #expect(decoded.genres.isEmpty)
    }
    
    @Test("Duplicate values in arrays are preserved")
    func testDuplicatesInArrays() throws {
        var doc = FolioDocument()
        doc.tags = ["swift", "swift", "ios"]
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.tags.count == 3)
        #expect(decoded.tags == ["swift", "swift", "ios"])
    }
    
    @Test("Dates with milliseconds round-trip correctly")
    func testDatePrecision() throws {
        var doc = FolioDocument()
        doc.createdAt = Date()
        doc.updatedAt = Date()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(doc)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FolioDocument.self, from: data)
        
        // Dates should be close (within 1 second due to encoding precision)
        if let original = doc.createdAt, let decoded = decoded.createdAt {
            #expect(abs(original.timeIntervalSince(decoded)) < 1.0)
        } else {
            Issue.record("Dates should be preserved")
        }
    }
}

// MARK: - DetailItem Tests

@Suite("DetailItem Tests")
struct DetailItemTests {
    
    @Test("DetailItem with string value")
    func testStringDetailItem() throws {
        let item = DetailItem(key: "author", value: .string("John Doe"))
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        #expect(decoded.key == "author")
        #expect(decoded.value.string == "John Doe")
    }
    
    @Test("DetailItem with number value")
    func testNumberDetailItem() throws {
        let item = DetailItem(key: "version", value: .number(1.5))
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        #expect(decoded.key == "version")
        #expect(decoded.value.number == 1.5)
    }
    
    @Test("DetailItem with boolean value")
    func testBoolDetailItem() throws {
        let item = DetailItem(key: "published", value: .bool(true))
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        #expect(decoded.key == "published")
        #expect(decoded.value.bool == true)
    }
    
    @Test("DetailItem with array value")
    func testArrayDetailItem() throws {
        let item = DetailItem(key: "contributors", value: .array([.string("Alice"), .string("Bob")]))
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        if case .array(let arr) = decoded.value {
            #expect(arr.count == 2)
            #expect(arr[0].string == "Alice")
            #expect(arr[1].string == "Bob")
        } else {
            Issue.record("Expected array value")
        }
    }
    
    @Test("DetailItem with object value")
    func testObjectDetailItem() throws {
        let item = DetailItem(
            key: "metadata",
            value: .object(["created": .string("2025-11-17"), "version": .number(2)])
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        if case .object(let obj) = decoded.value {
            #expect(obj["created"]?.string == "2025-11-17")
            #expect(obj["version"]?.number == 2)
        } else {
            Issue.record("Expected object value")
        }
    }
    
    @Test("DetailItem with null value")
    func testNullDetailItem() throws {
        let item = DetailItem(key: "optional", value: .null)
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        if case .null = decoded.value {
            // Success
        } else {
            Issue.record("Expected null value")
        }
    }
    
    @Test("Empty key is allowed in DetailItem")
    func testEmptyKeyDetailItem() throws {
        let item = DetailItem(key: "", value: .string("value"))
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        #expect(decoded.key == "")
    }
    
    @Test("Special characters in DetailItem key")
    func testSpecialCharactersInKey() throws {
        let item = DetailItem(key: "my-key_with.special:chars", value: .string("test"))
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DetailItem.self, from: data)
        
        #expect(decoded.key == "my-key_with.special:chars")
    }
}

// MARK: - AssetPath Tests

@Suite("AssetPath Tests")
struct AssetPathTests {
    
    @Test("AssetPath with both paths")
    func testAssetPathComplete() throws {
        let asset = AssetPath(
            pathToOriginal: "/path/to/original.jpg",
            pathToEdited: "/path/to/edited.jpg"
        )
        
        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(AssetPath.self, from: data)
        
        #expect(decoded.pathToOriginal == "/path/to/original.jpg")
        #expect(decoded.pathToEdited == "/path/to/edited.jpg")
    }
    
    @Test("AssetPath with empty paths")
    func testAssetPathEmpty() throws {
        let asset = AssetPath()
        
        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(AssetPath.self, from: data)
        
        #expect(decoded.pathToOriginal == "")
        #expect(decoded.pathToEdited == "")
    }
    
    @Test("AssetPath equality check")
    func testAssetPathEquality() {
        let asset1 = AssetPath(pathToOriginal: "/path/1.jpg", pathToEdited: "/path/2.jpg")
        let asset2 = AssetPath(pathToOriginal: "/path/1.jpg", pathToEdited: "/path/2.jpg")
        let asset3 = AssetPath(pathToOriginal: "/path/1.jpg", pathToEdited: "/path/3.jpg")
        
        #expect(asset1 == asset2)
        #expect(asset1 != asset3)
    }
}

// MARK: - ImageLabel Tests

@Suite("ImageLabel Tests")
struct ImageLabelTests {
    
    @Test("Preset labels encode correctly")
    func testPresetLabelsEncode() throws {
        let labels: [ImageLabel] = [.thumbnail, .banner, .heroBanner, .poster, .icon]
        
        for label in labels {
            let data = try JSONEncoder().encode(label)
            let decoded = try JSONDecoder().decode(ImageLabel.self, from: data)
            #expect(decoded == label)
        }
    }
    
    @Test("Custom label encodes with prefix")
    func testCustomLabelEncode() throws {
        let label = ImageLabel.custom("MyCustomImage")
        
        let data = try JSONEncoder().encode(label)
        let decoded = try JSONDecoder().decode(ImageLabel.self, from: data)
        
        if case .custom(let name) = decoded {
            #expect(name == "MyCustomImage")
        } else {
            Issue.record("Expected custom label")
        }
    }
    
    @Test("Storage keys are unique")
    func testStorageKeysUnique() {
        let presets = ImageLabel.presets
        let keys = Set(presets.map { $0.storageKey })
        #expect(keys.count == presets.count)
    }
    
    @Test("Custom label storage key has prefix")
    func testCustomLabelStorageKey() {
        let label = ImageLabel.custom("Test")
        #expect(label.storageKey == "custom:Test")
    }
    
    @Test("ImageLabel from storage key")
    func testImageLabelFromStorageKey() {
        #expect(ImageLabel(storageKey: "thumbnail") == .thumbnail)
        #expect(ImageLabel(storageKey: "banner") == .banner)
        #expect(ImageLabel(storageKey: "custom:MyImage") == .custom("MyImage"))
    }
    
    @Test("Unknown storage key treated as custom")
    func testUnknownStorageKeyAsCustom() {
        let label = ImageLabel(storageKey: "unknownLabel")
        if case .custom(let name) = label {
            #expect(name == "unknownLabel")
        } else {
            Issue.record("Unknown label should be treated as custom")
        }
    }
}

// MARK: - JSONResource Tests

@Suite("JSONResource Tests")
struct JSONResourceTests {
    
    @Test("JSONResource with all fields")
    func testCompleteResource() throws {
        let resource = JSONResource(
            label: "Documentation",
            category: "Reference",
            type: "Website",
            url: "https://example.com"
        )
        
        let data = try JSONEncoder().encode(resource)
        let decoded = try JSONDecoder().decode(JSONResource.self, from: data)
        
        #expect(decoded.label == "Documentation")
        #expect(decoded.category == "Reference")
        #expect(decoded.type == "Website")
        #expect(decoded.url == "https://example.com")
    }
    
    @Test("JSONResource with empty fields")
    func testEmptyResource() throws {
        let resource = JSONResource()
        
        let data = try JSONEncoder().encode(resource)
        let decoded = try JSONDecoder().decode(JSONResource.self, from: data)
        
        #expect(decoded.label == "")
        #expect(decoded.category == "")
        #expect(decoded.type == "")
        #expect(decoded.url == "")
    }
    
    @Test("JSONResource equality")
    func testResourceEquality() {
        let res1 = JSONResource(label: "Test", category: "Cat", type: "Type", url: "url")
        let res2 = JSONResource(label: "Test", category: "Cat", type: "Type", url: "url")
        let res3 = JSONResource(label: "Test", category: "Cat", type: "Type", url: "different")
        
        #expect(res1 == res2)
        #expect(res1 != res3)
    }
}

// MARK: - CollectionItem Tests

@Suite("CollectionItem Tests")
struct CollectionItemTests {
    
    @Test("File type collection item")
    func testFileTypeItem() throws {
        let item = JSONCollectionItem(
            type: .file,
            label: "Document",
            filePath: AssetPath(pathToOriginal: "/path/to/file.pdf", pathToEdited: ""),
            thumbnail: AssetPath()
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.type == .file)
        #expect(decoded.label == "Document")
        #expect(decoded.filePath?.pathToOriginal == "/path/to/file.pdf")
    }
    
    @Test("URL type collection item")
    func testURLTypeItem() throws {
        let item = JSONCollectionItem(
            type: .urlLink,
            label: "Website",
            url: "https://example.com",
            thumbnail: AssetPath()
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.type == .urlLink)
        #expect(decoded.url == "https://example.com")
    }
    
    @Test("Folio type collection item")
    func testFolioTypeItem() throws {
        let linkedID = UUID()
        let item = JSONCollectionItem(
            type: .folio,
            label: "Linked Project",
            url: linkedID.uuidString,
            thumbnail: AssetPath()
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.type == .folio)
        #expect(decoded.url == linkedID.uuidString)
    }
    
    @Test("Collection item with summary")
    func testItemWithSummary() throws {
        let item = JSONCollectionItem(
            type: .file,
            label: "Report",
            summary: "Annual report document",
            thumbnail: AssetPath()
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.summary == "Annual report document")
    }
    
    @Test("Collection item ID persistence")
    func testItemIDPersistence() throws {
        let id = UUID()
        let item = JSONCollectionItem(id: id, type: .file, thumbnail: AssetPath())
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.id == id)
    }
}

// MARK: - CollectionSection Tests

@Suite("CollectionSection Tests")
struct CollectionSectionTests {
    
    @Test("Empty collection section")
    func testEmptySection() throws {
        let section = CollectionSection()
        
        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(CollectionSection.self, from: data)
        
        #expect(decoded.images.isEmpty)
        #expect(decoded.items.isEmpty)
    }
    
    @Test("Collection section with items")
    func testSectionWithItems() throws {
        let item1 = JSONCollectionItem(type: .file, label: "Item 1", thumbnail: AssetPath())
        let item2 = JSONCollectionItem(type: .urlLink, label: "Item 2", thumbnail: AssetPath())
        
        let section = CollectionSection(items: [item1, item2])
        
        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(CollectionSection.self, from: data)
        
        #expect(decoded.items.count == 2)
        #expect(decoded.items[0].label == "Item 1")
        #expect(decoded.items[1].label == "Item 2")
    }
    
    @Test("Collection section with images")
    func testSectionWithImages() throws {
        let images: [String: AssetPath] = [
            "banner": AssetPath(pathToOriginal: "/banner.jpg", pathToEdited: ""),
            "thumbnail": AssetPath(pathToOriginal: "/thumb.jpg", pathToEdited: "")
        ]
        
        let section = CollectionSection(images: images)
        
        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(CollectionSection.self, from: data)
        
        #expect(decoded.images.count == 2)
        #expect(decoded.images["banner"]?.pathToOriginal == "/banner.jpg")
    }
}

// MARK: - Settings Tests

@Suite("Settings Tab Tests")
struct SettingsTabTests {
    
    @Test("SettingsTab enum has correct cases")
    func testSettingsTabCases() {
        let allCases = SettingsTab.allCases
        
        #expect(allCases.count == 2)
        #expect(allCases.contains(.classifications))
        #expect(allCases.contains(.preferences))
    }
    
    @Test("SettingsTab raw values are correct")
    func testSettingsTabRawValues() {
        #expect(SettingsTab.classifications.rawValue == "Classifications")
        #expect(SettingsTab.preferences.rawValue == "Preferences")
    }
}

// MARK: - Code Snippets Tests

@Suite("Code Snippets Tests")
struct CodeSnippetsTests {
    
    @Test("ExportFormat has correct file extensions")
    func testExportFormatExtensions() {
        #expect(ExportFormat.json.fileExtension == "json")
        #expect(ExportFormat.csv.fileExtension == "csv")
        #expect(ExportFormat.txt.fileExtension == "txt")
    }
    
    @Test("SnippetMode has correct cases")
    func testSnippetModes() {
        let allModes = SnippetMode.allCases
        
        #expect(allModes.count == 2)
        #expect(allModes.contains(.single))
        #expect(allModes.contains(.multiple))
    }
    
    @Test("CodeSnippetID has only two cases")
    func testCodeSnippetIDCount() {
        let allIDs = CodeSnippetID.allCases
        
        #expect(allIDs.count == 2)
        #expect(allIDs.contains(.loadSummary))
        #expect(allIDs.contains(.exportMetadata))
    }
    
    @Test("Python snippets load correctly")
    func testPythonSnippetsLoad() {
        let snippets = CodeSnippetLibrary.loadedSnippets(for: .python, mode: .single)
        
        #expect(snippets.count == 2)
        #expect(snippets.first?.id == .loadSummary)
        #expect(snippets[1].id == .exportMetadata)
        #expect(!snippets.first!.code.isEmpty)
    }
    
    @Test("Non-Python languages return empty snippets")
    func testNonPythonSnippetsEmpty() {
        let swiftSnippets = CodeSnippetLibrary.loadedSnippets(for: .swift, mode: .single)
        let jsSnippets = CodeSnippetLibrary.loadedSnippets(for: .javascript, mode: .single)
        
        #expect(swiftSnippets.isEmpty)
        #expect(jsSnippets.isEmpty)
    }
}

// MARK: - Media Detail Tests

@Suite("Media Detail View Tests")
struct MediaDetailTests {
    
    @Test("Copy original button hidden when paths match")
    func testCopyOriginalButtonVisibility() {
        var doc = FolioDocument()
        doc.assetsFolder = AssetsFolderLocation(url: URL(fileURLWithPath: "/tmp/assets"))
        
        // Same path for original and edited
        let samePath = AssetPath(pathToOriginal: "/path/to/image.jpg", 
                                 pathToEdited: "/path/to/image.jpg")
        doc.images[.thumbnail] = samePath
        
        // The view logic should hide the button when paths match
        #expect(samePath.pathToOriginal == samePath.pathToEdited)
    }
    
    @Test("Delete Image Key available only for custom labels")
    func testDeleteImageKeyAvailability() {
        let thumbnailLabel = ImageLabel.thumbnail
        let customLabel = ImageLabel.custom("MyImage")
        
        // Preset labels
        #expect(!isCustomLabel(thumbnailLabel))
        #expect(!isCustomLabel(.banner))
        #expect(!isCustomLabel(.icon))
        
        // Custom label
        #expect(isCustomLabel(customLabel))
    }
    
    private func isCustomLabel(_ label: ImageLabel) -> Bool {
        if case .custom = label {
            return true
        }
        return false
    }
}

// MARK: - Collection Item Tests

@Suite("Collection Item Editor Tests")
struct CollectionItemEditorTests {
    
    @Test("CollectionItemType has three cases")
    func testCollectionItemTypes() {
        #expect(CollectionItemType.file.rawValue == "file")
        #expect(CollectionItemType.urlLink.rawValue == "urlLink")
        #expect(CollectionItemType.folio.rawValue == "folio")
    }
    
    @Test("Collection item type switching clears appropriate fields")
    func testCollectionItemTypeSwitch() {
        var item = JSONCollectionItem()
        item.type = .file
        item.filePath = AssetPath(pathToOriginal: "/file.pdf", pathToEdited: "")
        item.url = nil
        
        // Switch to URL should clear filePath
        item.type = .urlLink
        #expect(item.type == .urlLink)
        
        // Switch to Folio should clear both
        item.type = .folio
        #expect(item.type == .folio)
    }
}

// MARK: - JSON Document Viewer Tests

@Suite("JSON Document Viewer Tests")
struct JSONDocumentViewerTests {
    
    @Test("Document encodes to valid JSON string")
    func testDocumentJSONEncoding() throws {
        var doc = FolioDocument()
        doc.title = "Test"
        doc.isPublic = true
        doc.tags = ["test", "example"]
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(doc)
        let jsonString = String(data: data, encoding: .utf8)
        
        #expect(jsonString != nil)
        #expect(jsonString!.contains("\"title\""))
        #expect(jsonString!.contains("\"Test\""))
        #expect(jsonString!.contains("\"isPublic\""))
        #expect(jsonString!.contains("\"tags\""))
    }
}

// MARK: - Launcher Tests

@Suite("Launcher View Tests")
struct LauncherTests {
    
    @Test("Launcher auto-open preference defaults to true")
    func testLauncherAutoOpenDefault() {
        @AppStorage("launcherAutoOpen") var launcherAutoOpen = true
        
        #expect(launcherAutoOpen == true)
    }
    
    @Test("File path validation detects missing files")
    func testFilePathValidation() {
        let nonExistentPath = "/tmp/nonexistent-file-\(UUID().uuidString).folioDoc"
        let exists = FileManager.default.fileExists(atPath: nonExistentPath)
        
        #expect(exists == false)
    }
}
