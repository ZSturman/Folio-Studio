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
    @StateObject private var inspectorState = InspectorState()
    @AppStorage("launcherAutoOpen") private var launcherAutoOpen = true
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        Window("Folio", id: "launcher") {
            LauncherView()
                .modelContainer(for: FolioVersionedSchema.models)
                .environmentObject(session)
                .onAppear {
                    // Open launcher automatically if enabled and no documents are open
                    if launcherAutoOpen && session.openDocumentCount == 0 {
                        // Launcher is already showing via this window
                    }
                }
        }
        .defaultPosition(.center)
        
        // 2) Real document windows only open after a file is chosen or created
        DocumentGroup(newDocument:  FolioDocument() ) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .environmentObject(session)
                .environmentObject(inspectorState)
                .background(SeedBootstrapper())
            
        }
        .defaultSize(width: 1400, height: 900)
        .modelContainer(for: FolioVersionedSchema.models)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New…") { DocumentActions.createNewDocumentWithSavePanel() }
                    .keyboardShortcut("n")
                Button("Open…") { DocumentActions.openExistingDocumentPanel() }
                    .keyboardShortcut("o")
            }
        }
        
        Settings {
            SettingsView()
                .modelContainer(for: FolioVersionedSchema.models)
        }
    }
    
}


final class AppSession: ObservableObject {
    @Published var openDocumentCount: Int = 0
}
