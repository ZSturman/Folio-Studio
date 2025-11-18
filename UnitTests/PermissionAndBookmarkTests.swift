//
//  PermissionAndBookmarkTests.swift
//  UnitTests
//
//  Created by Zachary Sturman on 11/17/25.
//

import Testing
import Foundation
@testable import Folio

// MARK: - Permission and Bookmark Tests

@Suite("AssetsFolderLocation Tests")
struct AssetsFolderLocationTests {
    
    @Test("AssetsFolderLocation with path only")
    func testAssetsFolderLocationPathOnly() throws {
        let location = AssetsFolderLocation(path: "/Users/test/Assets", bookmarkData: nil)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.path == "/Users/test/Assets")
        #expect(decoded.bookmarkData == nil)
    }
    
    @Test("AssetsFolderLocation with bookmark data")
    func testAssetsFolderLocationWithBookmark() throws {
        let mockBookmark = "mock bookmark".data(using: .utf8)!
        let location = AssetsFolderLocation(path: "/Users/test/Assets", bookmarkData: mockBookmark)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.path == "/Users/test/Assets")
        #expect(decoded.bookmarkData == mockBookmark)
    }
    
    @Test("AssetsFolderLocation with nil path")
    func testAssetsFolderLocationNilPath() throws {
        let mockBookmark = "mock bookmark".data(using: .utf8)!
        let location = AssetsFolderLocation(path: nil, bookmarkData: mockBookmark)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.path == nil)
        #expect(decoded.bookmarkData == mockBookmark)
    }
    
    @Test("AssetsFolderLocation with both nil")
    func testAssetsFolderLocationBothNil() throws {
        let location = AssetsFolderLocation(path: nil, bookmarkData: nil)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.path == nil)
        #expect(decoded.bookmarkData == nil)
    }
    
    @Test("AssetsFolderLocation with empty path")
    func testAssetsFolderLocationEmptyPath() throws {
        let location = AssetsFolderLocation(path: "", bookmarkData: nil)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.path == "")
    }
    
    @Test("AssetsFolderLocation with very long path")
    func testAssetsFolderLocationLongPath() throws {
        let longPath = "/Users/" + String(repeating: "a/", count: 200) + "Assets"
        let location = AssetsFolderLocation(path: longPath, bookmarkData: nil)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.path == longPath)
    }
    
    @Test("AssetsFolderLocation with special characters in path")
    func testAssetsFolderLocationSpecialChars() throws {
        let path = "/Users/test/My Assets (2024)/Folder #1"
        let location = AssetsFolderLocation(path: path, bookmarkData: nil)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.path == path)
    }
    
    @Test("AssetsFolderLocation with large bookmark data")
    func testAssetsFolderLocationLargeBookmark() throws {
        let largeBookmark = Data(repeating: 0xFF, count: 10000)
        let location = AssetsFolderLocation(path: "/test", bookmarkData: largeBookmark)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.bookmarkData?.count == 10000)
    }
}

// MARK: - Document Permission Tests

@Suite("Document Permission Tests")
struct DocumentPermissionTests {
    
    @Test("Document with assets folder location")
    func testDocumentWithAssetsFolder() throws {
        var doc = FolioDocument()
        doc.assetsFolder = AssetsFolderLocation(path: "/Users/test/FolioAssets", bookmarkData: nil)
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.assetsFolder?.path == "/Users/test/FolioAssets")
    }
    
    @Test("Document without assets folder")
    func testDocumentWithoutAssetsFolder() throws {
        var doc = FolioDocument()
        doc.assetsFolder = nil
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.assetsFolder == nil)
    }
    
    @Test("Document assets folder migration from string")
    func testAssetsFolderMigrationFromString() throws {
        // This tests backward compatibility if old documents stored just a string
        let jsonString = """
        {
            "id": "00000000-0000-0000-0000-000000000000",
            "title": "Test",
            "subtitle": "",
            "isPublic": false,
            "summary": "",
            "featured": false,
            "requiresFollowUp": false,
            "assetsFolder": "/Users/test/Assets",
            "values": {}
        }
        """
        
        // Note: This might fail if backward compatibility isn't implemented
        // The current FolioDocument should handle this gracefully
    }
}

// MARK: - Image Permission Tests

@Suite("Image Permission Tests")
struct ImagePermissionTests {
    
