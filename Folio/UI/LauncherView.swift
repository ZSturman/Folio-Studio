//
//  LauncherView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import SwiftUI
import AppKit
import SwiftData


struct LauncherView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: AppSession
    
    @Query(sort: [SortDescriptor(\ProjectDoc.updatedAt, order: .reverse)])
    private var documents: [ProjectDoc]
    

    var body: some View {
        VStack(spacing: 16) {
            Text("Folio").font(.largeTitle)
            Text("Open an existing document or create a new one.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Open…") {
              
                    DocumentActions.openExistingDocumentPanel()
                    dismiss()
                  
                }
                Button("New…") {
                 
                    DocumentActions.createNewDocumentWithSavePanel()
                    dismiss()
                 
                }
                .keyboardShortcut(.defaultAction)
            }
            
            List {
                ForEach(documents.prefix(8), id: \.self) { doc in
                    Button {
                        openDocument(doc)
                    } label: {
                        HStack {
                            Text(doc.title)
                            Spacer()
                            Text(doc.filePath)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }
    private func openDocument(_ doc: ProjectDoc) {
        let url = URL(fileURLWithPath: doc.filePath)
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in
            dismiss()
        }
    }
}
