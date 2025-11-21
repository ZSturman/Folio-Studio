//
//  URL+Extensions.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import Foundation

extension URL {
    /// Calculate relative path from a base URL to this URL
    /// Returns nil if URLs are not related
    func relativePath(from baseURL: URL) -> String? {
        // Standardize paths
        let basePath = baseURL.standardized.path
        let targetPath = self.standardized.path
        
        // Check if target is under base
        guard targetPath.hasPrefix(basePath) else {
            return nil
        }
        
        // Remove base path prefix
        var relativePath = String(targetPath.dropFirst(basePath.count))
        
        // Remove leading slash if present
        if relativePath.hasPrefix("/") {
            relativePath = String(relativePath.dropFirst())
        }
        
        return relativePath.isEmpty ? nil : relativePath
    }
}