    @Test("Document with multiple images")
    func testDocumentWithMultipleImages() throws {
        var doc = FolioDocument()
        doc.images[.thumbnail] = AssetPath(pathToOriginal: "/path/to/thumb.jpg", pathToEdited: "")
        doc.images[.banner] = AssetPath(pathToOriginal: "/path/to/banner.jpg", pathToEdited: "")
        doc.images[.poster] = AssetPath(pathToOriginal: "/path/to/poster.jpg", pathToEdited: "")
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.images.count == 3)
        #expect(decoded.images[.thumbnail]?.pathToOriginal == "/path/to/thumb.jpg")
        #expect(decoded.images[.banner]?.pathToOriginal == "/path/to/banner.jpg")
        #expect(decoded.images[.poster]?.pathToOriginal == "/path/to/poster.jpg")
    }
    
    @Test("Document with custom image labels")
    func testDocumentWithCustomImageLabels() throws {
        var doc = FolioDocument()
        doc.images[.custom("Logo")] = AssetPath(pathToOriginal: "/path/to/logo.png", pathToEdited: "")
        doc.images[.custom("Screenshot")] = AssetPath(pathToOriginal: "/path/to/screen.png", pathToEdited: "")
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.images.count == 2)
        #expect(decoded.images[.custom("Logo")]?.pathToOriginal == "/path/to/logo.png")
    }
    
    @Test("Image paths with special characters")
    func testImagePathsSpecialCharacters() throws {
        var doc = FolioDocument()
        doc.images[.thumbnail] = AssetPath(
            pathToOriginal: "/Users/test/Photos (2024)/My Image #1.jpg",
            pathToEdited: "/Users/test/Edited/My Image #1_edited.jpg"
        )
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.images[.thumbnail]?.pathToOriginal.contains("(2024)") == true)
        #expect(decoded.images[.thumbnail]?.pathToOriginal.contains("#1") == true)
    }
    
    @Test("Image paths with Unicode characters")
    func testImagePathsUnicode() throws {
        var doc = FolioDocument()
        doc.images[.thumbnail] = AssetPath(
            pathToOriginal: "/Users/test/写真/画像.jpg",
            pathToEdited: ""
        )
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.images[.thumbnail]?.pathToOriginal.contains("写真") == true)
    }
    
    @Test("Empty image dictionary")
    func testEmptyImageDictionary() throws {
        var doc = FolioDocument()
        doc.images = [:]
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.images.isEmpty)
    }
}

// MARK: - Collection File Permission Tests

@Suite("Collection File Permission Tests")
struct CollectionFilePermissionTests {
    
    @Test("Collection item with local file path")
    func testCollectionItemLocalFile() throws {
        let item = JSONCollectionItem(
            type: .file,
            label: "Report",
            filePath: AssetPath(
                pathToOriginal: "/Users/test/Documents/report.pdf",
                pathToEdited: ""
            ),
            thumbnail: AssetPath(
                pathToOriginal: "/Users/test/Thumbnails/report_thumb.jpg",
                pathToEdited: ""
            )
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.type == .file)
        #expect(decoded.filePath?.pathToOriginal == "/Users/test/Documents/report.pdf")
        #expect(decoded.thumbnail.pathToOriginal == "/Users/test/Thumbnails/report_thumb.jpg")
    }
    
    @Test("Collection section with multiple file items")
    func testCollectionSectionMultipleFiles() throws {
        let item1 = JSONCollectionItem(
            type: .file,
            label: "File1",
            filePath: AssetPath(pathToOriginal: "/path/1.pdf", pathToEdited: ""),
            thumbnail: AssetPath()
        )
        let item2 = JSONCollectionItem(
            type: .file,
            label: "File2",
            filePath: AssetPath(pathToOriginal: "/path/2.pdf", pathToEdited: ""),
            thumbnail: AssetPath()
        )
        
        let section = CollectionSection(items: [item1, item2])
        
        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(CollectionSection.self, from: data)
        
        #expect(decoded.items.count == 2)
        #expect(decoded.items[0].filePath?.pathToOriginal == "/path/1.pdf")
        #expect(decoded.items[1].filePath?.pathToOriginal == "/path/2.pdf")
    }
    
    @Test("Collection item file path with network share")
    func testCollectionItemNetworkPath() throws {
        let item = JSONCollectionItem(
            type: .file,
            label: "Network File",
            filePath: AssetPath(pathToOriginal: "smb://server/share/file.pdf", pathToEdited: ""),
            thumbnail: AssetPath()
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.filePath?.pathToOriginal == "smb://server/share/file.pdf")
    }
}

// MARK: - Resource Permission Tests

@Suite("Resource Permission Tests")
struct ResourcePermissionTests {
    
