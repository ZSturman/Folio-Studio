//
//  AssetPathThumbnailTests.swift
//  UnitTests
//
//  Created by GitHub Copilot on 12/2/25.
//

import Testing
import Foundation
import AppKit
@testable import Folio

// MARK: - AssetPath Thumbnail Aspect Ratio Tests

@Suite("AssetPath Thumbnail Aspect Ratio Tests")
struct AssetPathThumbnailAspectRatioTests {
    
    @Test("Thumbnail has 4:3 aspect ratio")
    func testThumbnailAspectRatio() {
        let thumbnail = ImageLabel.thumbnail
        let aspect = thumbnail.targetAspect(using: nil)
        
        #expect(aspect.width == 4)
        #expect(aspect.height == 3)
    }
    
    @Test("Thumbnail maps to standard AspectRatio")
    func testThumbnailAspectRatioMapping() {
        let thumbnail = ImageLabel.thumbnail
        let aspectRatio = thumbnail.toAspectRatio()
        
        #expect(aspectRatio == .standard)  // 4:3
    }
    
    @Test("Icon remains square")
    func testIconAspectRatio() {
        let icon = ImageLabel.icon
        let aspect = icon.targetAspect(using: nil)
        
        #expect(aspect.width == 1)
        #expect(aspect.height == 1)
    }
    
    @Test("Banner is 4:1 aspect ratio")
    func testBannerAspectRatio() {
        let banner = ImageLabel.banner
        let aspect = banner.targetAspect(using: nil)
        
        #expect(aspect.width == 4)
        #expect(aspect.height == 1)
    }
    
    @Test("Hero banner is 16:9 aspect ratio")
    func testHeroBannerAspectRatio() {
        let heroBanner = ImageLabel.heroBanner
        let aspect = heroBanner.targetAspect(using: nil)
        
        #expect(aspect.width == 16)
        #expect(aspect.height == 9)
    }
    
    @Test("Poster is 2:3 aspect ratio")
    func testPosterAspectRatio() {
        let poster = ImageLabel.poster
        let aspect = poster.targetAspect(using: nil)
        
        #expect(aspect.width == 2)
        #expect(aspect.height == 3)
    }
    
    @Test("Custom label uses source image aspect")
    func testCustomLabelAspect() {
        // Create a mock NSImage with specific size
        let image = NSImage(size: NSSize(width: 1920, height: 1080))
        
        let custom = ImageLabel.custom("MyCustomImage")
        let aspect = custom.targetAspect(using: image)
        
        #expect(aspect.width == 1920)
        #expect(aspect.height == 1080)
    }
    
    @Test("Custom label with no source defaults to square")
    func testCustomLabelNoSource() {
        let custom = ImageLabel.custom("NoSource")
        let aspect = custom.targetAspect(using: nil)
        
        #expect(aspect.width == 1)
        #expect(aspect.height == 1)
    }
    
    @Test("Custom label with zero-size source defaults to square")
    func testCustomLabelZeroSizeSource() {
        let image = NSImage(size: NSSize(width: 0, height: 0))
        
        let custom = ImageLabel.custom("ZeroSize")
        let aspect = custom.targetAspect(using: image)
        
        #expect(aspect.width == 1)
        #expect(aspect.height == 1)
    }
}

// MARK: - Image Label Preferred Max Pixels Tests

@Suite("Image Label Preferred Max Pixels Tests")
struct ImageLabelPreferredMaxPixelsTests {
    
    @Test("Banner has correct max pixels")
    func testBannerMaxPixels() {
        let banner = ImageLabel.banner
        let maxPixels = banner.preferredMaxPixels
        
        #expect(maxPixels?.width == 2560)
        #expect(maxPixels?.height == 640)
    }
    
    @Test("Hero banner has correct max pixels")
    func testHeroBannerMaxPixels() {
        let heroBanner = ImageLabel.heroBanner
        let maxPixels = heroBanner.preferredMaxPixels
        
        #expect(maxPixels?.width == 2560)
        #expect(maxPixels?.height == 1440)
    }
    
    @Test("Thumbnail has correct max pixels")
    func testThumbnailMaxPixels() {
        let thumbnail = ImageLabel.thumbnail
        let maxPixels = thumbnail.preferredMaxPixels
        
        #expect(maxPixels?.width == 1024)
        #expect(maxPixels?.height == 1024)
    }
    
    @Test("Icon has correct max pixels")
    func testIconMaxPixels() {
        let icon = ImageLabel.icon
        let maxPixels = icon.preferredMaxPixels
        
        #expect(maxPixels?.width == 1024)
        #expect(maxPixels?.height == 1024)
    }
    
