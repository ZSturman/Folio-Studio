//
//  PermissionHelper.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import Foundation
import AppKit


enum PermissionHelper {
    
    static func isReadable(_ url: URL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path)
    }

    /// Try to resolve a previously stored bookmark for a path using BookmarkManager
    static func resolvedURL(forOriginalPath path: String, from documentWrapper: FileWrapper?) -> URL? {
        guard let url = BookmarkManager.shared.resolve(path: path, from: documentWrapper) else {
            return nil
        }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    /// Ask user to grant access to the file or its containing folder and save a bookmark for future sessions.
    static func requestAccess(for target: URL, in documentWrapper: FileWrapper?) -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Grant permission to read \"\(target.lastPathComponent)\". You can choose the file itself or its folder."
        panel.directoryURL = target.deletingLastPathComponent()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let picked = panel.url {
            do {
                let data = try picked.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                try BookmarkManager.shared.store(
                    bookmark: data,
                    forPath: picked.path,
                    in: documentWrapper
                )
                
                _ = picked.startAccessingSecurityScopedResource()
                return picked
            } catch {
                print("[PermissionHelper] Failed to store bookmark: \(error)")
                return nil
            }
        }
        return nil
    }
}
