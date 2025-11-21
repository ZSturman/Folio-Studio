//
//  AssetFolderManager.swift
//  Folio
//
//  Created by Zachary Sturman on 11/19/25.
//

import Foundation
import SwiftUI
import AppKit

/// Centralized helper for managing asset folder selection with improved UX
class AssetFolderManager {
    static let shared = AssetFolderManager()
    
    private init() {}
    
    /// Ensures an assets folder is selected for the document, with clear UX messaging
    /// and write permission validation. Only prompts if folder is not set or inaccessible.
    @discardableResult
    func ensureAssetsFolder(for document: Binding<FolioDocument>) -> URL? {
        // First, try to resolve existing assets folder
        if let existing = document.wrappedValue.assetsFolder,
           let resolvedURL = existing.resolvedURL() {
            // Folder is already set and accessible
            return resolvedURL
        }
        
        // Assets folder not set or inaccessible - prompt user
        let panel = NSOpenPanel()
        panel.title = "Choose Assets Folder"
        panel.message = "Select a folder where images and files for this document will be stored. A subfolder structure will be created automatically."
        panel.prompt = "Select Folder"
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        // If we have a previously stored path (even if bookmark failed), use it as hint
        if let existing = document.wrappedValue.assetsFolder,
           let path = existing.path {
            panel.directoryURL = URL(fileURLWithPath: path)
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            // Validate write permissions by creating and deleting a test file
            if validateWritePermissions(at: url) {
                // Create AssetsFolderLocation with path
                let location = AssetsFolderLocation(path: url.path)
                
                // Store security-scoped bookmark using BookmarkManager
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    
                    try BookmarkManager.shared.store(
                        bookmark: bookmarkData,
                        forPath: url.path,
                        in: document.wrappedValue.documentWrapper
                    )
                    
                    document.wrappedValue.assetsFolder = location
                    return url
                } catch {
                    print("[AssetFolderManager] Failed to store bookmark: \(error)")
                    document.wrappedValue.assetsFolder = location
                    return url
                }
            } else {
                showPermissionError(for: url)
                return nil
            }
        }
        
        return nil
    }
    
    /// Validates that we can write to the selected folder
    private func validateWritePermissions(at url: URL) -> Bool {
        let testFileURL = url.appendingPathComponent(".folio_write_test")
        let testData = Data("test".utf8)
        
        do {
            try testData.write(to: testFileURL)
            try FileManager.default.removeItem(at: testFileURL)
            return true
        } catch {
            print("Write validation failed: \(error)")
            return false
        }
    }
    
    /// Shows an alert when folder doesn't have write permissions
    private func showPermissionError(for url: URL) {
        let alert = NSAlert()
        alert.messageText = "Cannot Write to Folder"
        alert.informativeText = "The selected folder '\(url.lastPathComponent)' does not have write permissions. Please choose a different folder or adjust permissions."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Request permission for an existing assets folder path
    /// Returns true if permission was granted and bookmark updated, false otherwise
    @discardableResult
    func requestPermissionForExistingFolder(path: String, in document: Binding<FolioDocument>) -> Bool {
        let folderURL = URL(fileURLWithPath: path)
        
        // Show alert explaining the issue
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        alert.informativeText = "This document's assets folder at '\(folderURL.lastPathComponent)' requires permission to access. Please grant access to continue working with images."
        alert.addButton(withTitle: "Grant Access")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return false
        }
        
        // Open file picker directly to the folder location
        let panel = NSOpenPanel()
        panel.title = "Grant Access to Assets Folder"
        panel.message = "Please select the folder '\(folderURL.lastPathComponent)' to grant access."
        panel.prompt = "Grant Access"
        panel.canCreateDirectories = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        // Navigate to the folder's parent or the folder itself if it exists
        if FileManager.default.fileExists(atPath: folderURL.path) {
            panel.directoryURL = folderURL.deletingLastPathComponent()
        } else {
            panel.directoryURL = folderURL.deletingLastPathComponent()
        }
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            // Verify they selected the correct folder
            if selectedURL.path != folderURL.path {
                let confirmAlert = NSAlert()
                confirmAlert.messageText = "Different Folder Selected"
                confirmAlert.informativeText = "You selected '\(selectedURL.lastPathComponent)' but the document expects '\(folderURL.lastPathComponent)'. Do you want to update the document to use the new location?"
                confirmAlert.addButton(withTitle: "Update Location")
                confirmAlert.addButton(withTitle: "Cancel")
                
                if confirmAlert.runModal() != .alertFirstButtonReturn {
                    return false
                }
            }
            
            // Validate write permissions
            if !validateWritePermissions(at: selectedURL) {
                showPermissionError(for: selectedURL)
                return false
            }
            
            // Create and store new bookmark
            do {
                let bookmarkData = try selectedURL.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                try BookmarkManager.shared.store(
                    bookmark: bookmarkData,
                    forPath: selectedURL.path,
                    in: document.wrappedValue.documentWrapper
                )
                
                // Update the document's assets folder path if changed
                if selectedURL.path != path {
                    document.wrappedValue.assetsFolder = AssetsFolderLocation(path: selectedURL.path)
                }
                
                return true
            } catch {
                print("[AssetFolderManager] Failed to store bookmark: \(error)")
                
                let errorAlert = NSAlert()
                errorAlert.messageText = "Failed to Save Permission"
                errorAlert.informativeText = "Could not save access permission: \(error.localizedDescription)"
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
                
                return false
            }
        }
        
        return false
    }
}
