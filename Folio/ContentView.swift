//
//  ContentView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    
    @Binding var document: FolioDocument
    @EnvironmentObject var session: AppSession
    @StateObject private var sdc = SwiftDataCoordinator()
    
    
    @State private var selection: SidebarTab? = .basicInfo
    
    var fileURL: URL?

    var body: some View {
        NavigationSplitView {
            SidebarTabsView(selection: $selection)
#if os(macOS)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
        } detail: {
            Group {
                if let selection {
                    ScrollView {
                        detailView(for: selection)
                            .environmentObject(sdc)
                    }
                } else {
                    Text("Select a Tab")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .onAppear {
            sdc.bind(using: modelContext)
            session.openDocumentCount += 1
        }
        .task(id: fileURL) {
            guard let url = fileURL else { return }
            if $document.wrappedValue.title.isEmpty { $document.wrappedValue.title = url.deletingPathExtension().lastPathComponent }
            $document.wrappedValue.filePath = url
            let snapshot = document
            let r = await sdc.reconcileOnOpen(from: snapshot, fileURL: url)
            if case .failure(let e) = r { print("[ContentView] reconcile error: \(e)") }
            // Mark documents created via your launcher on first open.
            if document.createdAt == nil {
                document.createdAt = Date()
            }
        }
        .onDisappear {
            Task { _ = await sdc.flushSwiftDataChange(for: $document.wrappedValue.id) }
            session.openDocumentCount -= 1
            if session.openDocumentCount == 0 {
                openWindow(id: "launcher")
            }
        }
    }

    @ViewBuilder
    private func detailView(for tab: SidebarTab) -> some View {
        switch tab {
        case .basicInfo:
            BasicInfoTabView(document: $document)
        case .collection:
            CollectionTabView(document: $document)
        case .content:
            ContentTabView(document: $document)
        case .media:
            MediaTabView(document: $document)
        case .other:
            OtherTabView(document: $document)
        case .tagsAndClassification:
            TagsAndClassificationTabView(document: $document)
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView(document: .constant(FolioDocument()), fileURL: nil)
        .environmentObject(AppSession())
        .modelContainer(for: FolioVersionedSchema.models, inMemory: true)
}
