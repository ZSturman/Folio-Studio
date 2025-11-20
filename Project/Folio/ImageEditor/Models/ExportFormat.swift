//
//  ExportFormat.swift
//  ImageEditor
//

import AppKit
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"
    case heic = "HEIC"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        case .heic: return "heic"
        }
    }
    
    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        case .heic: return .heic
        }
    }
    
    var bitmapFormat: NSBitmapImageRep.FileType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        case .heic:
            if #available(macOS 11.0, *) {
                return NSBitmapImageRep.FileType(rawValue: 8) ?? .png // HEIC
            } else {
                return .png
            }
        }
    }
    
    var compressionProperties: [NSBitmapImageRep.PropertyKey: Any] {
        switch self {
        case .jpeg:
            return [.compressionFactor: 0.9]
        default:
            return [:]
        }
    }
}
