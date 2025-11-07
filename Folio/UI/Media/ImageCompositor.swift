//
//  ImageCompositor.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import Foundation
// ImageCompositor.swift
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ImageCompositor {
    static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Compose original into a target canvas with transform and background fill.
    static func compose(original nsImage: NSImage,
                        targetSize: CGSize,
                        cropAspect: CGSize,
                        user: UserTransform?,
                        enforceCover: Bool) -> NSImage? {
        guard let ci = nsImage.ciImage else { return nil }

        // Background
        let bg: CIImage =  CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: CGRect(origin: .zero, size: targetSize))


        // Compute base cover-fit transform to fill target rect
        let baseScale = max(targetSize.width / ci.extent.width, targetSize.height / ci.extent.height)
        var t = CGAffineTransform.identity
            .translatedBy(x: targetSize.width/2, y: targetSize.height/2)
            .scaledBy(x: baseScale, y: baseScale)

        // Apply user transform if any
        if let user {
            t = t
                .translatedBy(x: user.translation.width, y: user.translation.height)
                .rotated(by: user.rotationDegrees * .pi / 180)
                .scaledBy(x: user.scale, y: user.scale)
        }

        // Move CIImage so that its center is at the origin before applying t
        let centered = ci.transformed(by: CGAffineTransform(translationX: -ci.extent.midX, y: -ci.extent.midY))
        let placed = centered.transformed(by: t)

        // Composite
        let composed = placed.composited(over: bg)
            .cropped(to: CGRect(origin: .zero, size: targetSize))

        // Optional cover enforcement: if holes appear and enforceCover is true, re-center and clamp translation.
        // Simple clamp: ensure at least target rect is covered by the transformed image’s bounds.
        // This can be refined in the editor UI; compositor stays permissive.

        // Render
        guard let cg = ciContext.createCGImage(composed, from: CGRect(origin: .zero, size: targetSize)) else { return nil }
        let out = NSImage(cgImage: cg, size: NSSize(width: targetSize.width, height: targetSize.height))
        return out
    }
}

private extension NSImage {
    var ciImage: CIImage? {
        if let tiff = self.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            return CIImage(bitmapImageRep: rep)
        }
        return nil
    }
}
