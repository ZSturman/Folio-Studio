//
//  AnimatedImageView.swift
//  Folio
//
//  Created for GIF animation support
//

import SwiftUI
import AppKit

/// A SwiftUI view that displays images with GIF animation support
/// Uses NSImageView under the hood which properly handles animated GIFs
struct AnimatedImageView: NSViewRepresentable {
    let url: URL?
    let nsImage: NSImage?
    
    init(url: URL) {
        self.url = url
        self.nsImage = nil
    }
    
    init(nsImage: NSImage) {
        self.url = nil
        self.nsImage = nsImage
    }
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true // Enable GIF animation
        imageView.isEditable = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(imageView)
        
        // Constrain image view to fill container while respecting aspect ratio
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: containerView.widthAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: containerView.heightAnchor)
        ])
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let imageView = nsView.subviews.first as? NSImageView else { return }
        
        if let url = url {
            // Load from URL - this preserves GIF animation data
            imageView.image = NSImage(contentsOf: url)
        } else if let image = nsImage {
            imageView.image = image
        }
        imageView.animates = true
    }
}

/// Helper to check if a file is a GIF
extension URL {
    var isGIF: Bool {
        pathExtension.lowercased() == "gif"
    }
}
