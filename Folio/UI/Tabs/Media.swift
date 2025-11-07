//
//  Media.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Media Tab

struct MediaTabView: View {
    @Binding var document: FolioDocument

    @State private var errorMessage: String?
    @State private var newCustomName: String = ""
    
    #warning("Fix the issue where when it's a custom image label the user is unable to change the aspect ratio. Also the preview window shows an aspect ration different than that of the image editor view")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Edited folder selector (required)
            HStack {
                Text("Edited Images Folder:")
                if let assetsFolder = document.assetsFolder {
                    Text(assetsFolder.path)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("None selected")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Choose…") { pickEditedFolder() }
            }

            if let msg = errorMessage {
                Text(msg).foregroundColor(.red).font(.caption)
            }

            Divider()

            // One slot per ImageLabel
            ForEach(ImageLabel.presets, id: \.self) { label in
                if document.images[label] != nil {
                    ImageSlotView(
                        label: label,
                        jsonImage: Binding(
                            get: { document.images[label] },
                            set: { document.images[label] = $0 }
                        ),
                        assetsFolder: $document.assetsFolder
                    )
                    .disabled(document.assetsFolder == nil)
                    .overlay(alignment: .topTrailing) {
                        if document.assetsFolder == nil {
                            Text("Select edited folder first")
                                .font(.caption2)
                                .padding(4)
                                .background(.yellow.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(6)
                        }
                    }
                    Divider()
                } else {
                    HStack {
                        Text(label.title)
                        Spacer()
                        Button("Add \(label.title)") {
                            document.images[label] = AssetPath(pathToOriginal: "", pathToEdited: "")
                        }
                    }
                    Divider()
                }
            }

            Text("Custom").font(.title3).padding(.top, 6)

            // Derive existing custom labels from the document.images keys
            let customNames = document.images.keys.compactMap { key -> String? in
                key.hasPrefix("custom:") ? String(key.dropFirst(7)) : nil
            }.sorted()

            ForEach(customNames, id: \.self) { name in
                ImageSlotView(
                    label: .custom(name),
                    jsonImage: Binding(
                        get: { document.images[.custom(name)] },
                        set: { document.images[.custom(name)] = $0 }
                    ),
                    assetsFolder: $document.assetsFolder
                )
                .disabled(document.assetsFolder == nil)
                .overlay(alignment: .topTrailing) {
                    if document.assetsFolder == nil {
                        Text("Select edited folder first")
                            .font(.caption2)
                            .padding(4)
                            .background(.yellow.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                }
                Divider()
            }

            HStack(spacing: 8) {
                TextField("Custom label name", text: $newCustomName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 250)
                Button("Add Custom") {
                    let trimmed = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    // If this custom label does not yet exist, create it like presets
                    if document.images[.custom(trimmed)] == nil {
                        document.images[.custom(trimmed)] = AssetPath(pathToOriginal: "", pathToEdited: "")
                    }
                    newCustomName = ""
                }
                Spacer()
            }
        }
        .padding()
    }

    private func pickEditedFolder() {
        let panel = NSOpenPanel()
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            document.assetsFolder = url
            errorMessage = nil
        }
    }
}



// MARK: - Preview

#Preview {
    NavigationStack {
        MediaTabView(document: .constant(FolioDocument()))
    }
}
