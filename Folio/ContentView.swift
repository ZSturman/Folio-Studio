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

    @State private var basicInfoSubtab: BasicInfoSubtab? = .main
    @State private var contentSubtab:   ContentSubtab?   = .summary
    @State private var selectedLanguage: ProgrammingLanguage? = .swift
    @State private var selectedResourceIndex: Int?
    @State private var selectedCollectionItem: CollectionTabView.SelectedItem?
    @State private var selectedImageLabel: ImageLabel = .thumbnail
    
    var fileURL: URL?

    var body: some View {
        NavigationSplitView {
            // 1st column: main sidebar
            SidebarTabsView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)

        } content: {
            secondarySidebar
                .padding(.horizontal, 4)

        } detail: {
            // 3rd column: the actual editor / detail
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
        .onChange(of: selectedLanguage) { _, new in
            print("selectedLanguage changed to", new as Any)
        }
    }

    @ViewBuilder
    private func detailView(for tab: SidebarTab) -> some View {
        switch tab {
        case .basicInfo:
            switch basicInfoSubtab ?? .main {
            case .main:
                // your existing main basic info view
                BasicInfoTabView(document: $document)

            case .classification:
                // a different view or mode for classification
                BasicInfoClassificationView(document: $document)

            case .details:
                BasicInfoDetailsView(document: $document)
            }

        case .content:
            switch contentSubtab ?? .summary {
            case .summary:
                DocumentTextSection(
                    title: "Summary",
                    text: Binding(
                        get: { document.summary },
                        set: { document.summary = $0 }
                    )
                )
            case .description:
     
                DocumentTextSection(
                    title: "Description",
                    text: Binding(
                        get: { document.description ?? "" },
                        set: { document.description = $0 }
                    )
                )
                
            case .resources:
                ResourcesDetailView(document: $document)
                
                
            }
            
        

        case .media:
            MediaDetailView(document: $document, selectedImageLabel: $selectedImageLabel)
                .navigationTitle(selectedImageLabel.title)

        case .collection:
            CollectionTabView(
                document: $document,
                selectedItem: $selectedCollectionItem
            )

        case .snippets:
            CodeSnippetsView(programmingLanguage: selectedLanguage ?? .swift)
                .onAppear { print("Detail language:", selectedLanguage as Any) }
                .onChange(of: selectedLanguage) { _, new in
                    print("Detail sees language change:", new as Any)
                }

        case .settings:
            SettingsView()
        }
    }
    
    @ViewBuilder
    private var secondarySidebar: some View {
        switch selection {
        case .basicInfo:
            List(BasicInfoSubtab.allCases, selection: $basicInfoSubtab) { sub in
                Text(sub.title)
                    .tag(sub)
            }
            .navigationTitle("Basic Info")

        case .content:
            List(ContentSubtab.allCases, selection: $contentSubtab) { sub in
                Text(sub.title)
                    .tag(sub)
            }
            .navigationTitle("Content")


        case .media:
            MediaSecondarySidebar(
                document: $document,
                selectedImageLabel: $selectedImageLabel
            )
            .navigationTitle("Media")

        case .collection:
            CollectionSidebar(
                document: $document,
                selectedItem: $selectedCollectionItem
            )
            .navigationTitle("Collection")

        case .snippets:
            List(ProgrammingLanguage.allCases, selection: $selectedLanguage) { language in
                Text(language.displayName)
                    .tag(language)
            }
            .navigationTitle("Snippets")

        case .settings, .none:
            Text("No secondary options")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView(document: .constant(FolioDocument()), fileURL: nil)
        .environmentObject(AppSession())
        .modelContainer(for: FolioVersionedSchema.models, inMemory: true)
}

