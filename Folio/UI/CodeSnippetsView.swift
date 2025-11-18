//
//  CodeSnippetsView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/13/25.
//

import SwiftUI
import AppKit


struct CodeSnippetsView: View {
    var programmingLanguage: ProgrammingLanguage

    @State private var loadedSnippets: [LoadedCodeSnippet] = []

    var body: some View {
    
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    headerSection

                    ForEach(loadedSnippets) { snippet in
                        snippetCard(snippet)
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

                    //footerSection
                }
                .padding()
            }
            .navigationTitle("Code Snippets")
            .onAppear { load() }
            .onChange(of: programmingLanguage) {
                load()
            }
        
    }

    private func load(bundle: Bundle = .main) {
        loadedSnippets = CodeSnippetLibrary.loadedSnippets(for: programmingLanguage, bundle: bundle)
    }

    // MARK: Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Folio Code Snippets")
                .font(.title2.bold())
                .foregroundColor(.primary)

            Text("Language: \(programmingLanguage.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Copy-paste-ready examples for working with your Folio documents: loading, summarizing, exporting metadata, copying images, iterating collections, extracting URLs, and batch-processing many projects.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func snippetCard(_ snippet: LoadedCodeSnippet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snippet.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(snippet.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            infoRow(title: "Input", text: snippet.inputDescription)
            infoRow(title: "Output", text: snippet.outputDescription)
            infoRow(title: "Notes", text: snippet.notes)

            codeBlock(snippet.code)
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

//    private var footerSection: some View {
//        VStack(alignment: .leading, spacing: 6) {
//            Text("Extending to other languages")
//                .font(.subheadline).bold()
//
//            Text("These examples are currently implemented for Python. To add more languages, add Markdown files using the same snippet IDs per language under CodeSnippets/<language> in your app bundle.")
//                .font(.footnote)
//              
//        }
//        .padding(.top, 8)
//    }

    // MARK: Copy helper

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
     
    }
}

// MARK: - Preview

struct CodeSnippetsView_Previews: PreviewProvider {
    static var previews: some View {
        CodeSnippetsView(programmingLanguage: .python)
    }
}
