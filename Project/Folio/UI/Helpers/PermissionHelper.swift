//
//  PermissionHelper.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import Foundation
import AppKit


enum PermissionHelper {
    private static let storeKey = "SecurityScopedBookmarks"

    static func isReadable(_ url: URL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path)
    }

    /// Try to resolve a previously stored bookmark for a path and start access.
    static func resolvedURL(forOriginalPath path: String) -> URL? {
        guard let dict = UserDefaults.standard.dictionary(forKey: storeKey) as? [String: Data],
              let data = dict[path] else { return nil }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
            _ = url.startAccessingSecurityScopedResource()
            return url
        }
        return nil
    }

    /// Ask user to grant access to the file or its containing folder and save a bookmark for future sessions.
    static func requestAccess(for target: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Grant permission to read “\(target.lastPathComponent)”. You can choose the file itself or its folder."
        panel.directoryURL = target.deletingLastPathComponent()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let picked = panel.url {
            do {
                let data = try picked.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                var dict = UserDefaults.standard.dictionary(forKey: storeKey) as? [String: Data] ?? [:]
                dict[picked.path] = data
                UserDefaults.standard.set(dict, forKey: storeKey)
                _ = picked.startAccessingSecurityScopedResource()
                return picked
            } catch {
                return nil
            }
        }
        return nil
    }
}