    @Test("Poster has correct max pixels")
    func testPosterMaxPixels() {
        let poster = ImageLabel.poster
        let maxPixels = poster.preferredMaxPixels
        
        #expect(maxPixels?.width == 2000)
        #expect(maxPixels?.height == 3000)
    }
    
    @Test("Custom label has no max pixels")
    func testCustomLabelNoMaxPixels() {
        let custom = ImageLabel.custom("NoLimit")
        let maxPixels = custom.preferredMaxPixels
        
        #expect(maxPixels == nil)
    }
}

// MARK: - AssetPath Migration Tests

@Suite("AssetPath Migration Tests")
struct AssetPathMigrationTests {
    
    @Test("New AssetPath with path only")
    func testNewAssetPathFormat() throws {
        let asset = AssetPath(id: UUID(), path: "thumbnails/image.png")
        
        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(AssetPath.self, from: data)
        
        #expect(decoded.path == "thumbnails/image.png")
        #expect(decoded.pathToOriginal == nil)
        #expect(decoded.pathToEdited == nil)
    }
    
    @Test("Legacy AssetPath with pathToOriginal and pathToEdited")
    func testLegacyAssetPathFormat() throws {
        let asset = AssetPath(
            pathToOriginal: "/path/to/original.png",
            pathToEdited: "/path/to/edited.png"
        )
        
        // In new format, path is set to edited path
        #expect(asset.path == "/path/to/edited.png")
        #expect(asset.pathToOriginal == "/path/to/original.png")
        #expect(asset.pathToEdited == "/path/to/edited.png")
    }
    
    @Test("AssetPath encoding excludes legacy fields")
    func testAssetPathEncodingExcludesLegacy() throws {
        var asset = AssetPath(id: UUID(), path: "new/path.png")
        // Manually set legacy fields (shouldn't be encoded)
        asset.pathToOriginal = "/legacy/original.png"
        asset.pathToEdited = "/legacy/edited.png"
        
        let data = try JSONEncoder().encode(asset)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Should only have 'path', not legacy fields
        #expect(jsonString.contains("\"path\""))
        #expect(!jsonString.contains("\"pathToOriginal\""))
        #expect(!jsonString.contains("\"pathToEdited\""))
    }
    
    @Test("Custom aspect ratio persists")
    func testCustomAspectRatioPersists() throws {
        let customAspect = CGSize(width: 21, height: 9)
        let asset = AssetPath(id: UUID(), path: "wide.png", customAspectRatio: customAspect)
        
        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(AssetPath.self, from: data)
        
        #expect(decoded.customAspectRatio?.width == 21)
        #expect(decoded.customAspectRatio?.height == 9)
    }
}



// MARK: - Thumbnail Integration Tests

@Suite("Thumbnail Integration Tests")
struct ThumbnailIntegrationTests {
    
    @Test("Document with 4:3 thumbnail aspect")
    func testDocumentThumbnailAspect() throws {
        var doc = FolioDocument()
        doc.images[.thumbnail] = AssetPath(id: UUID(), path: "thumb.png")
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        let thumbnailPath = decoded.images[.thumbnail]
        #expect(thumbnailPath?.path == "thumb.png")
    }
    
    @Test("Collection item with 4:3 thumbnail")
    func testCollectionItemThumbnail() throws {
        let item = JSONCollectionItem(
            label: "Test Item",
            thumbnail: AssetPath(id: UUID(), path: "items/item-thumb.png")
        )
        
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(JSONCollectionItem.self, from: data)
        
        #expect(decoded.thumbnail.path == "items/item-thumb.png")
    }
    
    @Test("Multiple image labels with different aspects")
    func testMultipleImageLabelsAspects() throws {
        var doc = FolioDocument()
        doc.images[.thumbnail] = AssetPath(id: UUID(), path: "thumb.png")
        doc.images[.banner] = AssetPath(id: UUID(), path: "banner.png")
        doc.images[.icon] = AssetPath(id: UUID(), path: "icon.png")
        
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FolioDocument.self, from: data)
        
        // Verify all images persist with correct paths
        #expect(decoded.images[.thumbnail]?.path == "thumb.png")
        #expect(decoded.images[.banner]?.path == "banner.png")
        #expect(decoded.images[.icon]?.path == "icon.png")
        
        // Verify aspects are correct
        #expect(ImageLabel.thumbnail.targetAspect(using: nil) == CGSize(width: 4, height: 3))
        #expect(ImageLabel.banner.targetAspect(using: nil) == CGSize(width: 4, height: 1))
        #expect(ImageLabel.icon.targetAspect(using: nil) == CGSize(width: 1, height: 1))
    }
}
