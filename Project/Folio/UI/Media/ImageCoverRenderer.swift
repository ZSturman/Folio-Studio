//
//  ImageCoverRenderer.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//
// ImageCoverRenderer.swift
import AppKit

enum OutputFormat { case jpeg(CGFloat), png }

struct CoverRenderOptions {
    let targetAspect: CGSize
    let targetMaxPixels: CGSize?
    let output: OutputFormat
    let enforceCover: Bool        // true on import
}

enum CoverRender {
    static func renderCover(nsImage: NSImage,
                            options: CoverRenderOptions,
                            userTransform: UserTransform? = nil) -> NSImage? {
        // Compute target pixel size: preserve aspect of `targetAspect`.
        let aspect = options.targetAspect
        let baseWidth: CGFloat
        let baseHeight: CGFloat
        if let target = options.targetMaxPixels, target != .zero {
            // Snap exactly to provided size
            baseWidth = target.width
            baseHeight = target.height
        } else {
            // Default to 1600px on longer edge
            if aspect.width >= aspect.height {
                baseWidth = 1600
                baseHeight = 1600 * aspect.height / aspect.width
            } else {
                baseHeight = 1600
                baseWidth = 1600 * aspect.width / aspect.height
            }
        }

        let outSize = CGSize(width: round(baseWidth), height: round(baseHeight))
        return ImageCompositor.compose(original: nsImage,
                                       targetSize: outSize,
                                       cropAspect: aspect,
                                       user: userTransform,
                                       enforceCover: options.enforceCover)
    }
}
