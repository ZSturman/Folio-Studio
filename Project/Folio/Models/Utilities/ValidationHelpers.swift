//
//  ValidationHelpers.swift
//  Folio
//
//  Created by Zachary Sturman on 11/17/25.
//

import Foundation

// MARK: - Validation Errors

enum ValidationError: Error, LocalizedError {
    case emptyTitle
    case invalidURL(String)
    case invalidFilePath(String)
    case circularReference(UUID)
    case invalidCropBounds
    case pathTooLong(Int)
    case invalidCharactersInPath(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Title cannot be empty. Please provide a title for your project."
        case .invalidURL(let url):
            return "Invalid URL: \(url). Please provide a valid http, https, or file URL."
        case .invalidFilePath(let path):
            return "Invalid file path: \(path). The path contains invalid characters."
        case .circularReference(let id):
            return "Circular reference detected for project \(id.uuidString). This could cause infinite loops."
        case .invalidCropBounds:
            return "Crop bounds are invalid. Please adjust the crop area."
        case .pathTooLong(let length):
            return "File path is too long (\(length) characters). Maximum allowed is 1024 characters."
        case .invalidCharactersInPath(let chars):
            return "File path contains invalid characters: \(chars)"
        }
    }
}

// MARK: - Validation Result

enum ValidationResult {
    case valid
    case warning(String)
    case error(ValidationError)
    
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
    
    var message: String? {
        switch self {
        case .valid:
            return nil
        case .warning(let msg):
            return msg
        case .error(let err):
            return err.localizedDescription
        }
    }
}

// MARK: - Validation Helpers

struct Validator {
    
    // MARK: - Title Validation
    
    static func validateTitle(_ title: String) -> ValidationResult {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .error(.emptyTitle)
        }
        
        if title != trimmed {
            return .warning("Title has leading or trailing whitespace that will be preserved.")
        }
        
        if trimmed.count > 500 {
            return .warning("Title is very long (\(trimmed.count) characters). Consider shortening it.")
        }
        
