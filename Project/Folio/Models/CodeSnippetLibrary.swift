//
//  CodeSnippetLibrary.swift
//  Folio
//
//  Created by Zachary Sturman on 11/13/25.
//

import Foundation

// MARK: - Wrapper type returned to the UI

struct LoadedCodeSnippet: Identifiable {
    let id: CodeSnippetID
    let title: String
    let summary: String
    let inputDescription: String?
    let outputDescription: String?
    let notes: String?
    let code: String
}

// MARK: - Library

enum CodeSnippetLibrary {
    /// Load snippets for a specific language and mode
    static func loadedSnippets(
        for language: ProgrammingLanguage,
        bundle: Bundle = .main,
        mode: SnippetMode = .single
    ) -> [LoadedCodeSnippet] {
        guard language == .python else { return [] }
        
        return metadata.compactMap { snippet in
            guard let codeTemplate = codeByLanguage[snippet.id]?[language] else {
                return nil
            }
            
            // Replace placeholders based on mode
            let code = adaptCodeForMode(codeTemplate, mode: mode, snippetID: snippet.id)
            
            return LoadedCodeSnippet(
                id: snippet.id,
                title: snippet.title,
                summary: snippet.summary,
                inputDescription: snippet.inputDescription,
                outputDescription: snippet.outputDescription,
                notes: snippet.notes,
                code: code
            )
        }
    }
    
    private static func adaptCodeForMode(_ code: String, mode: SnippetMode, snippetID: CodeSnippetID) -> String {
        // For now, simplified JSON viewing snippets don't need adaptation
        // Future: could add single vs multiple folio logic here
        return code
    }
    
    // Metadata for JSON viewing snippets only
    static let metadata: [CodeSnippet] = [
        CodeSnippet(
            id: .loadSummary,
            title: "Load and view Folio JSON structure",
            summary: "Reads a Folio JSON file and displays the document structure with indentation.",
            inputDescription: "Path to a `.folio` or `.folioDoc` file on disk.",
            outputDescription: "Pretty-printed JSON structure to the console.",
            notes: "Use this to understand your document's structure and verify data integrity."
        ),
        CodeSnippet(
            id: .exportMetadata,
            title: "Parse and extract specific fields",
            summary: "Loads a Folio file and extracts specific metadata fields like title, domain, tags, and status.",
            inputDescription: "Path to a `.folio` / `.folioDoc` file.",
            outputDescription: "Selected fields printed or saved to a file.",
            notes: "Customize which fields to extract based on your needs."
        )
    ]

    /// Language-specific code bodies for each snippet.
    static let codeByLanguage: [CodeSnippetID: [ProgrammingLanguage: String]] = [
        .loadSummary: [
            .python: """
import json
from pathlib import Path


def load_and_view_folio(path: str) -> None:
    \"\"\"Load a Folio JSON document and print it with formatting.\"\"\"
    p = Path(path)
    
    if not p.exists():
        print(f"Error: File not found: {path}")
        return
    
    with p.open("r", encoding="utf-8") as f:
        project = json.load(f)
    
    # Pretty print the entire JSON structure
    print(json.dumps(project, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python view_folio.py <path_to_folio_file>")
        print("Example: python view_folio.py /path/to/MyProject.folioDoc")
        sys.exit(1)
    
    folio_path = sys.argv[1]
    load_and_view_folio(folio_path)
"""
        ],
        .exportMetadata: [
            .python: """
import json
from pathlib import Path
from typing import Any, Dict


def load_folio(path: str) -> Dict[str, Any]:
    \"\"\"Load a Folio JSON document from disk.\"\"\"
    p = Path(path)
    with p.open("r", encoding="utf-8") as f:
        return json.load(f)


def extract_metadata(project: Dict[str, Any]) -> Dict[str, Any]:
    \"\"\"Extract key metadata fields from a Folio project.\"\"\"
    metadata = {
        "id": project.get("id"),
        "title": project.get("title"),
        "subtitle": project.get("subtitle"),
        "domain": project.get("domain"),
        "category": project.get("category"),
        "status": project.get("status"),
        "phase": project.get("phase"),
        "tags": project.get("tags", []),
        "isPublic": project.get("isPublic", False),
        "summary": project.get("summary"),
    }
    
    # Count collection items
    collection = project.get("collection", {})
    total_items = sum(
        len(section.get("items", [])) 
        for section in collection.values() 
        if isinstance(section, dict)
    )
    metadata["collectionItemCount"] = total_items
    
    # Count resources
    resources = project.get("resources", [])
    metadata["resourceCount"] = len(resources) if isinstance(resources, list) else 0
    
    return metadata


def print_metadata(metadata: Dict[str, Any]) -> None:
    \"\"\"Print metadata in a readable format.\"\"\"
    print("=" * 50)
    print("FOLIO PROJECT METADATA")
    print("=" * 50)
    
    for key, value in metadata.items():
        if isinstance(value, list):
            print(f"{key}: {', '.join(map(str, value))}")
        else:
            print(f"{key}: {value}")
    
    print("=" * 50)


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python extract_metadata.py <path_to_folio_file> [output.json]")
        print("Example: python extract_metadata.py /path/to/MyProject.folioDoc")
        print("         python extract_metadata.py /path/to/MyProject.folioDoc metadata.json")
        sys.exit(1)
    
    folio_path = sys.argv[1]
    project = load_folio(folio_path)
    metadata = extract_metadata(project)
    
    # Print to console
    print_metadata(metadata)
    
    # Optionally save to file
    if len(sys.argv) >= 3:
        output_path = Path(sys.argv[2])
        with output_path.open("w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=2, ensure_ascii=False)
        print(f"\\nMetadata saved to: {output_path}")
"""
        ]
    ]
}
