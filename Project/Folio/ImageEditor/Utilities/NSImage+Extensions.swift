//
//  NSImage+Extensions.swift
//  ImageEditor
//

import AppKit

extension NSImage {
    /// Get CGImage representation
    var cgImage: CGImage? {
        // Try to get CGImage from the best representation
        guard let imageData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData) else {
            return nil
        }
        return bitmap.cgImage
    }
    
    /// Create NSImage from CGImage
    convenience init?(cgImage: CGImage) {
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        self.init(cgImage: cgImage, size: size)
    }
    
    /// Resize image to fit within maximum dimensions while maintaining aspect ratio
    func resized(toFit maxSize: CGSize) -> NSImage? {
        let widthRatio = maxSize.width / size.width
        let heightRatio = maxSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio, 1.0)
        
        let newSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        
        let context = NSGraphicsContext.current?.cgContext
        context?.interpolationQuality = .high
        
        draw(in: CGRect(origin: .zero, size: newSize),
             from: CGRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
    
    /// Export image data in specified format
    func exportData(format: ExportFormat) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapImage.representation(
            using: format.bitmapFormat,
            properties: format.compressionProperties
        )
    }
}
