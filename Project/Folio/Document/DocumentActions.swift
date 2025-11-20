//
//  DocumentActions.swift
//  Folio
//
//  Created by Zachary Sturman on 11/5/25.
//

import Combine
import AppKit

enum DocumentActions {
    static func openExistingDocumentPanel() {
#if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.folioDoc]
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
#endif
    }
    static func createNewDocumentWithSavePanel() {
#if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.folioDoc]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "New Project.folio"
        if panel.runModal() == .OK, let url = panel.url {
            let doc = FolioDocument()
            do {
                let data = try JSONEncoder().encode(doc)
                try data.write(to: url, options: [.atomic])
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
            } catch {
                #if os(macOS)
                NSAlert(error: error).runModal()
                #endif
            }
        }
#endif
    }
}




