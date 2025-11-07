//
//  SharedDropTarget.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import Foundation

import SwiftUI
import UniformTypeIdentifiers

public struct DropTargetView: View {
    @Binding var isTargeted: Bool
    let title: String
    let acceptImagesOnly: Bool
    let onPick: (URL) -> Void

    public init(isTargeted: Binding<Bool>, title: String, acceptImagesOnly: Bool = false, onPick: @escaping (URL) -> Void) {
        self._isTargeted = isTargeted
        self.title = title
        self.acceptImagesOnly = acceptImagesOnly
        self.onPick = onPick
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down.on.square")
                .imageScale(.large)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isTargeted ? .blue : .secondary, style: StrokeStyle(lineWidth: 1, dash: [6]))
        )
        .contentShape(Rectangle())
        .onDrop(of: dropTypes, isTargeted: $isTargeted) { providers in
            // Prefer direct file URL
            if let item = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
                _ = item.loadObject(ofClass: URL.self) { url, _ in
                    if let url, self.accept(url) { DispatchQueue.main.async { onPick(url) } }
                }
                return true
            }
            // Fallback: data/image
            if let any = providers.first {
                let type = acceptImagesOnly ? UTType.image : UTType.data
                any.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                    guard let data else { return }
                    let ext = self.acceptImagesOnly ? "png" : "bin"
                    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(ext)
                    do {
                        try data.write(to: tmp)
                        DispatchQueue.main.async { onPick(tmp) }
                    } catch { /* ignore */ }
                }
                return true
            }
            return false
        }
        .accessibilityAddTraits(.isButton)
    }

    private var dropTypes: [UTType] {
        acceptImagesOnly ? [.fileURL, .image] : [.fileURL, .image, .data]
    }

    private func accept(_ url: URL) -> Bool {
        guard acceptImagesOnly else { return true }
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .image)
        }
        // Fallback by extension
        let ok = ["png","jpg","jpeg","heic","tiff","gif","bmp","webp"]
        return ok.contains(url.pathExtension.lowercased())
    }
}
