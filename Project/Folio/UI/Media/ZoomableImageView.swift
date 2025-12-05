//
//  ZoomableImageView.swift
//  Folio
//
//  Provides zoomable and scrollable image viewing with magnification controls
//

import SwiftUI
import AppKit

/// A view that wraps an image (static or animated) with zoom and scroll capabilities
struct ZoomableImageView: View {
    let url: URL?
    let nsImage: NSImage?
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    private let minScale: CGFloat = 0.25
    private let maxScale: CGFloat = 4.0
    
    init(url: URL) {
        self.url = url
        self.nsImage = nil
    }
    
    init(nsImage: NSImage) {
        self.url = nil
        self.nsImage = nsImage
    }
    
    private var loadedImage: NSImage? {
        if let url = url {
            return NSImage(contentsOf: url)
        }
        return nsImage
    }
    
    private var isAnimatedGIF: Bool {
        url?.pathExtension.lowercased() == "gif"
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Main scrollable image area
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack {
                        if isAnimatedGIF, let url = url {
                            // Use AnimatedImageView for GIFs to preserve animation
                            AnimatedImageView(url: url)
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                        } else if let image = loadedImage {
                            // Use SwiftUI Image for static images - simpler and more reliable
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                        }
                    }
                    .frame(
                        minWidth: geometry.size.width,
                        minHeight: geometry.size.height
                    )
                }
                .background(Color(NSColor.controlBackgroundColor))
                
                // Zoom controls toolbar
                HStack(spacing: 12) {
                    Button(action: zoomOut) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(scale <= minScale)
                    .help("Zoom Out")
                    
                    Slider(value: $scale, in: minScale...maxScale, step: 0.1)
                        .frame(width: 120)
                        .help("Zoom Level: \(Int(scale * 100))%")
                    
                    Button(action: zoomIn) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(scale >= maxScale)
                    .help("Zoom In")
                    
                    Divider()
                        .frame(height: 16)
                    
                    Button(action: resetZoom) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .help("Reset Zoom")
                    
                    Text("\(Int(scale * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 45, alignment: .trailing)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(NSColor.separatorColor)),
                    alignment: .top
                )
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastScale
                    lastScale = value
                    let newScale = scale * delta
                    scale = min(max(newScale, minScale), maxScale)
                }
                .onEnded { _ in
                    lastScale = 1.0
                }
        )
    }
    
    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = min(scale + 0.25, maxScale)
        }
    }
    
    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = max(scale - 0.25, minScale)
        }
    }
    
    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = 1.0
        }
    }
}

#Preview {
    if let url = Bundle.main.url(forResource: "sample", withExtension: "jpg") {
        ZoomableImageView(url: url)
            .frame(width: 600, height: 400)
    } else {
        Text("No preview image available")
    }
}
