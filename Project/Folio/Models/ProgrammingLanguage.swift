//
//  ProgrammingLanguage.swift
//  Folio
//
//  Created by Zachary Sturman on 11/13/25.
//

import Foundation

// MARK: - Language

enum ProgrammingLanguage: String, CaseIterable, Identifiable, Hashable {
    case python
    case swift
    case javascript
    case typescript
    case ruby
    case go

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Snippet IDs

/// Stable identifiers for each snippet. These map directly to resource filenames
/// in Resources/CodeSnippets/<language>/<snippetID>.md
enum CodeSnippetID: String, CaseIterable, Identifiable {
    case loadSummary
    case exportMetadata

    var id: String { rawValue }
}

// MARK: - Lightweight metadata model

/// Describes a snippet's metadata. Actual code is loaded from Markdown files
/// in the app bundle using `CodeSnippetLibrary`.
struct CodeSnippet: Identifiable {
    let id: CodeSnippetID
    let title: String
    let summary: String
    let inputDescription: String?
    let outputDescription: String?
    let notes: String?
}
