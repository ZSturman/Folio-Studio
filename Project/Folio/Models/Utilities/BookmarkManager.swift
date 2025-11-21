//
//  BookmarkManager.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import Foundation
import AppKit

/// Manages security-scoped bookmarks stored in .system/bookmarks.plist within .folio package
final class BookmarkManager {
    
    static let shared = BookmarkManager()
    private init() {}
    
    private let bookmarksFileName = "bookmarks.plist"
    private let systemFolderName = ".system"
    
    // MARK: - Storage
    
    /// Store a bookmark for a given path in the document's .system folder
    func store(bookmark: Data, forPath path: String, in documentWrapper: FileWrapper?) throws {
        guard let wrapper = documentWrapper else {
            print("[BookmarkManager] No document wrapper provided")
            return
        }
        
        // Get or create .system folder
        let systemWrapper = try getOrCreateSystemFolder(in: wrapper)
        
        // Get or create bookmarks.plist
        var bookmarks = try loadBookmarks(from: systemWrapper)
        
        // Store bookmark
        bookmarks[path] = bookmark
        
        // Save back
        try saveBookmarks(bookmarks, to: systemWrapper)
    }
    
    /// Resolve a path using stored bookmark data
    func resolve(path: String, from documentWrapper: FileWrapper?) -> URL? {
        guard let wrapper = documentWrapper,
              let systemWrapper = wrapper.fileWrappers?[systemFolderName],
              let bookmarks = try? loadBookmarks(from: systemWrapper),
              let bookmarkData = bookmarks[path] else {
            return nil
        }
        
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                print("[BookmarkManager] Bookmark is stale for path: \(path)")
            }
            
            return url
        } catch {
            print("[BookmarkManager] Failed to resolve bookmark for \(path): \(error)")
            return nil
        }
    }
    
    /// Update bookmark key when path changes (e.g., rename)
    func updateKey(from oldPath: String, to newPath: String, in documentWrapper: FileWrapper?) throws {
        guard let wrapper = documentWrapper,
              let systemWrapper = wrapper.fileWrappers?[systemFolderName] else {
            return
        }
        
        var bookmarks = try loadBookmarks(from: systemWrapper)
        
        if let bookmark = bookmarks[oldPath] {
            bookmarks.removeValue(forKey: oldPath)
            bookmarks[newPath] = bookmark
            try saveBookmarks(bookmarks, to: systemWrapper)
        }
    }
    
    /// Request user access to a file/folder and store the bookmark
    func requestAccess(for path: String, in documentWrapper: FileWrapper?) throws -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Grant access to: \(URL(fileURLWithPath: path).lastPathComponent)"
        panel.prompt = "Grant Access"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        // Try to navigate to the parent folder
        let url = URL(fileURLWithPath: path)
        panel.directoryURL = url.deletingLastPathComponent()
        
        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return nil
        }
        
        // Create security-scoped bookmark
        do {
            let bookmarkData = try selectedURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            try store(bookmark: bookmarkData, forPath: path, in: documentWrapper)
            return selectedURL
        } catch {
            print("[BookmarkManager] Failed to create bookmark: \(error)")
            throw error
        }
    }
    
    /// Remove all bookmarks from document
    func clearAll(in documentWrapper: FileWrapper?) throws {
        guard let wrapper = documentWrapper,
              let systemWrapper = wrapper.fileWrappers?[systemFolderName] else {
            return
        }
        
        try saveBookmarks([:], to: systemWrapper)
    }
    
    /// Get all stored bookmark paths
    func allPaths(in documentWrapper: FileWrapper?) -> [String] {
        guard let wrapper = documentWrapper,
              let systemWrapper = wrapper.fileWrappers?[systemFolderName],
              let bookmarks = try? loadBookmarks(from: systemWrapper) else {
            return []
        }
        return Array(bookmarks.keys)
    }
    
    // MARK: - Helper Methods
    
    private func getOrCreateSystemFolder(in wrapper: FileWrapper) throws -> FileWrapper {
        if let existing = wrapper.fileWrappers?[systemFolderName] {
            return existing
        }
        
        // Create new .system folder
        let systemWrapper = FileWrapper(directoryWithFileWrappers: [:])
        systemWrapper.preferredFilename = systemFolderName
        wrapper.addFileWrapper(systemWrapper)
        
        return systemWrapper
    }
    
    private func loadBookmarks(from systemWrapper: FileWrapper) throws -> [String: Data] {
        guard let bookmarkWrapper = systemWrapper.fileWrappers?[bookmarksFileName],
              let data = bookmarkWrapper.regularFileContents else {
            return [:]
        }
        
        let decoder = PropertyListDecoder()
        return (try? decoder.decode([String: Data].self, from: data)) ?? [:]
    }
    
    private func saveBookmarks(_ bookmarks: [String: Data], to systemWrapper: FileWrapper) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(bookmarks)
        
        if let existing = systemWrapper.fileWrappers?[bookmarksFileName] {
            systemWrapper.removeFileWrapper(existing)
        }
        
        let bookmarkWrapper = FileWrapper(regularFileWithContents: data)
        bookmarkWrapper.preferredFilename = bookmarksFileName
        systemWrapper.addFileWrapper(bookmarkWrapper)
    }
    
    // MARK: - Migration Support
    
    /// Extract bookmarks from old document format and prepare for package migration
    static func extractBookmarksForMigration(from document: FolioDocument) -> [String: Data] {
        var bookmarks: [String: Data] = [:]
        
        // Extract assetFolder bookmark
        if let assetFolderPath = document.assetsFolder?.path,
           let bookmarkData = document.assetsFolder?.bookmarkData {
            bookmarks[assetFolderPath] = bookmarkData
        }
        
        // Note: AssetPath bookmarks will be handled when AssetPath is updated
        // For now, we'll just handle the assetsFolder
        
        return bookmarks
    }
}