        return .valid
    }
    
    static func sanitizeTitle(_ title: String, defaultValue: String = "Untitled Project") -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }
    
    // MARK: - URL Validation
    
    static func validateURL(_ urlString: String, allowEmpty: Bool = false) -> ValidationResult {
        if urlString.isEmpty {
            return allowEmpty ? .valid : .error(.invalidURL("URL cannot be empty"))
        }
        
        // Allow relative URLs
        if urlString.hasPrefix("/") || urlString.hasPrefix("./") {
            return .valid
        }
        
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased() else {
            return .error(.invalidURL(urlString))
        }
        
        let allowedSchemes = ["http", "https", "file", "ftp", "mailto"]
        
        if !allowedSchemes.contains(scheme) {
            return .warning("URL scheme '\(scheme)' may not be supported on all platforms.")
        }
        
        // Additional validation for http/https
        if ["http", "https"].contains(scheme) {
            if url.host == nil {
                return .error(.invalidURL("URL is missing a host"))
            }
        }
        
        return .valid
    }
    
    // MARK: - File Path Validation
    
    static func validateFilePath(_ path: String, allowEmpty: Bool = false) -> ValidationResult {
        if path.isEmpty {
            return allowEmpty ? .valid : .error(.invalidFilePath("Path cannot be empty"))
        }
        
        // Check length (macOS limit is typically 1024)
        if path.count > 1024 {
            return .error(.pathTooLong(path.count))
        }
        
        // Check for invalid characters on macOS
        // macOS allows most characters, but some are problematic
        let invalidChars: Set<Character> = ["\0"] // Null byte
        let foundInvalid = path.filter { invalidChars.contains($0) }
        
        if !foundInvalid.isEmpty {
            return .error(.invalidCharactersInPath(String(foundInvalid)))
        }
        
        // Warning for paths with special characters that might cause issues
        let problematicChars: Set<Character> = [":", "*", "?", "\"", "<", ">", "|"]
        let foundProblematic = path.filter { problematicChars.contains($0) }
        
        if !foundProblematic.isEmpty {
            return .warning("Path contains characters that may cause issues: \(String(foundProblematic))")
        }
        
        return .valid
    }
    
    // MARK: - Circular Reference Detection
    
    static func detectCircularReferences(
        startingFrom rootID: UUID,
        in collection: [String: CollectionSection],
        maxDepth: Int = 10
    ) -> ValidationResult {
        // Build a graph of item IDs to their folio link targets
        var graph: [UUID: [UUID]] = [:]
        var allItemIDs: Set<UUID> = []
        
        for section in collection.values {
            for item in section.items {
                allItemIDs.insert(item.id)
                if item.type == .folio,
                   let linkedIDString = item.url,
                   let linkedID = UUID(uuidString: linkedIDString) {
                    graph[item.id, default: []].append(linkedID)
                }
            }
        }
        
        // Check for cycles using DFS from rootID
        var visited: Set<UUID> = []
        var recursionStack: Set<UUID> = []
        
        func hasCycle(from id: UUID, depth: Int) -> Bool {
            if depth > maxDepth {
                return true // Too deep, assume circular
            }
            
            if recursionStack.contains(id) {
                return true // Found a cycle
            }
            
            if visited.contains(id) {
                return false // Already checked this path, no cycle
            }
            
            visited.insert(id)
            recursionStack.insert(id)
            
            if let links = graph[id] {
                for linkedID in links {
                    if hasCycle(from: linkedID, depth: depth + 1) {
                        return true
                    }
                }
            }
            
            recursionStack.remove(id)
            return false
        }
        
        if hasCycle(from: rootID, depth: 0) {
            return .error(.circularReference(rootID))
        }
        
        return .valid
    }
    
    // MARK: - Crop Bounds Validation
    
    struct CropRect {
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }
    
    static func validateCropBounds(_ rect: CropRect) -> ValidationResult {
        // Normalized coordinates should be in [0, 1]
        if rect.x < 0 || rect.x > 1 ||
           rect.y < 0 || rect.y > 1 {
            return .error(.invalidCropBounds)
        }
        
        if rect.width <= 0 || rect.height <= 0 {
            return .error(.invalidCropBounds)
        }
        
        if rect.x + rect.width > 1.01 { // Allow small epsilon for floating point
            return .error(.invalidCropBounds)
        }
        
        if rect.y + rect.height > 1.01 {
            return .error(.invalidCropBounds)
        }
        
        return .valid
    }
    
    static func clampCropBounds(_ rect: CropRect) -> CropRect {
        var clamped = rect
        clamped.x = max(0, min(1, rect.x))
        clamped.y = max(0, min(1, rect.y))
        clamped.width = max(0.01, min(1 - clamped.x, rect.width))
        clamped.height = max(0.01, min(1 - clamped.y, rect.height))
        return clamped
    }
    
    // MARK: - Collection Item Validation
    
    static func validateCollectionItem(_ item: JSONCollectionItem) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Validate label
        let labelResult = validateTitle(item.label)
        if !labelResult.isValid {
            results.append(labelResult)
        }
        
        // Validate based on type
        switch item.type {
        case .file:
            if let filePath = item.filePath {
                results.append(validateFilePath(filePath.pathToOriginal ?? ""))
            } else {
                results.append(.error(.invalidFilePath("File type item must have a file path")))
            }
            
        case .urlLink:
            if let url = item.url {
                results.append(validateURL(url))
            } else {
                results.append(.error(.invalidURL("URL type item must have a URL")))
            }
            
        case .folio:
            if let url = item.url {
                // Validate it's a valid UUID
                if UUID(uuidString: url) == nil {
                    results.append(.error(.invalidURL("Folio type item must have a valid UUID")))
                }
            } else {
                results.append(.error(.invalidURL("Folio type item must have a linked project UUID")))
            }
        }
        
        // Validate thumbnail paths
        if !(item.thumbnail.pathToOriginal?.isEmpty ?? true) {
            results.append(validateFilePath(item.thumbnail.pathToOriginal ?? "", allowEmpty: true))
        }
        
        return results.filter { !$0.isValid }
    }
    
    // MARK: - Document Validation
    
    static func validateDocument(_ doc: FolioDocument) -> [String: ValidationResult] {
        var results: [String: ValidationResult] = [:]
        
        // Title
        results["title"] = validateTitle(doc.title)
        
        // Resources
        for (index, resource) in doc.resources.enumerated() {
            if !resource.url.isEmpty {
                let urlResult = validateURL(resource.url, allowEmpty: true)
                if !urlResult.isValid {
                    results["resource.\(index).url"] = urlResult
                }
            }
        }
        
        // Collection items
        for (sectionName, section) in doc.collection {
            for (index, item) in section.items.enumerated() {
                let itemResults = validateCollectionItem(item)
                for (resultIndex, result) in itemResults.enumerated() {
                    results["collection.\(sectionName).\(index).\(resultIndex)"] = result
                }
            }
        }
        
        // Circular references
        let circularCheck = detectCircularReferences(
            startingFrom: doc.id,
            in: doc.collection
        )
        if !circularCheck.isValid {
            results["circular_references"] = circularCheck
        }
        
        return results.filter { !$0.value.isValid }
    }
}

// MARK: - Validation Extensions

extension FolioDocument {
    
    /// Validate the entire document and return any errors/warnings
    func validate() -> [String: ValidationResult] {
        return Validator.validateDocument(self)
    }
    
    /// Check if document is valid (no errors)
    func isValid() -> Bool {
        let results = validate()
        return results.allSatisfy { _, result in
            if case .error = result {
                return false
            }
            return true
        }
    }
    
    /// Get a sanitized copy with validated/corrected fields
    func sanitized() -> FolioDocument {
        var sanitized = self
        sanitized.title = Validator.sanitizeTitle(self.title)
        return sanitized
    }
}

extension JSONCollectionItem {
    
    /// Validate the collection item
    func validate() -> [ValidationResult] {
        return Validator.validateCollectionItem(self)
    }
    
    /// Check if item is valid
    func isValid() -> Bool {
        return validate().allSatisfy { result in
            if case .error = result {
                return false
            }
            return true
        }
    }
}
