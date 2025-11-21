//
//  JSONDocumentViewer.swift
//  Folio
//
//  Created by Zachary Sturman on 11/19/25.
//

import SwiftUI

struct JSONDocumentViewer: View {
    let document: FolioDocument
    @State private var jsonString: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Document JSON")
                    .font(.title2.bold())
                Spacer()
                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // JSON Content
            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
                    .padding()
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(jsonString)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            generateJSON()
        }
    }
    
    private func generateJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(document)
            if let string = String(data: data, encoding: .utf8) {
                jsonString = string
            } else {
                errorMessage = "Failed to convert JSON data to string"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)
    }
}
