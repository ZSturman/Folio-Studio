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
    // Metadata for all snippets. Code is stored in-memory and selected per language.
    static let metadata: [CodeSnippet] = [
        CodeSnippet(
            id: .loadSummary,
            title: "Load a Folio document and print a quick summary",
            summary: "Reads a Folio JSON file and prints basic information such as id, title, domain, tags, and collection counts.",
            inputDescription: "Path to a `.folio` or `.folioDoc` file on disk.",
            outputDescription: "A human-readable summary printed to the console.",
            notes: "Use this as a sanity check after exporting from the Folio app."
        ),
        CodeSnippet(
            id: .exportMetadata,
            title: "Export project metadata as a clean JSON blob",
            summary: "Loads a Folio file and writes a trimmed-down `metadata.json` with just the fields you care about.",
            inputDescription: "Path to a `.folio` / `.folioDoc` file and an optional output path.",
            outputDescription: "`metadata.json` written to disk.",
            notes: "Great for feeding Folio projects into a CMS or static site generator."
        ),
        CodeSnippet(
            id: .copyImages,
            title: "Copy all project images into one folder",
            summary: "Scans the top-level `images` field, picks `pathToEdited` or `pathToOriginal`, and copies all images into a flat directory.",
            inputDescription: "Path to a `.folio` / `.folioDoc` file and a destination folder path.",
            outputDescription: "All referenced images copied into the specified folder.",
            notes: "Use this to quickly gather assets for design tools or manual uploads."
        ),
        CodeSnippet(
            id: .iterateCollections,
            title: "Loop over collection items and infer type",
            summary: "Walks every collection (episodes, gallery, etc.), guesses a canonical type, and prints a compact summary per item.",
            inputDescription: "Path to a `.folio` / `.folioDoc` file.",
            outputDescription: "A list of collection items with id, inferred type, label, and URL.",
            notes: "Handy for building galleries, feeds, or analytics on top of collection data."
        ),
        CodeSnippet(
            id: .listURLs,
            title: "Collect all URLs from a Folio project",
            summary: "Extracts every URL from top-level resources and collection item resources.",
            inputDescription: "Path to a `.folio` / `.folioDoc` file.",
            outputDescription: "A unique list of URLs printed to the console.",
            notes: "Use this to power link checkers, analytics, or previews."
        ),
        CodeSnippet(
            id: .externalImageHosts,
            title: "Find which domains host your images",
            summary: "Recursively scans projects and collects unique hostnames from any URL-like fields.",
            inputDescription: "One or more paths to `.folio` / `.folioDoc` files.",
            outputDescription: "A list of unique hostnames printed to the console.",
            notes: "Helps you see whether assets are local, on a CDN, or on third-party services."
        ),
        CodeSnippet(
            id: .batchProcess,
            title: "Run a function on every Folio document in a folder",
            summary: "Recursively finds all Folio documents under a root folder and applies a handler function to each one.",
            inputDescription: "Path to a root folder on disk.",
            outputDescription: "Whatever your handler function does (e.g., printing, exporting files, etc.).",
            notes: "Use this as a template for writing your own batch tools."
        )
    ]

    /// Language-specific code bodies for each snippet.
    static let codeByLanguage: [CodeSnippetID: [ProgrammingLanguage: String]] = [
        .loadSummary: [
            .python: """
import json
from pathlib import Path


def load_folio(path: str) -> dict:
    # Load a Folio JSON document from disk.
    p = Path(path)
    with p.open("r", encoding="utf-8") as f:
        return json.load(f)


def count_collection_items(project: dict) -> int:
    # Return the total number of items across all collections.
    collection = project.get("collection") or {}
    total = 0
    for items in collection.values():
        if isinstance(items, list):
            total += len(items)
    return total


def print_summary(project: dict) -> None:
    # Print a human-readable summary of a Folio project.
    print("ID:      ", project.get("id"))
    print("Title:   ", project.get("title") or project.get("name"))
    print("Subtitle:", project.get("subtitle"))
    print("Domain:  ", project.get("domain"))
    print("Public?: ", project.get("isPublic"))
    print("Tags:    ", ", ".join(project.get("tags") or []))

    total_collection_items = count_collection_items(project)
    print("Collection items:", total_collection_items)


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python load_folio_summary.py /path/to/project.folioDoc")
    project = load_folio(sys.argv[1])
    print_summary(project)
""",
            .swift: """
import Foundation

func loadFolio(at path: String) throws -> [String: Any] {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    let json = try JSONSerialization.jsonObject(with: data, options: [])
    return json as? [String: Any] ?? [:]
}

func countCollectionItems(in project: [String: Any]) -> Int {
    let collection = project["collection"] as? [String: Any] ?? [:]
    var total = 0
    for value in collection.values {
        if let items = value as? [Any] {
            total += items.count
        }
    }
    return total
}

func printSummary(for project: [String: Any]) {
    print("ID:      ", project["id"] ?? "nil")
    let title = project["title"] ?? project["name"] ?? "nil"
    print("Title:   ", title)
    print("Subtitle:", project["subtitle"] ?? "nil")
    print("Domain:  ", project["domain"] ?? "nil")
    print("Public?: ", project["isPublic"] ?? "nil")

    if let tags = project["tags"] as? [String] {
        print("Tags:    ", tags.joined(separator: ", "))
    } else {
        print("Tags:    ")
    }

    let total = countCollectionItems(in: project)
    print("Collection items:", total)
}

if CommandLine.arguments.count != 2 {
    fputs("Usage: load_folio_summary /path/to/project.folioDoc\\n", stderr)
    exit(1)
}

do {
    let path = CommandLine.arguments[1]
    let project = try loadFolio(at: path)
    printSummary(for: project)
} catch {
    fputs("Error: \\(error)\\n", stderr)
    exit(1)
}
""",
            .javascript: """
const fs = require("fs");
const path = require("path");

function loadFolio(filePath) {
    const abs = path.resolve(filePath);
    const data = fs.readFileSync(abs, { encoding: "utf8" });
    return JSON.parse(data);
}

function countCollectionItems(project) {
    const collection = project.collection || {};
    let total = 0;
    for (const key of Object.keys(collection)) {
        const items = collection[key];
        if (Array.isArray(items)) {
            total += items.length;
        }
    }
    return total;
}

function printSummary(project) {
    console.log("ID:      ", project.id);
    console.log("Title:   ", project.title || project.name);
    console.log("Subtitle:", project.subtitle);
    console.log("Domain:  ", project.domain);
    console.log("Public?: ", project.isPublic);
    console.log("Tags:    ", (project.tags || []).join(", "));

    const total = countCollectionItems(project);
    console.log("Collection items:", total);
}

if (require.main === module) {
    if (process.argv.length !== 3) {
        console.error("Usage: node load_folio_summary.js /path/to/project.folioDoc");
        process.exit(1);
    }
    const project = loadFolio(process.argv[2]);
    printSummary(project);
}
""",
            .typescript: """
import * as fs from "fs";
import * as path from "path";

interface Project {
    [key: string]: any;
    id?: string;
    title?: string;
    name?: string;
    subtitle?: string;
    domain?: string;
    isPublic?: boolean;
    tags?: string[];
    collection?: { [key: string]: any[] };
}

function loadFolio(filePath: string): Project {
    const abs = path.resolve(filePath);
    const data = fs.readFileSync(abs, { encoding: "utf8" });
    return JSON.parse(data) as Project;
}

function countCollectionItems(project: Project): number {
    const collection = project.collection || {};
    let total = 0;
    for (const key of Object.keys(collection)) {
        const items = collection[key];
        if (Array.isArray(items)) {
            total += items.length;
        }
    }
    return total;
}

function printSummary(project: Project): void {
    console.log("ID:      ", project.id);
    console.log("Title:   ", project.title || project.name);
    console.log("Subtitle:", project.subtitle);
    console.log("Domain:  ", project.domain);
    console.log("Public?: ", project.isPublic);
    console.log("Tags:    ", (project.tags || []).join(", "));

    const total = countCollectionItems(project);
    console.log("Collection items:", total);
}

if (require.main === module) {
    if (process.argv.length !== 3) {
        console.error("Usage: ts-node load_folio_summary.ts /path/to/project.folioDoc");
        process.exit(1);
    }
    const project = loadFolio(process.argv[2]);
    printSummary(project);
}
""",
            .ruby: """
require "json"

def load_folio(path)
  data = File.read(path, encoding: "UTF-8")
  JSON.parse(data)
end

def count_collection_items(project)
  collection = project["collection"] || {}
  total = 0
  collection.each_value do |items|
    total += items.length if items.is_a?(Array)
  end
  total
end

def print_summary(project)
  puts "ID:       #{project["id"]}"
  puts "Title:    #{project["title"] || project["name"]}"
  puts "Subtitle: #{project["subtitle"]}"
  puts "Domain:   #{project["domain"]}"
  puts "Public?:  #{project["isPublic"]}"
  tags = project["tags"] || []
  puts "Tags:     #{tags.join(", ")}"
  total = count_collection_items(project)
  puts "Collection items: #{total}"
end

if ARGV.length != 1
  abort "Usage: ruby load_folio_summary.rb /path/to/project.folioDoc"
end

project = load_folio(ARGV[0])
print_summary(project)
""",
            .go: """
package main

import (
    "encoding/json"
    "fmt"
    "io/ioutil"
    "log"
    "os"
)

type Project map[string]interface{}

func loadFolio(path string) (Project, error) {
    data, err := ioutil.ReadFile(path)
    if err != nil {
        return nil, err
    }
    var proj Project
    if err := json.Unmarshal(data, &proj); err != nil {
        return nil, err
    }
    return proj, nil
}

func countCollectionItems(project Project) int {
    collectionRaw, ok := project["collection"]
    if !ok {
        return 0
    }

    collection, ok := collectionRaw.(map[string]interface{})
    if !ok {
        return 0
    }

    total := 0
    for _, v := range collection {
        if items, ok := v.([]interface{}); ok {
            total += len(items)
        }
    }
    return total
}

func getStringField(p Project, key string) string {
    if v, ok := p[key]; ok {
        if s, ok := v.(string); ok {
            return s
        }
    }
    return ""
}

func getBoolField(p Project, key string) interface{} {
    if v, ok := p[key]; ok {
        return v
    }
    return nil
}

func getTags(p Project) []string {
    raw, ok := p["tags"]
    if !ok {
        return nil
    }
    arr, ok := raw.([]interface{})
    if !ok {
        return nil
    }
    tags := make([]string, 0, len(arr))
    for _, v := range arr {
        if s, ok := v.(string); ok {
            tags = append(tags, s)
        }
    }
    return tags
}

func printSummary(project Project) {
    fmt.Println("ID:      ", getStringField(project, "id"))

    title := getStringField(project, "title")
    if title == "" {
        title = getStringField(project, "name")
    }
    fmt.Println("Title:   ", title)
    fmt.Println("Subtitle:", getStringField(project, "subtitle"))
    fmt.Println("Domain:  ", getStringField(project, "domain"))
    fmt.Println("Public?: ", getBoolField(project, "isPublic"))

    tags := getTags(project)
    fmt.Println("Tags:    ", tags)

    total := countCollectionItems(project)
    fmt.Println("Collection items:", total)
}

func main() {
    if len(os.Args) != 2 {
        fmt.Fprintln(os.Stderr, "Usage: load_folio_summary /path/to/project.folioDoc")
        os.Exit(1)
    }

    project, err := loadFolio(os.Args[1])
    if err != nil {
        log.Fatalf("Error loading project: %v\\n", err)
    }

    printSummary(project)
}
""",
        ],
        .exportMetadata: [
            .python: """
import json
from pathlib import Path

METADATA_FIELDS = [
    "id",
    "filePath",
    "title",
    "subtitle",
    "summary",
    "description",
    "domain",
    "category",
    "status",
    "phase",
    "isPublic",
    "featured",
    "requiresFollowUp",
    "tags",
    "mediums",
    "genres",
    "topics",
    "subjects",
    "customFlag",
    "customNumber",
    "customObject",
]


def export_metadata(folio_path: str, out_path: str | None = None) -> Path:
    folio_file = Path(folio_path)
    with folio_file.open("r", encoding="utf-8") as f:
        project = json.load(f)

    meta = {k: project.get(k) for k in METADATA_FIELDS if k in project}

    if out_path is None:
        out_path = folio_file.with_name("metadata.json")

    out_file = Path(out_path)
    out_file.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    return out_file


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        raise SystemExit("Usage: python export_metadata.py project.folioDoc [metadata.json]")
    folio_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) == 3 else None
    out_file = export_metadata(folio_path, out_path)
    print("Wrote:", out_file)
""",
            .swift: """
import Foundation

let metadataFields: [String] = [
    "id",
    "filePath",
    "title",
    "subtitle",
    "summary",
    "description",
    "domain",
    "category",
    "status",
    "phase",
    "isPublic",
    "featured",
    "requiresFollowUp",
    "tags",
    "mediums",
    "genres",
    "topics",
    "subjects",
    "customFlag",
    "customNumber",
    "customObject",
]

func exportMetadata(folioPath: String, outPath: String?) throws -> URL {
    let folioURL = URL(fileURLWithPath: folioPath)
    let data = try Data(contentsOf: folioURL)
    let json = try JSONSerialization.jsonObject(with: data, options: [])
    let project = json as? [String: Any] ?? [:]

    var meta: [String: Any] = [:]
    for key in metadataFields {
        if let value = project[key] {
            meta[key] = value
        }
    }

    let outputURL: URL
    if let outPath = outPath {
        outputURL = URL(fileURLWithPath: outPath)
    } else {
        outputURL = folioURL.deletingLastPathComponent().appendingPathComponent("metadata.json")
    }

    let outData = try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys])
    try outData.write(to: outputURL, options: .atomic)
    return outputURL
}

if CommandLine.arguments.count < 2 || CommandLine.arguments.count > 3 {
    fputs("Usage: export_metadata /path/to/project.folioDoc [metadata.json]\\n", stderr)
    exit(1)
}

do {
    let folioPath = CommandLine.arguments[1]
    let outPath = CommandLine.arguments.count == 3 ? CommandLine.arguments[2] : nil
    let url = try exportMetadata(folioPath: folioPath, outPath: outPath)
    print("Wrote:", url.path)
} catch {
    fputs("Error: \\(error)\\n", stderr)
    exit(1)
}
""",
            .javascript: """
const fs = require("fs");
const path = require("path");

const METADATA_FIELDS = [
    "id",
    "filePath",
    "title",
    "subtitle",
    "summary",
    "description",
    "domain",
    "category",
    "status",
    "phase",
    "isPublic",
    "featured",
    "requiresFollowUp",
    "tags",
    "mediums",
    "genres",
    "topics",
    "subjects",
    "customFlag",
    "customNumber",
    "customObject",
];

function exportMetadata(folioPath, outPath) {
    const folioFile = path.resolve(folioPath);
    const raw = fs.readFileSync(folioFile, { encoding: "utf8" });
    const project = JSON.parse(raw);

    const meta = {};
    for (const key of METADATA_FIELDS) {
        if (Object.prototype.hasOwnProperty.call(project, key)) {
            meta[key] = project[key];
        }
    }

    const output = outPath
        ? path.resolve(outPath)
        : path.join(path.dirname(folioFile), "metadata.json");

    fs.writeFileSync(output, JSON.stringify(meta, null, 2), { encoding: "utf8" });
    return output;
}

if (require.main === module) {
    if (process.argv.length < 3 || process.argv.length > 4) {
        console.error("Usage: node export_metadata.js project.folioDoc [metadata.json]");
        process.exit(1);
    }
    const folioPath = process.argv[2];
    const outPath = process.argv[3];
    const output = exportMetadata(folioPath, outPath);
    console.log("Wrote:", output);
}
""",
            .typescript: """
import * as fs from "fs";
import * as path from "path";

const METADATA_FIELDS: string[] = [
    "id",
    "filePath",
    "title",
    "subtitle",
    "summary",
    "description",
    "domain",
    "category",
    "status",
    "phase",
    "isPublic",
    "featured",
    "requiresFollowUp",
    "tags",
    "mediums",
    "genres",
    "topics",
    "subjects",
    "customFlag",
    "customNumber",
    "customObject",
];

type Project = Record<string, unknown>;

function exportMetadata(folioPath: string, outPath?: string): string {
    const folioFile = path.resolve(folioPath);
    const raw = fs.readFileSync(folioFile, { encoding: "utf8" });
    const project = JSON.parse(raw) as Project;

    const meta: Project = {};
    for (const key of METADATA_FIELDS) {
        if (Object.prototype.hasOwnProperty.call(project, key)) {
            meta[key] = project[key];
        }
    }

    const output = outPath
        ? path.resolve(outPath)
        : path.join(path.dirname(folioFile), "metadata.json");

    fs.writeFileSync(output, JSON.stringify(meta, null, 2), { encoding: "utf8" });
    return output;
}

if (require.main === module) {
    if (process.argv.length < 3 || process.argv.length > 4) {
        console.error("Usage: ts-node export_metadata.ts project.folioDoc [metadata.json]");
        process.exit(1);
    }
    const folioPath = process.argv[2];
    const outPath = process.argv[3];
    const output = exportMetadata(folioPath, outPath);
    console.log("Wrote:", output);
}
""",
            .ruby: """
require "json"

METADATA_FIELDS = [
  "id",
  "filePath",
  "title",
  "subtitle",
  "summary",
  "description",
  "domain",
  "category",
  "status",
  "phase",
  "isPublic",
  "featured",
  "requiresFollowUp",
  "tags",
  "mediums",
  "genres",
  "topics",
  "subjects",
  "customFlag",
  "customNumber",
  "customObject",
].freeze

def export_metadata(folio_path, out_path = nil)
  folio_file = File.expand_path(folio_path)
  raw = File.read(folio_file, encoding: "UTF-8")
  project = JSON.parse(raw)

  meta = {}
  METADATA_FIELDS.each do |key|
    meta[key] = project[key] if project.key?(key)
  end

  output = out_path ? File.expand_path(out_path) : File.join(File.dirname(folio_file), "metadata.json")
  File.write(output, JSON.pretty_generate(meta), encoding: "UTF-8")
  output
end

if ARGV.length < 1 || ARGV.length > 2
  abort "Usage: ruby export_metadata.rb project.folioDoc [metadata.json]"
end

folio_path = ARGV[0]
out_path = ARGV[1]
output = export_metadata(folio_path, out_path)
puts "Wrote: #{output}"
""",
            .go: """
package main

import (
    "encoding/json"
    "fmt"
    "io/ioutil"
    "log"
    "os"
    "path/filepath"
)

var metadataFields = []string{
    "id",
    "filePath",
    "title",
    "subtitle",
    "summary",
    "description",
    "domain",
    "category",
    "status",
    "phase",
    "isPublic",
    "featured",
    "requiresFollowUp",
    "tags",
    "mediums",
    "genres",
    "topics",
    "subjects",
    "customFlag",
    "customNumber",
    "customObject",
}

func exportMetadata(folioPath, outPath string) (string, error) {
    folioFile, err := filepath.Abs(folioPath)
    if err != nil {
        return "", err
    }

    data, err := ioutil.ReadFile(folioFile)
    if err != nil {
        return "", err
    }

    var project map[string]interface{}
    if err := json.Unmarshal(data, &project); err != nil {
        return "", err
    }

    meta := make(map[string]interface{})
    for _, key := range metadataFields {
        if val, ok := project[key]; ok {
            meta[key] = val
        }
    }

    output := outPath
    if output == "" {
        output = filepath.Join(filepath.Dir(folioFile), "metadata.json")
    } else {
        abs, err := filepath.Abs(outPath)
        if err == nil {
            output = abs
        }
    }

    outData, err := json.MarshalIndent(meta, "", "  ")
    if err != nil {
        return "", err
    }

    if err := ioutil.WriteFile(output, outData, 0644); err != nil {
        return "", err
    }

    return output, nil
}

func main() {
    if len(os.Args) < 2 || len(os.Args) > 3 {
        fmt.Fprintln(os.Stderr, "Usage: export_metadata project.folioDoc [metadata.json]")
        os.Exit(1)
    }

    folioPath := os.Args[1]
    outPath := ""
    if len(os.Args) == 3 {
        outPath = os.Args[2]
    }

    output, err := exportMetadata(folioPath, outPath)
    if err != nil {
        log.Fatalf("Error exporting metadata: %v\\n", err)
    }

    fmt.Println("Wrote:", output)
}
""",
        ],
        .copyImages: [
            .python: """
import json
import shutil
from pathlib import Path


def resolve_image_path(project_dir: Path, entry: dict) -> Path | None:
    if not isinstance(entry, dict):
        return None
    rel = entry.get("pathToEdited") or entry.get("pathToOriginal")
    if not rel:
        return None
    return (project_dir / rel).resolve()


def copy_project_images(folio_path: str, dest_dir: str) -> list[Path]:
    folio_file = Path(folio_path).resolve()
    project_dir = folio_file.parent
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    with folio_file.open("r", encoding="utf-8") as f:
        project = json.load(f)

    images = project.get("images") or {}
    copied: list[Path] = []

    for key, entry in images.items():
        src = resolve_image_path(project_dir, entry)
        if not src or not src.exists():
            print(f"[WARN] Missing image for '{key}': {src}")
            continue
        target_path = dest / src.name
        shutil.copy2(src, target_path)
        copied.append(target_path)
        print(f"Copied {key}: {src} -> {target_path}")

    return copied


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        raise SystemExit("Usage: python copy_images_flat.py project.folioDoc /path/to/output")
    copy_project_images(sys.argv[1], sys.argv[2])
""",
            .swift: """
import Foundation

func resolveImageURL(projectDir: URL, entry: Any) -> URL? {
    guard let dict = entry as? [String: Any] else { return nil }
    let rel = (dict["pathToEdited"] as? String) ?? (dict["pathToOriginal"] as? String)
    guard let relPath = rel else { return nil }
    return projectDir.appendingPathComponent(relPath)
}

@discardableResult
func copyProjectImages(folioPath: String, destDir: String) throws -> [URL] {
    let folioURL = URL(fileURLWithPath: folioPath).standardizedFileURL
    let projectDir = folioURL.deletingLastPathComponent()
    let destURL = URL(fileURLWithPath: destDir).standardizedFileURL

    let data = try Data(contentsOf: folioURL)
    let json = try JSONSerialization.jsonObject(with: data, options: [])
    guard let project = json as? [String: Any] else { return [] }

    let fm = FileManager.default
    try fm.createDirectory(at: destURL, withIntermediateDirectories: true, attributes: nil)

    let images = project["images"] as? [String: Any] ?? [:]
    var copied: [URL] = []

    for (key, entry) in images {
        guard let src = resolveImageURL(projectDir: projectDir, entry: entry),
              fm.fileExists(atPath: src.path) else {
            print("[WARN] Missing image for '\\(key)'")
            continue
        }
        let target = destURL.appendingPathComponent(src.lastPathComponent)
        if fm.fileExists(atPath: target.path) {
            try fm.removeItem(at: target)
        }
        try fm.copyItem(at: src, to: target)
        copied.append(target)
        print("Copied \\(key): \\(src.path) -> \\(target.path)")
    }

    return copied
}

if CommandLine.arguments.count != 3 {
    fputs("Usage: copy_images_flat /path/to/project.folioDoc /path/to/output\\n", stderr)
    exit(1)
}

do {
    let folioPath = CommandLine.arguments[1]
    let destPath = CommandLine.arguments[2]
    _ = try copyProjectImages(folioPath: folioPath, destDir: destPath)
} catch {
    fputs("Error: \\(error)\\n", stderr)
    exit(1)
}
""",
            .javascript: """
const fs = require("fs");
const path = require("path");

function resolveImagePath(projectDir, entry) {
    if (!entry || typeof entry !== "object") return null;
    const rel = entry.pathToEdited || entry.pathToOriginal;
    if (!rel) return null;
    return path.resolve(projectDir, rel);
}

function copyProjectImages(folioPath, destDir) {
    const folioFile = path.resolve(folioPath);
    const projectDir = path.dirname(folioFile);
    const dest = path.resolve(destDir);

    if (!fs.existsSync(dest)) {
        fs.mkdirSync(dest, { recursive: true });
    }

    const raw = fs.readFileSync(folioFile, { encoding: "utf8" });
    const project = JSON.parse(raw);

    const images = project.images || {};
    const copied = [];

    for (const [key, entry] of Object.entries(images)) {
        const src = resolveImagePath(projectDir, entry);
        if (!src || !fs.existsSync(src)) {
            console.warn(`[WARN] Missing image for '${key}': ${src}`);
            continue;
        }
        const target = path.join(dest, path.basename(src));
        fs.copyFileSync(src, target);
        copied.push(target);
        console.log(`Copied ${key}: ${src} -> ${target}`);
    }

    return copied;
}

if (require.main === module) {
    if (process.argv.length !== 4) {
        console.error("Usage: node copy_images_flat.js project.folioDoc /path/to/output");
        process.exit(1);
    }
    copyProjectImages(process.argv[2], process.argv[3]);
}
""",
            .typescript: """
import * as fs from "fs";
import * as path from "path";

type ImageEntry = {
    pathToEdited?: string;
    pathToOriginal?: string;
    [key: string]: unknown;
};

type Project = {
    images?: Record<string, ImageEntry>;
    [key: string]: unknown;
};

function resolveImagePath(projectDir: string, entry: ImageEntry | unknown): string | null {
    if (!entry || typeof entry !== "object") return null;
    const e = entry as ImageEntry;
    const rel = e.pathToEdited || e.pathToOriginal;
    if (!rel) return null;
    return path.resolve(projectDir, rel);
}

export function copyProjectImages(folioPath: string, destDir: string): string[] {
    const folioFile = path.resolve(folioPath);
    const projectDir = path.dirname(folioFile);
    const dest = path.resolve(destDir);

    if (!fs.existsSync(dest)) {
        fs.mkdirSync(dest, { recursive: true });
    }

    const raw = fs.readFileSync(folioFile, { encoding: "utf8" });
    const project = JSON.parse(raw) as Project;

    const images = project.images ?? {};
    const copied: string[] = [];

    for (const [key, entry] of Object.entries(images)) {
        const src = resolveImagePath(projectDir, entry);
        if (!src || !fs.existsSync(src)) {
            console.warn(`[WARN] Missing image for '${key}': ${src}`);
            continue;
        }
        const target = path.join(dest, path.basename(src));
        fs.copyFileSync(src, target);
        copied.push(target);
        console.log(`Copied ${key}: ${src} -> ${target}`);
    }

    return copied;
}

if (require.main === module) {
    if (process.argv.length !== 4) {
        console.error("Usage: ts-node copy_images_flat.ts project.folioDoc /path/to/output");
        process.exit(1);
    }
    copyProjectImages(process.argv[2], process.argv[3]);
}
""",
            .ruby: """
require "json"
require "fileutils"

def resolve_image_path(project_dir, entry)
  return nil unless entry.is_a?(Hash)
  rel = entry["pathToEdited"] || entry["pathToOriginal"]
  return nil unless rel
  File.expand_path(rel, project_dir)
end

def copy_project_images(folio_path, dest_dir)
  folio_file = File.expand_path(folio_path)
  project_dir = File.dirname(folio_file)
  dest = File.expand_path(dest_dir)

  FileUtils.mkdir_p(dest)

  raw = File.read(folio_file, encoding: "UTF-8")
  project = JSON.parse(raw)

  images = project["images"] || {}
  copied = []

  images.each do |key, entry|
    src = resolve_image_path(project_dir, entry)
    unless src && File.exist?(src)
      warn "[WARN] Missing image for '#{key}': #{src}"
      next
    end
    target = File.join(dest, File.basename(src))
    FileUtils.cp(src, target)
    copied << target
    puts "Copied #{key}: #{src} -> #{target}"
  end

  copied
end

if ARGV.length != 2
  abort "Usage: ruby copy_images_flat.rb project.folioDoc /path/to/output"
end

copy_project_images(ARGV[0], ARGV[1])
""",
            .go: """
package main

import (
    "encoding/json"
    "fmt"
    "io"
    "log"
    "os"
    "path/filepath"
)

type ImageEntry struct {
    PathToEdited   string `json:"pathToEdited"`
    PathToOriginal string `json:"pathToOriginal"`
}

type Project struct {
    Images map[string]ImageEntry `json:"images"`
}

func resolveImagePath(projectDir string, entry ImageEntry) string {
    rel := entry.PathToEdited
    if rel == "" {
        rel = entry.PathToOriginal
    }
    if rel == "" {
        return ""
    }
    return filepath.Join(projectDir, rel)
}

func copyFile(src, dst string) error {
    in, err := os.Open(src)
    if err != nil {
        return err
    }
    defer in.Close()

    out, err := os.Create(dst)
    if err != nil {
        return err
    }
    defer out.Close()

    if _, err := io.Copy(out, in); err != nil {
        return err
    }

    if err := out.Sync(); err != nil {
        return err
    }
    return nil
}

func copyProjectImages(folioPath, destDir string) ([]string, error) {
    folioFile, err := filepath.Abs(folioPath)
    if err != nil {
        return nil, err
    }
    projectDir := filepath.Dir(folioFile)

    dest, err := filepath.Abs(destDir)
    if err != nil {
        return nil, err
    }
    if err := os.MkdirAll(dest, 0o755); err != nil {
        return nil, err
    }

    data, err := os.ReadFile(folioFile)
    if err != nil {
        return nil, err
    }

    var project Project
    if err := json.Unmarshal(data, &project); err != nil {
        return nil, err
    }

    copied := make([]string, 0)
    for key, entry := range project.Images {
        src := resolveImagePath(projectDir, entry)
        if src == "" {
            fmt.Fprintf(os.Stderr, "[WARN] Missing image for '%s': %s\n", key, src)
            continue
        }
        if _, err := os.Stat(src); err != nil {
            fmt.Fprintf(os.Stderr, "[WARN] Missing image for '%s': %s\n", key, src)
            continue
        }
        target := filepath.Join(dest, filepath.Base(src))
        if err := copyFile(src, target); err != nil {
            fmt.Fprintf(os.Stderr, "[WARN] Failed to copy '%s': %v\n", key, err)
            continue
        }
        copied = append(copied, target)
        fmt.Printf("Copied %s: %s -> %s\n", key, src, target)
    }

    return copied, nil
}

func main() {
    if len(os.Args) != 3 {
        fmt.Fprintln(os.Stderr, "Usage: copy_images_flat project.folioDoc /path/to/output")
        os.Exit(1)
    }

    folioPath := os.Args[1]
    destDir := os.Args[2]

    if _, err := copyProjectImages(folioPath, destDir); err != nil {
        log.Fatalf("Error copying images: %v\n", err)
    }
}
""",
        ],
        .iterateCollections: [
            .python: """
import json
import os
from pathlib import Path
from typing import Optional


IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tiff", ".svg"}
VIDEO_EXTS = {".mov", ".mp4", ".webm", ".mkv", ".avi"}
AUDIO_EXTS = {".mp3", ".wav", ".aac", ".ogg", ".m4a", ".flac"}
MODEL_EXTS = {".glb", ".gltf", ".obj", ".fbx", ".stl"}
GAME_EXTS = {".html", ".htm", ".unityweb", ".wasm"}
TEXT_EXTS = {".md", ".markdown", ".txt", ".json", ".pdf"}


def determine_collection_item_type(raw_type: Optional[str], path_val: Optional[str]) -> str:
    if raw_type and isinstance(raw_type, str):
        t = raw_type.strip().lower()
        if t in {"image", "video", "audio", "text", "game", "3d-model"}:
            return t
        if t in {"3d", "model"}:
            return "3d-model"

    if path_val:
        _, ext = os.path.splitext(path_val.lower())
        if ext in IMAGE_EXTS:
            return "image"
        if ext in VIDEO_EXTS:
            return "video"
        if ext in AUDIO_EXTS:
            return "audio"
        if ext in MODEL_EXTS:
            return "3d-model"
        if ext in GAME_EXTS:
            return "game"
        if ext in TEXT_EXTS:
            return "text"

    return "image"


def iterate_collections(folio_path: str) -> None:
    folio_file = Path(folio_path)
    with folio_file.open("r", encoding="utf-8") as f:
        project = json.load(f)

    collection = project.get("collection") or {}
    for coll_name, items in collection.items():
        if not isinstance(items, list):
            continue
        print(f"Collection '{coll_name}' ({len(items)} items):")
        for item in items:
            if not isinstance(item, dict):
                continue
            raw_type = item.get("type")
            file_path_obj = item.get("filePath")
            path_hint = None
            if isinstance(file_path_obj, dict):
                path_hint = file_path_obj.get("pathToEdited") or file_path_obj.get("pathToOriginal")

            inferred_type = determine_collection_item_type(raw_type, path_hint or item.get("label"))
            item_id = item.get("id")
            label = item.get("label")
            resource = item.get("resource") or {}
            url = resource.get("url")

            print(f"  - {item_id} [{inferred_type}] {label} -> {url}")


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python iterate_collections.py project.folioDoc")
    iterate_collections(sys.argv[1])
""",
            .swift: """
import Foundation

let imageExts: Set<String> = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tiff", ".svg"]
let videoExts: Set<String> = [".mov", ".mp4", ".webm", ".mkv", ".avi"]
let audioExts: Set<String> = [".mp3", ".wav", ".aac", ".ogg", ".m4a", ".flac"]
let modelExts: Set<String> = [".glb", ".gltf", ".obj", ".fbx", ".stl"]
let gameExts: Set<String> = [".html", ".htm", ".unityweb", ".wasm"]
let textExts: Set<String> = [".md", ".markdown", ".txt", ".json", ".pdf"]

func determineCollectionItemType(rawType: String?, pathVal: String?) -> String {
    if let rawType = rawType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        switch rawType {
        case "image", "video", "audio", "text", "game", "3d-model":
            return rawType
        case "3d", "model":
            return "3d-model"
        default:
            break
        }
    }

    if let pathVal = pathVal?.lowercased(),
       let ext = URL(fileURLWithPath: pathVal).pathExtension.isEmpty
        ? nil
        : "." + URL(fileURLWithPath: pathVal).pathExtension.lowercased() {
        if imageExts.contains(ext) { return "image" }
        if videoExts.contains(ext) { return "video" }
        if audioExts.contains(ext) { return "audio" }
        if modelExts.contains(ext) { return "3d-model" }
        if gameExts.contains(ext) { return "game" }
        if textExts.contains(ext) { return "text" }
    }

    return "image"
}

func iterateCollections(folioPath: String) throws {
    let url = URL(fileURLWithPath: folioPath)
    let data = try Data(contentsOf: url)
    let json = try JSONSerialization.jsonObject(with: data, options: [])
    guard let project = json as? [String: Any] else { return }

    let collection = project["collection"] as? [String: Any] ?? [:]
    for (collName, items) in collection {
        guard let list = items as? [Any] else { continue }
        print("Collection '\\(collName)' (\\(list.count) items):")
        for itemAny in list {
            guard let item = itemAny as? [String: Any] else { continue }
            let rawType = item["type"] as? String
            var pathHint: String? = nil
            if let filePathObj = item["filePath"] as? [String: Any] {
                pathHint = (filePathObj["pathToEdited"] as? String) ?? (filePathObj["pathToOriginal"] as? String)
            }
            let inferredType = determineCollectionItemType(rawType: rawType, pathVal: pathHint ?? (item["label"] as? String))
            let itemId = item["id"] as? String ?? "?"
            let label = item["label"] as? String ?? ""
            let resource = item["resource"] as? [String: Any] ?? [:]
            let urlStr = resource["url"] as? String ?? ""

            print("  - \\(itemId) [\\(inferredType)] \\(label) -> \\(urlStr)")
        }
    }
}

if CommandLine.arguments.count != 2 {
    fputs("Usage: iterate_collections /path/to/project.folioDoc\\n", stderr)
    exit(1)
}

do {
    try iterateCollections(folioPath: CommandLine.arguments[1])
} catch {
    fputs("Error: \\(error)\\n", stderr)
    exit(1)
}
""",
            .javascript: """
const fs = require("fs");
const path = require("path");

const IMAGE_EXTS = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tiff", ".svg"]);
const VIDEO_EXTS = new Set([".mov", ".mp4", ".webm", ".mkv", ".avi"]);
const AUDIO_EXTS = new Set([".mp3", ".wav", ".aac", ".ogg", ".m4a", ".flac"]);
const MODEL_EXTS = new Set([".glb", ".gltf", ".obj", ".fbx", ".stl"]);
const GAME_EXTS = new Set([".html", ".htm", ".unityweb", ".wasm"]);
const TEXT_EXTS = new Set([".md", ".markdown", ".txt", ".json", ".pdf"]);

function determineCollectionItemType(rawType, pathVal) {
    if (typeof rawType === "string") {
        const t = rawType.trim().toLowerCase();
        if (["image", "video", "audio", "text", "game", "3d-model"].includes(t)) return t;
        if (t === "3d" || t === "model") return "3d-model";
    }
    if (typeof pathVal === "string") {
        const lower = pathVal.toLowerCase();
        const ext = path.extname(lower);
        if (IMAGE_EXTS.has(ext)) return "image";
        if (VIDEO_EXTS.has(ext)) return "video";
        if (AUDIO_EXTS.has(ext)) return "audio";
        if (MODEL_EXTS.has(ext)) return "3d-model";
        if (GAME_EXTS.has(ext)) return "game";
        if (TEXT_EXTS.has(ext)) return "text";
    }
    return "image";
}

function iterateCollections(folioPath) {
    const folioFile = path.resolve(folioPath);
    const raw = fs.readFileSync(folioFile, { encoding: "utf8" });
    const project = JSON.parse(raw);

    const collection = project.collection || {};
    for (const [collName, items] of Object.entries(collection)) {
        if (!Array.isArray(items)) continue;
        console.log(`Collection '${collName}' (${items.length} items):`);
        for (const item of items) {
            if (!item || typeof item !== "object") continue;
            const rawType = item.type;
            let pathHint;
            const filePathObj = item.filePath;
            if (filePathObj && typeof filePathObj === "object") {
                pathHint = filePathObj.pathToEdited || filePathObj.pathToOriginal;
            }
            const inferredType = determineCollectionItemType(rawType, pathHint || item.label);
            const itemId = item.id;
            const label = item.label;
            const resource = item.resource || {};
            const url = resource.url;
            console.log(`  - ${itemId} [${inferredType}] ${label} -> ${url}`);
        }
    }
}

if (require.main === module) {
    if (process.argv.length !== 3) {
        console.error("Usage: node iterate_collections.js project.folioDoc");
        process.exit(1);
    }
    iterateCollections(process.argv[2]);
}
""",
            .typescript: """
import * as fs from "fs";
import * as path from "path";

const IMAGE_EXTS = new Set<string>([".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tiff", ".svg"]);
const VIDEO_EXTS = new Set<string>([".mov", ".mp4", ".webm", ".mkv", ".avi"]);
const AUDIO_EXTS = new Set<string>([".mp3", ".wav", ".aac", ".ogg", ".m4a", ".flac"]);
const MODEL_EXTS = new Set<string>([".glb", ".gltf", ".obj", ".fbx", ".stl"]);
const GAME_EXTS = new Set<string>([".html", ".htm", ".unityweb", ".wasm"]);
const TEXT_EXTS = new Set<string>([".md", ".markdown", ".txt", ".json", ".pdf"]);

interface FilePath {
    pathToEdited?: string;
    pathToOriginal?: string;
    [key: string]: unknown;
}

interface Resource {
    url?: string;
    [key: string]: unknown;
}

interface CollectionItem {
    id?: string;
    type?: string;
    label?: string;
    filePath?: FilePath;
    resource?: Resource;
    [key: string]: unknown;
}

interface Project {
    collection?: Record<string, CollectionItem[]>;
    [key: string]: unknown;
}

function determineCollectionItemType(rawType?: string, pathVal?: string): string {
    if (typeof rawType === "string") {
        const t = rawType.trim().toLowerCase();
        if (["image", "video", "audio", "text", "game", "3d-model"].includes(t)) {
            return t;
        }
        if (t === "3d" || t === "model") {
            return "3d-model";
        }
    }
    if (typeof pathVal === "string") {
        const lower = pathVal.toLowerCase();
        const ext = path.extname(lower);
        if (IMAGE_EXTS.has(ext)) return "image";
        if (VIDEO_EXTS.has(ext)) return "video";
        if (AUDIO_EXTS.has(ext)) return "audio";
        if (MODEL_EXTS.has(ext)) return "3d-model";
        if (GAME_EXTS.has(ext)) return "game";
        if (TEXT_EXTS.has(ext)) return "text";
    }
    return "image";
}

export function iterateCollections(folioPath: string): void {
    const folioFile = path.resolve(folioPath);
    const raw = fs.readFileSync(folioFile, { encoding: "utf8" });
    const project = JSON.parse(raw) as Project;

    const collection = project.collection ?? {};
    for (const [collName, items] of Object.entries(collection)) {
        if (!Array.isArray(items)) continue;
        console.log(`Collection '${collName}' (${items.length} items):`);
        for (const item of items) {
            if (!item || typeof item !== "object") continue;
            const rawType = item.type;
            let pathHint: string | undefined;
            const fp = item.filePath;
            if (fp && typeof fp === "object") {
                pathHint = fp.pathToEdited || fp.pathToOriginal;
            }
            const inferredType = determineCollectionItemType(rawType, pathHint ?? item.label);
            const itemId = item.id ?? "?";
            const label = item.label ?? "";
            const resource = item.resource ?? {};
            const url = resource.url ?? "";
            console.log(`  - ${itemId} [${inferredType}] ${label} -> ${url}`);
        }
    }
}

if (require.main === module) {
    if (process.argv.length !== 3) {
        console.error("Usage: ts-node iterate_collections.ts project.folioDoc");
        process.exit(1);
    }
    iterateCollections(process.argv[2]);
}
""",
            .ruby: """
require "json"
require "pathname"

IMAGE_EXTS = %w[.png .jpg .jpeg .gif .webp .bmp .tiff .svg].freeze
VIDEO_EXTS = %w[.mov .mp4 .webm .mkv .avi].freeze
AUDIO_EXTS = %w[.mp3 .wav .aac .ogg .m4a .flac].freeze
MODEL_EXTS = %w[.glb .gltf .obj .fbx .stl].freeze
GAME_EXTS  = %w[.html .htm .unityweb .wasm].freeze
TEXT_EXTS  = %w[.md .markdown .txt .json .pdf].freeze

def determine_collection_item_type(raw_type, path_val)
  if raw_type.is_a?(String)
    t = raw_type.strip.downcase
    return t if %w[image video audio text game 3d-model].include?(t)
    return "3d-model" if %w[3d model].include?(t)
  end

  if path_val.is_a?(String)
    ext = File.extname(path_val.downcase)
    return "image"    if IMAGE_EXTS.include?(ext)
    return "video"    if VIDEO_EXTS.include?(ext)
    return "audio"    if AUDIO_EXTS.include?(ext)
    return "3d-model" if MODEL_EXTS.include?(ext)
    return "game"     if GAME_EXTS.include?(ext)
    return "text"     if TEXT_EXTS.include?(ext)
  end

  "image"
end

def iterate_collections(folio_path)
  folio_file = Pathname.new(folio_path)
  project = JSON.parse(folio_file.read, symbolize_names: true)

  collection = project[:collection] || {}
  collection.each do |coll_name, items|
    next unless items.is_a?(Array)
    puts "Collection '#{coll_name}' (#{items.length} items):"
    items.each do |item|
      next unless item.is_a?(Hash)
      raw_type = item[:type]
      file_path_obj = item[:filePath]
      path_hint = if file_path_obj.is_a?(Hash)
                    file_path_obj[:pathToEdited] || file_path_obj[:pathToOriginal]
                  end
      inferred_type = determine_collection_item_type(raw_type, path_hint || item[:label])
      item_id = item[:id]
      label = item[:label]
      resource = item[:resource] || {}
      url = resource[:url]
      puts "  - #{item_id} [#{inferred_type}] #{label} -> #{url}"
    end
  end
end

if ARGV.length != 1
  abort "Usage: ruby iterate_collections.rb project.folioDoc"
end

iterate_collections(ARGV[0])
""",
            .go: """
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "os"
    "path/filepath"
    "strings"
)

var imageExts = map[string]bool{".png": true, ".jpg": true, ".jpeg": true, ".gif": true, ".webp": true, ".bmp": true, ".tiff": true, ".svg": true}
var videoExts = map[string]bool{".mov": true, ".mp4": true, ".webm": true, ".mkv": true, ".avi": true}
var audioExts = map[string]bool{".mp3": true, ".wav": true, ".aac": true, ".ogg": true, ".m4a": true, ".flac": true}
var modelExts = map[string]bool{".glb": true, ".gltf": true, ".obj": true, ".fbx": true, ".stl": true}
var gameExts = map[string]bool{".html": true, ".htm": true, ".unityweb": true, ".wasm": true}
var textExts = map[string]bool{".md": true, ".markdown": true, ".txt": true, ".json": true, ".pdf": true}

type FilePath struct {
    PathToEdited   string `json:"pathToEdited"`
    PathToOriginal string `json:"pathToOriginal"`
}

type Resource struct {
    URL string `json:"url"`
}

type CollectionItem struct {
    ID       string    `json:"id"`
    Type     string    `json:"type"`
    Label    string    `json:"label"`
    FilePath FilePath  `json:"filePath"`
    Resource Resource  `json:"resource"`
}

type Project struct {
    Collection map[string][]CollectionItem `json:"collection"`
}

func determineCollectionItemType(rawType, pathVal string) string {
    t := strings.TrimSpace(strings.ToLower(rawType))
    switch t {
    case "image", "video", "audio", "text", "game", "3d-model":
        return t
    case "3d", "model":
        return "3d-model"
    }

    if pathVal != "" {
        ext := strings.ToLower(filepath.Ext(pathVal))
        if imageExts[ext] {
            return "image"
        }
        if videoExts[ext] {
            return "video"
        }
        if audioExts[ext] {
            return "audio"
        }
        if modelExts[ext] {
            return "3d-model"
        }
        if gameExts[ext] {
            return "game"
        }
        if textExts[ext] {
            return "text"
        }
    }

    return "image"
}

func iterateCollections(folioPath string) error {
    data, err := os.ReadFile(folioPath)
    if err != nil {
        return err
    }

    var project Project
    if err := json.Unmarshal(data, &project); err != nil {
        return err
    }

    for collName, items := range project.Collection {
        fmt.Printf("Collection '%s' (%d items):\n", collName, len(items))
        for _, item := range items {
            pathHint := item.FilePath.PathToEdited
            if pathHint == "" {
                pathHint = item.FilePath.PathToOriginal
            }
            inferredType := determineCollectionItemType(item.Type, pathHint)
            fmt.Printf("  - %s [%s] %s -> %s\n", item.ID, inferredType, item.Label, item.Resource.URL)
        }
    }

    return nil
}

func main() {
    if len(os.Args) != 2 {
        fmt.Fprintln(os.Stderr, "Usage: iterate_collections project.folioDoc")
        os.Exit(1)
    }
    if err := iterateCollections(os.Args[1]); err != nil {
        log.Fatalf("Error: %v\n", err)
    }
}
""",
        ],
        .listURLs: [
            .python: """
import json
from pathlib import Path

def find_urls(obj, results):
    if isinstance(obj, dict):
        for v in obj.values():
            find_urls(v, results)
    elif isinstance(obj, list):
        for v in obj:
            find_urls(v, results)
    elif isinstance(obj, str):
        if obj.startswith("http://") or obj.startswith("https://"):
            results.add(obj)

def list_urls(folio_path: str):
    data = json.loads(Path(folio_path).read_text(encoding="utf-8"))
    results = set()
    find_urls(data, results)
    for url in sorted(results):
        print(url)

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python list_urls.py project.folioDoc")
    list_urls(sys.argv[1])
""",
            .swift: """
import Foundation

func findURLs(_ value: Any, results: inout Set<String>) {
    if let dict = value as? [String: Any] {
        for v in dict.values { findURLs(v, results: &results) }
    } else if let array = value as? [Any] {
        for v in array { findURLs(v, results: &results) }
    } else if let str = value as? String {
        if str.hasPrefix("http://") || str.hasPrefix("https://") {
            results.insert(str)
        }
    }
}

func listURLs(folioPath: String) throws {
    let url = URL(fileURLWithPath: folioPath)
    let data = try Data(contentsOf: url)
    let json = try JSONSerialization.jsonObject(with: data)

    var results = Set<String>()
    findURLs(json, results: &results)
    for url in results.sorted() { print(url) }
}

if CommandLine.arguments.count != 2 {
    fputs("Usage: list_urls project.folioDoc\n", stderr)
    exit(1)
}

do { try listURLs(folioPath: CommandLine.arguments[1]) }
catch {
    fputs("Error: \\(error)\n", stderr)
    exit(1)
}
""",
            .javascript: """
const fs = require("fs");
const path = require("path");

function findURLs(obj, results) {
    if (Array.isArray(obj)) {
        for (const v of obj) findURLs(v, results);
    } else if (obj && typeof obj === "object") {
        for (const v of Object.values(obj)) findURLs(v, results);
    } else if (typeof obj === "string") {
        if (obj.startsWith("http://") || obj.startsWith("https://")) {
            results.add(obj);
        }
    }
}

function listURLs(folioPath) {
    const raw = fs.readFileSync(path.resolve(folioPath), "utf8");
    const project = JSON.parse(raw);
    const results = new Set();
    findURLs(project, results);
    [...results].sort().forEach(u => console.log(u));
}

if (require.main === module) {
    if (process.argv.length !== 3) {
        console.error("Usage: node list_urls.js project.folioDoc");
        process.exit(1);
    }
    listURLs(process.argv[2]);
}
""",
            .typescript: """
import * as fs from "fs";
import * as path from "path";

function findURLs(obj: unknown, results: Set<string>): void {
    if (Array.isArray(obj)) {
        for (const v of obj) findURLs(v, results);
    } else if (obj && typeof obj === "object") {
        for (const v of Object.values(obj as Record<string, unknown>)) findURLs(v, results);
    } else if (typeof obj === "string") {
        if (obj.startsWith("http://") || obj.startsWith("https://")) results.add(obj);
    }
}

export function listURLs(folioPath: string): void {
    const raw = fs.readFileSync(path.resolve(folioPath), "utf8");
    const project = JSON.parse(raw);
    const results = new Set<string>();
    findURLs(project, results);
    [...results].sort().forEach(u => console.log(u));
}

if (require.main === module) {
    if (process.argv.length !== 3) {
        console.error("Usage: ts-node list_urls.ts project.folioDoc");
        process.exit(1);
    }
    listURLs(process.argv[2]);
}
""",
            .ruby: """
require "json"

def find_urls(obj, results)
  case obj
  when Hash
    obj.values.each { |v| find_urls(v, results) }
  when Array
    obj.each { |v| find_urls(v, results) }
  when String
    results << obj if obj.start_with?("http://", "https://")
  end
end

def list_urls(folio_path)
  project = JSON.parse(File.read(folio_path), symbolize_names: false)
  results = []
  find_urls(project, results)
  results.uniq.sort.each { |u| puts u }
end

if ARGV.length != 1
  abort "Usage: ruby list_urls.rb project.folioDoc"
end

list_urls(ARGV[0])
""",
            .go: """
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "os"
    "sort"
)

func findURLs(obj interface{}, results map[string]bool) {
    switch v := obj.(type) {
    case map[string]interface{}:
        for _, val := range v {
            findURLs(val, results)
        }
    case []interface{}:
        for _, val := range v {
            findURLs(val, results)
        }
    case string:
        if len(v) > 7 && (v[:7] == "http://" || v[:8] == "https://") {
            results[v] = true
        }
    }
}

func listURLs(folioPath string) error {
    data, err := os.ReadFile(folioPath)
    if err != nil {
        return err
    }
    var project interface{}
    if err := json.Unmarshal(data, &project); err != nil {
        return err
    }

    results := map[string]bool{}
    findURLs(project, results)

    urls := make([]string, 0, len(results))
    for u := range results {
        urls = append(urls, u)
    }
    sort.Strings(urls)
    for _, u := range urls {
        fmt.Println(u)
    }
    return nil
}

func main() {
    if len(os.Args) != 2 {
        fmt.Fprintln(os.Stderr, "Usage: list_urls project.folioDoc")
        os.Exit(1)
    }
    if err := listURLs(os.Args[1]); err != nil {
        log.Fatalf("Error: %v", err)
    }
}
""",
        ],
        .externalImageHosts: [
            .python: """
import json
from pathlib import Path
from urllib.parse import urlparse
from typing import Optional


def extract_external_image_hostnames(projects: list[dict]) -> set[str]:
    hosts: set[str] = set()

    def extract_hostname(url_str: str) -> Optional[str]:
        if not isinstance(url_str, str):
            return None
        parsed = urlparse(url_str)
        return parsed.hostname

    def scan_value(value):
        if isinstance(value, dict):
            for k, v in value.items():
                if isinstance(v, str) and (v.startswith("http://") or v.startswith("https://")):
                    host = extract_hostname(v)
                    if host:
                        hosts.add(host)
                scan_value(v)
        elif isinstance(value, list):
            for item in value:
                scan_value(item)
        elif isinstance(value, str):
            if value.startswith("http://") or value.startswith("https://"):
                host = extract_hostname(value)
                if host:
                    hosts.add(host)

    for proj in projects:
        scan_value(proj)

    return hosts


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        raise SystemExit("Usage: python image_hosts.py project1.folioDoc [project2.folioDoc ...]")
    loaded = []
    for arg in sys.argv[1:]:
        with Path(arg).open("r", encoding="utf-8") as f:
            loaded.append(json.load(f))
    hosts = extract_external_image_hostnames(loaded)
    for h in sorted(hosts):
        print(h)
""",
            .swift: """
import Foundation

func extractExternalImageHostnames(projects: [[String: Any]]) -> Set<String> {
    var hosts = Set<String>()

    func extractHostname(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        return host
    }

    func scanValue(_ value: Any) {
        if let dict = value as? [String: Any] {
            for (_, v) in dict {
                if let s = v as? String,
                   s.hasPrefix("http://") || s.hasPrefix("https://"),
                   let host = extractHostname(from: s) {
                    hosts.insert(host)
                }
                scanValue(v)
            }
        } else if let array = value as? [Any] {
            for v in array {
                scanValue(v)
            }
        } else if let s = value as? String {
            if s.hasPrefix("http://") || s.hasPrefix("https://"),
               let host = extractHostname(from: s) {
                hosts.insert(host)
            }
        }
    }

    for project in projects {
        scanValue(project)
    }

    return hosts
}

func loadProject(at path: String) throws -> [String: Any] {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    let json = try JSONSerialization.jsonObject(with: data, options: [])
    return json as? [String: Any] ?? [:]
}

if CommandLine.arguments.count < 2 {
    fputs("Usage: image_hosts project1.folioDoc [project2.folioDoc ...]\\n", stderr)
    exit(1)
}

do {
    var projects: [[String: Any]] = []
    for arg in CommandLine.arguments.dropFirst() {
        projects.append(try loadProject(at: arg))
    }
    let hosts = extractExternalImageHostnames(projects: projects)
    for host in hosts.sorted() {
        print(host)
    }
} catch {
    fputs("Error: \\(error)\\n", stderr)
    exit(1)
}
""",
            .javascript: """
const fs = require("fs");
const path = require("path");
const { URL } = require("url");

function extractExternalImageHostnames(projects) {
    const hosts = new Set();

    function extractHostname(urlStr) {
        try {
            const u = new URL(urlStr);
            return u.hostname || null;
        } catch {
            return null;
        }
    }

    function scanValue(value) {
        if (Array.isArray(value)) {
            for (const v of value) scanValue(v);
        } else if (value && typeof value === "object") {
            for (const v of Object.values(value)) {
                if (typeof v === "string" && (v.startsWith("http://") || v.startsWith("https://"))) {
                    const host = extractHostname(v);
                    if (host) hosts.add(host);
                }
                scanValue(v);
            }
        } else if (typeof value === "string") {
            if (value.startsWith("http://") || value.startsWith("https://")) {
                const host = extractHostname(value);
                if (host) hosts.add(host);
            }
        }
    }

    for (const proj of projects) {
        scanValue(proj);
    }

    return hosts;
}

function loadProject(filePath) {
    const abs = path.resolve(filePath);
    const raw = fs.readFileSync(abs, { encoding: "utf8" });
    return JSON.parse(raw);
}

if (require.main === module) {
    if (process.argv.length < 3) {
        console.error("Usage: node image_hosts.js project1.folioDoc [project2.folioDoc ...]");
        process.exit(1);
    }

    const projects = process.argv.slice(2).map(loadProject);
    const hosts = extractExternalImageHostnames(projects);
    [...hosts].sort().forEach(h => console.log(h));
}
""",
            .typescript: """
import * as fs from "fs";
import * as path from "path";
import { URL } from "url";

type JSONValue = string | number | boolean | null | JSONObject | JSONArray;
interface JSONObject {
    [key: string]: JSONValue;
}
interface JSONArray extends Array<JSONValue> {}

function extractExternalImageHostnames(projects: JSONObject[]): Set<string> {
    const hosts = new Set<string>();

    function extractHostname(urlStr: string): string | null {
        try {
            const u = new URL(urlStr);
            return u.hostname || null;
        } catch {
            return null;
        }
    }

    function scanValue(value: JSONValue): void {
        if (Array.isArray(value)) {
            for (const v of value) scanValue(v);
        } else if (value && typeof value === "object") {
            for (const v of Object.values(value as JSONObject)) {
                if (typeof v === "string" && (v.startsWith("http://") || v.startsWith("https://"))) {
                    const host = extractHostname(v);
                    if (host) hosts.add(host);
                }
                scanValue(v as JSONValue);
            }
        } else if (typeof value === "string") {
            if (value.startsWith("http://") || value.startsWith("https://")) {
                const host = extractHostname(value);
                if (host) hosts.add(host);
            }
        }
    }

    for (const proj of projects) {
        scanValue(proj);
    }

    return hosts;
}

function loadProject(filePath: string): JSONObject {
    const abs = path.resolve(filePath);
    const raw = fs.readFileSync(abs, { encoding: "utf8" });
    return JSON.parse(raw) as JSONObject;
}

if (require.main === module) {
    if (process.argv.length < 3) {
        console.error("Usage: ts-node image_hosts.ts project1.folioDoc [project2.folioDoc ...]");
        process.exit(1);
    }

    const projects = process.argv.slice(2).map(loadProject);
    const hosts = extractExternalImageHostnames(projects);
    [...hosts].sort().forEach(h => console.log(h));
}
""",
            .ruby: """
require "json"
require "uri"

def extract_external_image_hostnames(projects)
  hosts = []

  extract_hostname = lambda do |url_str|
    begin
      uri = URI.parse(url_str)
      uri.host
    rescue URI::InvalidURIError
      nil
    end
  end

  scan_value = lambda do |value|
    case value
    when Hash
      value.each_value do |v|
        if v.is_a?(String) && (v.start_with?("http://") || v.start_with?("https://"))
          host = extract_hostname.call(v)
          hosts << host if host
        end
        scan_value.call(v)
      end
    when Array
      value.each { |v| scan_value.call(v) }
    when String
      if value.start_with?("http://", "https://")
        host = extract_hostname.call(value)
        hosts << host if host
      end
    end
  end

  projects.each { |proj| scan_value.call(proj) }
  hosts.uniq
end

if ARGV.empty?
  abort "Usage: ruby image_hosts.rb project1.folioDoc [project2.folioDoc ...]"
end

projects = ARGV.map do |path|
  JSON.parse(File.read(path), symbolize_names: false)
end

hosts = extract_external_image_hostnames(projects)
hosts.sort.each { |h| puts h }
""",
            .go: """
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/url"
    "os"
    "sort"
)

func extractExternalImageHostnames(projects []interface{}) []string {
    hosts := map[string]bool{}

    var scanValue func(v interface{})
    scanValue = func(v interface{}) {
        switch val := v.(type) {
        case map[string]interface{}:
            for _, inner := range val {
                if s, ok := inner.(string); ok {
                    if len(s) > 7 && (s[:7] == "http://" || s[:8] == "https://") {
                        if u, err := url.Parse(s); err == nil && u.Hostname() != "" {
                            hosts[u.Hostname()] = true
                        }
                    }
                }
                scanValue(inner)
            }
        case []interface{}:
            for _, inner := range val {
                scanValue(inner)
            }
        case string:
            if len(val) > 7 && (val[:7] == "http://" || val[:8] == "https://") {
                if u, err := url.Parse(val); err == nil && u.Hostname() != "" {
                    hosts[u.Hostname()] = true
                }
            }
        }
    }

    for _, proj := range projects {
        scanValue(proj)
    }

    out := make([]string, 0, len(hosts))
    for h := range hosts {
        out = append(out, h)
    }
    sort.Strings(out)
    return out
}

func loadProject(path string) (interface{}, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    var proj interface{}
    if err := json.Unmarshal(data, &proj); err != nil {
        return nil, err
    }
    return proj, nil
}

func main() {
    if len(os.Args) < 2 {
        fmt.Fprintln(os.Stderr, "Usage: image_hosts project1.folioDoc [project2.folioDoc ...]")
        os.Exit(1)
    }

    var projects []interface{}
    for _, p := range os.Args[1:] {
        proj, err := loadProject(p)
        if err != nil {
            log.Fatalf("Error loading %s: %v\n", p, err)
        }
        projects = append(projects, proj)
    }

    hosts := extractExternalImageHostnames(projects)
    for _, h := range hosts {
        fmt.Println(h)
    }
}
""",
        ],
        .batchProcess: [
            .python: """
import json
from pathlib import Path
from typing import Callable, Iterable


def iter_folio_files(root: str, extensions: Iterable[str] = (".folio", ".folioDoc")):
    root_path = Path(root)
    for p in root_path.rglob("*"):
        if p.suffix in extensions:
            yield p


def process_project(path: Path, handler: Callable[[Path, dict], None]) -> None:
    with path.open("r", encoding="utf-8") as f:
        project = json.load(f)
    handler(path, project)


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        raise SystemExit("Usage: python batch_process_projects.py /path/to/root")

    def example_handler(path: Path, project: dict) -> None:
        print(f"{path}: {project.get('title') or project.get('name')}")

    for folio_file in iter_folio_files(sys.argv[1]):
        process_project(folio_file, example_handler)
""",
            .swift: """
import Foundation

func iterFolioFiles(root: String, extensions: [String] = [".folio", ".folioDoc"]) -> [URL] {
    let rootURL = URL(fileURLWithPath: root)
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: nil) else {
        return []
    }

    var result: [URL] = []
    for case let fileURL as URL in enumerator {
        let ext = "." + fileURL.pathExtension
        if extensions.contains(ext) {
            result.append(fileURL)
        }
    }
    return result
}

func processProject(at url: URL, handler: (URL, [String: Any]) -> Void) {
    do {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        let project = json as? [String: Any] ?? [:]
        handler(url, project)
    } catch {
        fputs("Failed to read \\(url.path): \\(error)\\n", stderr)
    }
}

if CommandLine.arguments.count != 2 {
    fputs("Usage: batch_process_projects /path/to/root\\n", stderr)
    exit(1)
}

let root = CommandLine.arguments[1]
let files = iterFolioFiles(root: root)

for url in files {
    processProject(at: url) { fileURL, project in
        let title = project["title"] ?? project["name"] ?? "nil"
        print("\\(fileURL.path): \\(title)")
    }
}
""",
            .javascript: """
const fs = require("fs");
const path = require("path");

function iterFolioFiles(root, extensions = [".folio", ".folioDoc"]) {
    const result = [];
    function walk(dir) {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
            const full = path.join(dir, entry.name);
            if (entry.isDirectory()) {
                walk(full);
            } else {
                const ext = path.extname(entry.name);
                if (extensions.includes(ext)) {
                    result.push(full);
                }
            }
        }
    }
    walk(path.resolve(root));
    return result;
}

function processProject(filePath, handler) {
    const raw = fs.readFileSync(filePath, { encoding: "utf8" });
    const project = JSON.parse(raw);
    handler(filePath, project);
}

if (require.main === module) {
    if (process.argv.length !== 3) {
        console.error("Usage: node batch_process_projects.js /path/to/root");
        process.exit(1);
    }

    const root = process.argv[2];
    const files = iterFolioFiles(root);

    function exampleHandler(filePath, project) {
        const title = project.title || project.name;
        console.log(`${filePath}: ${title}`);
    }

    for (const filePath of files) {
        processProject(filePath, exampleHandler);
    }
}
""",
            .typescript: """
import * as fs from "fs";
import * as path from "path";

type Project = Record<string, unknown>;

function iterFolioFiles(root: string, extensions: string[] = [".folio", ".folioDoc"]): string[] {
    const result: string[] = [];

    function walk(dir: string): void {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
            const full = path.join(dir, entry.name);
            if (entry.isDirectory()) {
                walk(full);
            } else {
                const ext = path.extname(entry.name);
                if (extensions.includes(ext)) {
                    result.push(full);
                }
            }
        }
    }

    walk(path.resolve(root));
    return result;
}

function processProject(filePath: string, handler: (filePath: string, project: Project) => void): void {
    const raw = fs.readFileSync(filePath, { encoding: "utf8" });
    const project = JSON.parse(raw) as Project;
    handler(filePath, project);
}

if (require.main === module) {
    if (process.argv.length !== 3) {
        console.error("Usage: ts-node batch_process_projects.ts /path/to/root");
        process.exit(1);
    }

    const root = process.argv[2];
    const files = iterFolioFiles(root);

    function exampleHandler(filePath: string, project: Project): void {
        const title = (project["title"] as string) || (project["name"] as string);
        console.log(`${filePath}: ${title}`);
    }

    for (const filePath of files) {
        processProject(filePath, exampleHandler);
    }
}
""",
            .ruby: """
require "json"
require "find"

def iter_folio_files(root, extensions = [".folio", ".folioDoc"])
  paths = []
  Find.find(root) do |path|
    next unless File.file?(path)
    ext = File.extname(path)
    paths << path if extensions.include?(ext)
  end
  paths
end

def process_project(path)
  data = File.read(path, encoding: "UTF-8")
  project = JSON.parse(data)
  yield(path, project)
end

if ARGV.length != 1
  abort "Usage: ruby batch_process_projects.rb /path/to/root"
end

root = ARGV[0]
files = iter_folio_files(root)

files.each do |path|
  process_project(path) do |file_path, project|
    title = project["title"] || project["name"]
    puts "#{file_path}: #{title}"
  end
end
""",
            .go: """
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "os"
    "path/filepath"
)

type Project map[string]interface{}

func iterFolioFiles(root string, extensions []string) ([]string, error) {
    var files []string
    err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
        if err != nil {
            return err
        }
        if info.IsDir() {
            return nil
        }
        ext := filepath.Ext(path)
        for _, e := range extensions {
            if ext == e {
                files = append(files, path)
                break
            }
        }
        return nil
    })
    return files, err
}

func processProject(path string, handler func(string, Project)) error {
    data, err := os.ReadFile(path)
    if err != nil {
        return err
    }
    var proj Project
    if err := json.Unmarshal(data, &proj); err != nil {
        return err
    }
    handler(path, proj)
    return nil
}

func main() {
    if len(os.Args) != 2 {
        fmt.Fprintln(os.Stderr, "Usage: batch_process_projects /path/to/root")
        os.Exit(1)
    }

    root := os.Args[1]
    files, err := iterFolioFiles(root, []string{".folio", ".folioDoc"})
    if err != nil {
        log.Fatalf("Error walking root: %v\n", err)
    }

    handler := func(path string, project Project) {
        title := ""
        if v, ok := project["title"].(string); ok {
            title = v
        } else if v, ok := project["name"].(string); ok {
            title = v
        }
        fmt.Printf("%s: %s\n", path, title)
    }

    for _, f := range files {
        if err := processProject(f, handler); err != nil {
            log.Printf("Error processing %s: %v\n", f, err)
        }
    }
}
""",
        ],
    ]

    // MARK: Loading

    /// Loads all snippets for a given language by pairing metadata with code read from the bundle.
    static func loadedSnippets(for language: ProgrammingLanguage, bundle: Bundle = .main) -> [LoadedCodeSnippet] {
        metadata.map { meta in
            let code = codeByLanguage[meta.id]?[language]
                ?? codeByLanguage[meta.id]?[.python]
                ?? missingCodePlaceholder(meta: meta, language: language)

            return LoadedCodeSnippet(
                id: meta.id,
                title: meta.title,
                summary: meta.summary,
                inputDescription: meta.inputDescription,
                outputDescription: meta.outputDescription,
                notes: meta.notes,
                code: code
            )
        }
    }

    private static func missingCodePlaceholder(meta: CodeSnippet, language: ProgrammingLanguage) -> String {
        """
        // Code not available for \(language.displayName).
        // No in-memory snippet has been defined for id: \(meta.id.rawValue).
        // Add an entry to CodeSnippetLibrary.codeByLanguage to provide an example.
        """
    }
}
