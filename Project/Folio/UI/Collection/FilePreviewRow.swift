//
//  FilePreviewRow.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import SwiftUI
import QuickLookThumbnailing


struct FilePreviewRow: View {
    let url: URL
    let title: String
    var onDelete: () -> Void
    /// Optional preloaded preview image to display immediately if available
    let preloadedImage: NSImage?

    @State private var thumbnail: NSImage?

    init(url: URL, title: String, preloadedImage: NSImage? = nil, onDelete: @escaping () -> Void) {
        self.url = url
        self.title = title
        self.onDelete = onDelete
        self.preloadedImage = preloadedImage
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: preloadedImage ?? thumbnail ?? NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.2)))

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.callout)
                    .lineLimit(1)
                Text(url.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(role: .destructive) { onDelete() } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .onAppear {
            if preloadedImage == nil {
                generateThumbnail()
            }
        }
    }

    private func generateThumbnail() {
        // Prefer a already-readable URL if possible, otherwise try a stored security-scoped bookmark.
        let candidate: URL = {
            if PermissionHelper.isReadable(url) { return url }
            if let resolved = PermissionHelper.resolvedURL(forOriginalPath: url.path, from: nil) { return resolved }
            return url
        }()
        // If the URL points to an image, load it directly for accurate preview.
        if let img = NSImage(contentsOf: candidate) {
            DispatchQueue.main.async {
                self.thumbnail = img
            }
            return
        }
        // Fall back to QuickLook for non-image types.
        let size = CGSize(width: 64, height: 64)
        let req = QLThumbnailGenerator.Request(
            fileAt: candidate,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .all
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
            if let cgImage = rep?.cgImage {
                DispatchQueue.main.async {
                    self.thumbnail = NSImage(cgImage: cgImage, size: size)
                }
            }
        }
    }
}
