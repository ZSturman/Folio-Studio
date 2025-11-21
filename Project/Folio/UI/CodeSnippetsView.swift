//
//  CodeSnippetsView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/13/25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

enum PathExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON"
    case csv = "CSV"
    case txt = "TXT"
    
    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
}

enum SnippetMode: String, CaseIterable, Identifiable {
    case single = "Single Folio"
    case multiple = "Multiple Folios"
    
    var id: String { rawValue }
}

struct CodeSnippetsView: View {
    @Environment(\.modelContext) private var modelContext
    
    var programmingLanguage: ProgrammingLanguage
    @Binding var selectedSnippetID: CodeSnippetID?

    @State private var loadedSnippets: [LoadedCodeSnippet] = []
    @State private var showExportSheet = false
    @State private var selectedFormat: PathExportFormat = .json
    @State private var snippetMode: SnippetMode = .single
    @State private var exportStatus: String?
    @State private var exportPreview: String = ""
    @State private var previewProjectCount: Int = 0
    @State private var totalProjectCount: Int = 0

    var body: some View {
        if programmingLanguage != .python {
            comingSoonView
        } else {
            pythonSnippetsView
        }
    }
    
    // MARK: - Coming Soon View
    
    private var comingSoonView: some View {
        VStack(spacing: 20) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Coming Soon")
                .font(.title.bold())
            
            Text("\(programmingLanguage.displayName) snippets are under development.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Python snippets are currently available. Check back soon for \(programmingLanguage.displayName) examples!")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Code Snippets")
    }
    
    // MARK: - Python Snippets View
    
    private var pythonSnippetsView: some View {
        ScrollView {
            if let selectedID = selectedSnippetID,
               let snippet = loadedSnippets.first(where: { $0.id == selectedID }) {
                // Show selected snippet
                VStack(alignment: .leading, spacing: 24) {
                    snippetDetailView(snippet)
                }
                .padding()
            } else {
                // Show overview when no snippet selected
                VStack(spacing: 24) {
                    headerSection
                    
                    VStack(spacing: 12) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("Select a Function")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Choose a snippet from the sidebar to view code examples")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
            }
        }
        .navigationTitle("Code Snippets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showExportSheet = true
                } label: {
                    Label("Export Folio Paths", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            exportPathsSheet
        }
        .onAppear { load() }
        .onChange(of: programmingLanguage) {
            load()
        }
    }
    
    private func snippetDetailView(_ snippet: LoadedCodeSnippet) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snippet.title)
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text(snippet.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            infoRow(title: "Input", text: snippet.inputDescription)
            infoRow(title: "Output", text: snippet.outputDescription)
            infoRow(title: "Notes", text: snippet.notes)

            codeBlock(snippet.code)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Export Sheet
    
    private var exportPathsSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Export Folio Paths")
                .font(.title2.bold())
            
            Text("Export a list of all Folio project file paths from your library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Export Format")
                    .font(.headline)
                
                Picker("Format", selection: $selectedFormat) {
                    ForEach(PathExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Preview section
            if totalProjectCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Preview")
                            .font(.headline)
                        Spacer()
                        Text("Showing first \(previewProjectCount) of \(totalProjectCount) projects")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    ScrollView {
                        Text(exportPreview)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 200)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator)
                    )
                }
            }
            
