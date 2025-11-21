//
//  ContentInspector.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import SwiftUI

/// Inspector panel for Content tab - shows resource metadata and content info
struct ContentInspector: View {
    @Binding var document: FolioDocument
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Content Info")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Summary Length")
                        .font(.subheadline)
                        .bold()
                    Text("\(document.summary.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Description Length")
                        .font(.subheadline)
                        .bold()
                    Text("\((document.description ?? "").count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Resources")
                        .font(.subheadline)
                        .bold()
                    Text("\(document.resources.count) resource(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !document.resources.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(document.resources.indices, id: \.self) { index in
                                HStack {
                                    Text("\(index + 1).")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(document.resources[index].label.isEmpty ? "Untitled" : document.resources[index].label)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
