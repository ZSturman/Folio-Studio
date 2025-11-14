//  JSONImage.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import Foundation
import AppKit
import CoreGraphics

struct AssetsFolderLocation: Codable {
    var path: String?      // stored in JSON, portable
    var bookmarkData: Data? // security-scoped bookmark, mac-only
}


enum ImageLabel: Hashable, Codable, Sendable {
    case thumbnail
    case banner        // thin desktop banner
    case heroBanner    // taller hero banner
    case poster
    case icon
    case custom(String)

    // Storage key to persist in document.images (which remains [String: JSONImage])
    var storageKey: String {
        switch self {
        case .thumbnail:   return "thumbnail"
        case .banner:      return "banner"
        case .heroBanner:  return "heroBanner"
        case .poster:      return "poster"
        case .icon:        return "icon"
        case .custom(let name): return "custom:" + name
        }
    }

    // UI title
    var title: String {
        switch self {
        case .thumbnail:   return "Thumbnail"
        case .banner:      return "Banner"
        case .heroBanner:  return "Hero Banner"
        case .poster:      return "Poster"
        case .icon:        return "Icon"
        case .custom(let name): return name
        }
    }

    // Base for filenames when exporting/deriving edited names
    var filenameBase: String {
        switch self {
        case .thumbnail:   return "thumbnail"
        case .banner:      return "banner"
        case .heroBanner:  return "heroBanner"
        case .poster:      return "poster"
        case .icon:        return "icon"
        case .custom(let name): return name
        }
    }

    // Preset pixel targets. Custom has none.
    var preferredMaxPixels: CGSize? {
        switch self {
        case .banner:          // thin desktop banner
            return CGSize(width: 2560, height: 640)   // same width, less height
        case .heroBanner:      // hero banner (keeps old banner size)
            return CGSize(width: 2560, height: 1440)
        case .thumbnail, .icon:
            return CGSize(width: 1024, height: 1024)
        case .poster:
            return CGSize(width: 2000, height: 3000)
        case .custom:
            return nil
        }
    }
    

    // Aspect for rendering cover images. For custom derive from the source image.
    func targetAspect(using source: NSImage?) -> CGSize {
        switch self {
        case .thumbnail, .icon:
            return CGSize(width: 1, height: 1)
        case .banner:
            // thinner desktop banner
            return CGSize(width: 4, height: 1)
        case .heroBanner:
            // hero banner keeps previous banner aspect
            return CGSize(width: 16, height: 9)
        case .poster:
            return CGSize(width: 2, height: 3)
        case .custom:
            guard let s = source, s.size.width > 0, s.size.height > 0 else {
                return CGSize(width: 1, height: 1)
            }
            return CGSize(width: s.size.width, height: s.size.height)
        }
    }

    // List presets for UI loops
    static var presets: [ImageLabel] { [.thumbnail, .banner, .heroBanner, .poster, .icon] }

    // Convenience init for turning stored keys back into labels
    init(storageKey raw: String) {
        if raw.hasPrefix("custom:") {
            self = .custom(String(raw.dropFirst(7)))
            return
        }
        switch raw {
        case "thumbnail":   self = .thumbnail
        case "banner":      self = .banner
        case "heroBanner":  self = .heroBanner
        case "poster":      self = .poster
        case "icon":        self = .icon
        default:
            // Backward compat: treat unknowns as custom
            self = .custom(raw)
        }
    }

    // Codable as a single string. customs are prefixed.
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        if raw.hasPrefix("custom:") {
            self = .custom(String(raw.dropFirst(7)))
            return
        }
        switch raw {
        case "thumbnail":   self = .thumbnail
        case "banner":      self = .banner
        case "heroBanner":  self = .heroBanner
        case "poster":      self = .poster
        case "icon":        self = .icon
        default:
            // Backward compat: treat unknowns as custom
            self = .custom(raw)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(storageKey)
    }
}

struct AssetPath: Codable, Hashable, Sendable {
    var pathToOriginal: String
    var pathToEdited: String
    
    public init(pathToOriginal: String = "", pathToEdited: String = "") {
         self.pathToOriginal = pathToOriginal
         self.pathToEdited = pathToEdited
     }
}

// Convenience API
extension Dictionary where Key == String, Value == AssetPath {
    subscript(_ label: ImageLabel) -> AssetPath? {
        get { self[label.storageKey] }
        set { self[label.storageKey] = newValue }
    }
}
