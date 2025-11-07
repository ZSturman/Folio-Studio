//
//  LauncherView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

#if os(macOS)
import SwiftUI
import AppKit
import SwiftData


struct LauncherView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: AppSession
    
    @Query(sort: [SortDescriptor(\ProjectDoc.updatedAt)])
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
                ForEach(documents, id: \.self) { doc in
                    HStack {
                        Text(doc.title)
                        Spacer()
                        Text(doc.filePath)
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }
}
#endif
