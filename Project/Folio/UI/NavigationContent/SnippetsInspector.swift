//
//  SnippetsInspector.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import SwiftUI

/// Inspector panel for Snippets tab - shows language info and settings
struct SnippetsInspector: View {
    @Binding var selectedLanguage: ProgrammingLanguage?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Language Info")
                    .font(.headline)
                
                if let language = selectedLanguage {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Language")
                            .font(.subheadline)
                            .bold()
                        Text(language.displayName)
                            .font(.body)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("File Extension")
                            .font(.subheadline)
                            .bold()
                        Text(language.fileExtension)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Switch Language")
                            .font(.subheadline)
                            .bold()
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(ProgrammingLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang as ProgrammingLanguage?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } else {
                    Text("No language selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

