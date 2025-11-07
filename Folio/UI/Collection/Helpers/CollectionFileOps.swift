//
//  CollectionFileOps.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//



import Foundation

enum CollectionFS {
    static func safeName(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_- "))
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let mapped = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(mapped).replacingOccurrences(of: " ", with: "_")
    }

    static func collectionsRoot(in assets: URL) -> URL {
        assets.appendingPathComponent("Collections", isDirectory: true)
    }

    @discardableResult
    static func ensureCollectionsRoot(in assets: URL) throws -> URL {
        let root = collectionsRoot(in: assets)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @discardableResult
    static func ensureCollectionFolder(assetsFolder: URL, name: String) throws -> URL {
        let root = try ensureCollectionsRoot(in: assetsFolder)
        let folder = root.appendingPathComponent(safeName(name), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @discardableResult
    static func ensureItemFolder(collectionFolder: URL, itemLabel: String) throws -> URL {
        let folder = collectionFolder.appendingPathComponent(safeName(itemLabel), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func copyWithCollision(from src: URL, to destFolder: URL) throws -> URL {
        let fm = FileManager.default
        let base = src.deletingPathExtension().lastPathComponent
        let ext = src.pathExtension
        var candidate = destFolder.appendingPathComponent(src.lastPathComponent)
        var n = 1
        while fm.fileExists(atPath: candidate.path) {
            let name = "\(base)_\(n)" + (ext.isEmpty ? "" : ".\(ext)")
            candidate = destFolder.appendingPathComponent(name)
            n += 1
        }
        try fm.copyItem(at: src, to: candidate)
        return candidate
    }

    // Rename a collection folder and return new absolute folder URL.
    static func renameCollectionFolder(assetsFolder: URL, oldName: String, newName: String) throws -> URL {
        let fm = FileManager.default
        let root = try ensureCollectionsRoot(in: assetsFolder)
        let from = root.appendingPathComponent(safeName(oldName), isDirectory: true)
        let to = root.appendingPathComponent(safeName(newName), isDirectory: true)
        if fm.fileExists(atPath: from.path) {
            if fm.fileExists(atPath: to.path) {
                throw NSError(domain: "CollectionFS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination exists"])
            }
            try fm.moveItem(at: from, to: to)
        } else {
            // If old folder didn't exist yet, just ensure the new one.
            try fm.createDirectory(at: to, withIntermediateDirectories: true)
        }
        return to
    }

    // Rename an item folder within a collection and return new folder URL.
    static func renameItemFolder(collectionFolder: URL, oldLabel: String, newLabel: String) throws -> URL {
        let fm = FileManager.default
        let from = collectionFolder.appendingPathComponent(safeName(oldLabel), isDirectory: true)
        let to = collectionFolder.appendingPathComponent(safeName(newLabel), isDirectory: true)
        if fm.fileExists(atPath: from.path) {
            if fm.fileExists(atPath: to.path) {
                throw NSError(domain: "CollectionFS", code: 2, userInfo: [NSLocalizedDescriptionKey: "Destination exists"])
            }
            try fm.moveItem(at: from, to: to)
        } else {
            try fm.createDirectory(at: to, withIntermediateDirectories: true)
        }
        return to
    }

    // Rewrite a stored edited-path when its parent folder changes.
    static func rebaseEditedPath(oldEditedPath: String, oldParent: URL, newParent: URL) -> String {
        guard !oldEditedPath.isEmpty else { return "" }
        let old = URL(fileURLWithPath: oldEditedPath)
        let leaf = old.lastPathComponent
        return newParent.appendingPathComponent(leaf).path
    }
}
