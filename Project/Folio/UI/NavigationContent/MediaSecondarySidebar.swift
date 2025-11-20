//
//  MediaSecondarySidebar.swift
//  Folio
//
//  Created by Zachary Sturman on 11/10/25.
//

import SwiftUI

struct MediaSecondarySidebar: View {
    @Binding var document: FolioDocument
    
    @Binding var selectedImageLabel: ImageLabel
    
    private var numberOfCustomLabels: Int { max(0, document.images.keys.count - ImageLabel.presets.count) }
    
    private var allImageLabels: [ImageLabel] {
        var ordered: [ImageLabel] = []
        // Start with the built-in presets
        let base = ImageLabel.presets +
        document.images.keys.map { ImageLabel(storageKey: $0) }
        
        for label in base {
            if !ordered.contains(label) {
                ordered.append(label)
            }
        }
        
        return ordered
    }
    
    private func addCustomLabel() {
        let newLabel: ImageLabel = .custom("Custom Image \(numberOfCustomLabels + 1)")
        if document.images[newLabel] == nil {
            document.images[newLabel] = AssetPath(pathToOriginal: "", pathToEdited: "")
        }
        selectedImageLabel = newLabel
        
    }
    
    private func iconForLabel(_ label: ImageLabel) -> String {
        switch label {
        case .thumbnail:
            return "camera.circle"
        case .banner:
            return "photo.on.rectangle.angled"
        case .heroBanner:
            return "rectangle.landscape"
        case .poster:
            return "doc.richtext"
        case .icon:
            return "app.badge"
        case .custom:
            return "photo.stack"
        }
    }
    
    
    
    var body: some View {
        List(selection: $selectedImageLabel) {
            ForEach(allImageLabels, id: \.self) { label in
                Label(label.title, systemImage: iconForLabel(label))
                    .tag(label)
            }
            
            
            Button(action: {
                addCustomLabel()
            }) {
                Label("Add", systemImage: "plus")
            }
            //                .buttonStyle(.borderless)
        }
    }
}

