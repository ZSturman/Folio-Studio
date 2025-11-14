//
//  FolioApp.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Combine

@main
struct FolioApp: App {
    @StateObject private var session = AppSession()
    
    
    
    var body: some Scene {
        Window("Folio", id: "launcher") {
            LauncherView()
                .modelContainer(for: FolioVersionedSchema.models)
                .environmentObject(session)
        }
        // 2) Real document windows only open after a file is chosen or created
        DocumentGroup(newDocument:  FolioDocument() ) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .environmentObject(session)
                .background(SeedBootstrapper())
            
        }
        .modelContainer(for: FolioVersionedSchema.models)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New…") { DocumentActions.createNewDocumentWithSavePanel() }
                    .keyboardShortcut("n")
                Button("Open…") { DocumentActions.openExistingDocumentPanel() }
                    .keyboardShortcut("o")
            }
        }
        
        Settings { SettingsView() }
    }
    
}


final class AppSession: ObservableObject {
    @Published var openDocumentCount: Int = 0
}
