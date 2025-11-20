//
//  ImageProcessor.swift
//  ImageEditor
//

import AppKit
import CoreGraphics

class ImageProcessor {
    /// Apply transformations for DISPLAY only (non-destructive preview)
    /// This shows the full image with transformations, without applying the crop
    static func process(
        image: NSImage,
        transform: ImageTransform,
        aspectRatio: AspectRatio?,
        canvasSize: CGSize
    ) -> NSImage? {
        print("ImageProcessor.process called - image size: \(image.size), canvas: \(canvasSize)")
        
        // For display, we just return the original image with transformations
        // but WITHOUT cropping. The crop will be shown as an overlay in the UI
        // and only applied during export
        
        guard let cgImage = image.cgImage else {
            print("Failed to get CGImage from NSImage")
            return nil
        }
        print("Got CGImage: \(cgImage.width)x\(cgImage.height)")
        
        // Only apply rotation and translation for display
        // Scale is handled by SwiftUI's .scaleEffect to maintain quality
        if transform.rotation != 0 || transform.translation != .zero {
            if let transformed = cgImage.transformedForDisplay(
                rotation: transform.rotation,
                translation: transform.translation
            ) {
                let result = NSImage(cgImage: transformed)
                print("Returning transformed image: \(result?.size ?? .zero)")
                return result
            }
        }
        
        // Return original image if no transformations needed
        print("Returning original image: \(image.size)")
        return image
    }
    
    /// Calculate the initial crop rect for a given aspect ratio
    static func calculateInitialCropRect(
        for imageSize: CGSize,
        aspectRatio: AspectRatio
    ) -> CGRect {
        guard let ratio = aspectRatio.ratio else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        let imageRatio = imageSize.width / imageSize.height
        
        if imageRatio > ratio {
            // Image is wider than target ratio - crop width
            let targetWidth = imageSize.height * ratio
            let cropX = (imageSize.width - targetWidth) / 2
            return CGRect(
                x: cropX / imageSize.width,
                y: 0,
                width: targetWidth / imageSize.width,
                height: 1
            )
        } else {
            // Image is taller than target ratio - crop height
            let targetHeight = imageSize.width / ratio
            let cropY = (imageSize.height - targetHeight) / 2
            return CGRect(
                x: 0,
                y: cropY / imageSize.height,
                width: 1,
                height: targetHeight / imageSize.height
            )
        }
    }
    
    /// Calculate display size that fits within canvas while respecting aspect ratio
    static func calculateDisplaySize(
        for imageSize: CGSize,
        aspectRatio: AspectRatio?,
        canvasSize: CGSize,
        scale: CGFloat
    ) -> CGSize {
        var targetSize = imageSize
        
        // Apply aspect ratio constraint if set
        if let ratio = aspectRatio?.ratio {
            let imageRatio = imageSize.width / imageSize.height
            if imageRatio > ratio {
                targetSize.width = imageSize.height * ratio
            } else {
                targetSize.height = imageSize.width / ratio
            }
        }
        
        // Scale to fit canvas
        let widthRatio = canvasSize.width / targetSize.width
        let heightRatio = canvasSize.height / targetSize.height
        let fitScale = min(widthRatio, heightRatio, 1.0)
        
        return CGSize(
            width: targetSize.width * fitScale * scale,
            height: targetSize.height * fitScale * scale
        )
    }
    
    /// Export image with transformations applied
    /// This is where we actually apply the crop and all transformations permanently
    static func exportImage(
        original: NSImage,
        transform: ImageTransform,
        format: ExportFormat
    ) -> Data? {
        guard let cgImage = original.cgImage else { return nil }
        
        var processedImage = cgImage
        
        // Step 1: Apply rotation and translation first
        if transform.rotation != 0 || transform.translation != .zero {
            if let transformed = processedImage.transformedForDisplay(
                rotation: transform.rotation,
                translation: transform.translation
            ) {
                processedImage = transformed
            }
        }
        
        // Step 2: Apply crop (this happens AFTER rotation/translation for export)
        if transform.cropRect != CGRect(x: 0, y: 0, width: 1, height: 1) {
            if let cropped = processedImage.cropped(to: transform.cropRect) {
                processedImage = cropped
            }
        }
        
        // Convert to NSImage and export
        guard let finalImage = NSImage(cgImage: processedImage) else { return nil }
        return finalImage.exportData(format: format)
    }
}
