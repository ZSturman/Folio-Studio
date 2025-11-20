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
    /// and write permission validation
    @discardableResult
    func ensureAssetsFolder(for document: Binding<FolioDocument>) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Assets Folder"
        panel.message = "Select a folder where images and files for this document will be stored. A subfolder structure will be created automatically."
        panel.prompt = "Select Folder"
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        // If we have a previously stored folder, use it as the starting location
        if let existing = document.wrappedValue.assetsFolder,
           let existingURL = existing.resolvedURL() {
            panel.directoryURL = existingURL
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            // Validate write permissions by creating and deleting a test file
            if validateWritePermissions(at: url) {
                document.wrappedValue.assetsFolder = AssetsFolderLocation(url: url)
                return url
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
}