            if let status = exportStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(status.contains("Error") ? .red : .green)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(status.contains("Error") ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    )
            }
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    showExportSheet = false
                    exportStatus = nil
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Export All") {
                    exportFolioPaths()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 550)
        .task(id: selectedFormat) {
            await generatePreview()
        }
        .onAppear {
            Task {
                await generatePreview()
            }
        }
    }

    private func load(bundle: Bundle = .main) {
        loadedSnippets = CodeSnippetLibrary.loadedSnippets(for: programmingLanguage, bundle: bundle, mode: snippetMode)
    }

    // MARK: Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Folio Code Snippets")
                .font(.title2.bold())
                .foregroundColor(.primary)

            Text("Language: \(programmingLanguage.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Snippet Mode")
                    .font(.subheadline.bold())
                
                Picker("Mode", selection: $snippetMode) {
                    ForEach(SnippetMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: snippetMode) {
                    load()
                }
                
                Text(snippetMode == .single 
                    ? "Snippets show examples for working with a single Folio document."
                    : "Snippets show examples for batch processing multiple Folio documents.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )

            Text("Select a function from the sidebar to view copy-paste-ready code examples.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func infoRow(title: String, text: String?) -> some View {
        Group {
            if let text, !text.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text("\(title):")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)

                    Text(text)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    private func codeBlock(_ code: String) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            ZStack(alignment: .topTrailing) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )

                Button {
                    copyToPasteboard(code)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
        .frame(maxHeight: 260)
    }

    // MARK: Copy helper

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    // MARK: - Export Folio Paths
    
    private func generatePreview() async {
        // Debounce by waiting 300ms
        try? await Task.sleep(for: .milliseconds(300))
        
        // Fetch all ProjectDocs from SwiftData
        let descriptor = FetchDescriptor<ProjectDoc>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        
        guard let projects = try? modelContext.fetch(descriptor) else {
            await MainActor.run {
                exportPreview = "Error: Could not fetch projects"
                totalProjectCount = 0
                previewProjectCount = 0
            }
            return
        }
        
        // Validate file paths exist
        let validProjects = projects.filter { project in
            FileManager.default.fileExists(atPath: project.filePath)
        }
        
        await MainActor.run {
            totalProjectCount = validProjects.count
        }
        
        guard !validProjects.isEmpty else {
            await MainActor.run {
                exportPreview = "No projects found in library"
                previewProjectCount = 0
            }
            return
        }
        
        // Limit preview to first 50 projects
        let previewProjects = Array(validProjects.prefix(50))
        
        // Generate preview content
        let content: String
        switch selectedFormat {
        case .json:
            content = generateJSONExport(projects: previewProjects)
        case .csv:
            content = generateCSVExport(projects: previewProjects)
        case .txt:
            content = generateTXTExport(projects: previewProjects)
        }
        
        await MainActor.run {
            exportPreview = content
            previewProjectCount = previewProjects.count
        }
    }
    
    private func exportFolioPaths() {
        // Fetch all ProjectDocs from SwiftData
        let descriptor = FetchDescriptor<ProjectDoc>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        
        guard let projects = try? modelContext.fetch(descriptor) else {
            exportStatus = "Error: Could not fetch projects from database"
            return
        }
        
        if projects.isEmpty {
            exportStatus = "No projects found in library"
            return
        }
        
        // Validate file paths exist
        let validProjects = projects.filter { project in
            FileManager.default.fileExists(atPath: project.filePath)
        }
        
        let invalidCount = projects.count - validProjects.count
        
        // Generate export content
        let content: String
        switch selectedFormat {
        case .json:
            content = generateJSONExport(projects: validProjects)
        case .csv:
            content = generateCSVExport(projects: validProjects)
        case .txt:
            content = generateTXTExport(projects: validProjects)
        }
        
        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: selectedFormat.fileExtension) ?? .plainText]
        savePanel.nameFieldStringValue = "folio-paths.\(selectedFormat.fileExtension)"
        savePanel.title = "Export Folio Paths"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    let suffix = invalidCount > 0 ? " (\(invalidCount) invalid paths excluded)" : ""
                    exportStatus = "Successfully exported \(validProjects.count) project paths\(suffix)"
                } catch {
                    exportStatus = "Error: Failed to write file - \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func generateJSONExport(projects: [ProjectDoc]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let exportData = projects.map { project in
            [
                "id": project.id.uuidString,
                "title": project.title,
                "filePath": project.filePath,
                "domain": project.domain?.name ?? "",
                "category": project.category?.name ?? "",
                "isPublic": project.isPublic ? "true" : "false",
                "updatedAt": ISO8601DateFormatter().string(from: project.updatedAt)
            ]
        }
        
        if let data = try? encoder.encode(exportData),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return "[]"
    }
    
    private func generateCSVExport(projects: [ProjectDoc]) -> String {
        var lines = ["ID,Title,FilePath,Domain,Category,IsPublic,UpdatedAt"]
        
        for project in projects {
            let domain = project.domain?.name ?? ""
            let category = project.category?.name ?? ""
            let updatedAt = ISO8601DateFormatter().string(from: project.updatedAt)
            
            // Escape CSV fields
            let title = escapeCSV(project.title)
            let filePath = escapeCSV(project.filePath)
            
            lines.append("\(project.id.uuidString),\(title),\(filePath),\(escapeCSV(domain)),\(escapeCSV(category)),\(project.isPublic),\(updatedAt)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func generateTXTExport(projects: [ProjectDoc]) -> String {
        var lines = ["# Folio Project Paths", ""]
        
        for project in projects {
            lines.append("## \(project.title)")
            lines.append("Path: \(project.filePath)")
            if let domain = project.domain?.name {
                lines.append("Domain: \(domain)")
            }
            if let category = project.category?.name {
                lines.append("Category: \(category)")
            }
            lines.append("Visibility: \(project.isPublic ? "Public" : "Private")")
            lines.append("Updated: \(ISO8601DateFormatter().string(from: project.updatedAt))")
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

#Preview {
    CodeSnippetsView(
        programmingLanguage: .python,
        selectedSnippetID: .constant(.loadSummary)
    )
    .modelContainer(for: [ProjectDoc.self], inMemory: true)
}