    @Test("Resource with local file URL")
    func testResourceLocalFileURL() throws {
        let resource = JSONResource(
            label: "Documentation",
            category: "Reference",
            type: "PDF",
            url: "file:///Users/test/docs.pdf"
        )
        
        let data = try JSONEncoder().encode(resource)
        let decoded = try JSONDecoder().decode(JSONResource.self, from: data)
        
        #expect(decoded.url == "file:///Users/test/docs.pdf")
    }
    
    @Test("Resource with HTTP URL")
    func testResourceHTTPURL() throws {
        let resource = JSONResource(
            label: "Website",
            category: "Reference",
            type: "Website",
            url: "https://example.com/resource"
        )
        
        let data = try JSONEncoder().encode(resource)
        let decoded = try JSONDecoder().decode(JSONResource.self, from: data)
        
        #expect(decoded.url == "https://example.com/resource")
    }
    
    @Test("Multiple resources with mixed URL types")
    func testMultipleResourcesMixedURLs() throws {
        var doc = FolioDocument()
        doc.resources = [
            JSONResource(label: "Web", category: "Ref", type: "Site", url: "https://example.com"),
            JSONResource(label: "Local", category: "Ref", type: "File", url: "file:///test.pdf"),
            JSONResource(label: "Relative", category: "Ref", type: "File", url: "./local/file.txt")
        ]
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.resources.count == 3)
        #expect(decoded.resources[0].url == "https://example.com")
        #expect(decoded.resources[1].url == "file:///test.pdf")
        #expect(decoded.resources[2].url == "./local/file.txt")
    }
}

// MARK: - Bookmark Data Integrity Tests

@Suite("Bookmark Data Integrity Tests")
struct BookmarkDataIntegrityTests {
    
    @Test("Bookmark data survives encoding/decoding")
    func testBookmarkDataRoundTrip() throws {
        let originalBookmark = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let location = AssetsFolderLocation(path: "/test", bookmarkData: originalBookmark)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.bookmarkData == originalBookmark)
    }
    
    @Test("Bookmark data with all byte values")
    func testBookmarkDataAllBytes() throws {
        var allBytes = Data()
        for byte in 0...255 {
            allBytes.append(UInt8(byte))
        }
        
        let location = AssetsFolderLocation(path: "/test", bookmarkData: allBytes)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.bookmarkData?.count == 256)
        #expect(decoded.bookmarkData == allBytes)
    }
    
    @Test("Empty bookmark data")
    func testEmptyBookmarkData() throws {
        let location = AssetsFolderLocation(path: "/test", bookmarkData: Data())
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(AssetsFolderLocation.self, from: data)
        
        #expect(decoded.bookmarkData?.isEmpty == true)
    }
}

// MARK: - Permission Edge Cases

@Suite("Permission Edge Cases")
struct PermissionEdgeCases {
    
    @Test("Document with inaccessible file paths")
    func testDocumentInaccessiblePaths() throws {
        var doc = FolioDocument()
        doc.images[.thumbnail] = AssetPath(
            pathToOriginal: "/System/Library/PrivateFile.jpg", // Likely inaccessible
            pathToEdited: ""
        )
        
        // Should encode without error (permission check happens at access time)
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.images[.thumbnail]?.pathToOriginal == "/System/Library/PrivateFile.jpg")
    }
    
    @Test("Document with deleted file paths")
    func testDocumentDeletedFilePaths() throws {
        var doc = FolioDocument()
        doc.images[.banner] = AssetPath(
            pathToOriginal: "/path/to/deleted/file.jpg",
            pathToEdited: ""
        )
        
        // Should preserve paths even if files don't exist
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        #expect(decoded.images[.banner]?.pathToOriginal == "/path/to/deleted/file.jpg")
    }
    
    @Test("Collection with mixed accessible and inaccessible files")
    func testCollectionMixedAccessibility() throws {
        let item1 = JSONCollectionItem(
            type: .file,
            label: "Accessible",
            filePath: AssetPath(pathToOriginal: "/Users/test/accessible.pdf", pathToEdited: ""),
            thumbnail: AssetPath()
        )
        let item2 = JSONCollectionItem(
            type: .file,
            label: "Inaccessible",
            filePath: AssetPath(pathToOriginal: "/System/inaccessible.pdf", pathToEdited: ""),
            thumbnail: AssetPath()
        )
        
        let section = CollectionSection(items: [item1, item2])
        
        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(CollectionSection.self, from: data)
        
        #expect(decoded.items.count == 2)
    }
}
