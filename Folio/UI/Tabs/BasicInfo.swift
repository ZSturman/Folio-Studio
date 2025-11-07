//
//  BasicInfo.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import Foundation
import SwiftUI
import SwiftData




struct BasicInfoTabView: View {
    
    @EnvironmentObject var sdc: SwiftDataCoordinator
    @Binding var document: FolioDocument

    // Computed bindings for optionals and enum mapping
    private var subtitleBinding: Binding<String> {
        Binding(
            get: { document.subtitle },
            set: { document.subtitle = $0.isEmpty ? "" : $0 }
        )
    }

    private var summaryBinding: Binding<String> {
        Binding(
            get: { document.summary },
            set: { document.summary = $0.isEmpty ? "" : $0 }
        )
    }

    private var featuredBinding: Binding<Bool> {
        Binding(
            get: { document.featured },
            set: { document.featured = $0 }
        )
    }

    var body: some View {
        Form {
            Section("Basic Information") {

                HStack {
                        Toggle("Featured", isOn: featuredBinding)
                    Spacer()
                    PrivacyToggle(document: $document)
                }
                
                HStack {
                    DocumentCalendarPicker(
                        document: $document,
                        title: "Created At",
                        keyPath: \.createdAt
                    )

                    DocumentCalendarPicker(
                        document: $document,
                        title: "Updated At",
                        keyPath: \.updatedAt
                    )
                }
                TitleEditorView(document: $document)

                TextField("Subtitle", text: subtitleBinding)
                    .submitLabel(.done)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: summaryBinding)
                        .frame(minHeight: 120)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.quaternary)
                        }
                }
            }

            Section {
         
                    DomainCategoryPickerView(document: $document)
                    ProjectStatusPickerView(document: $document)
                
            }
            
        }
        .navigationTitle("Basic Info")
    }
}

#Preview {
    NavigationStack {
        BasicInfoTabView(document: .constant(FolioDocument()))
    }
}

