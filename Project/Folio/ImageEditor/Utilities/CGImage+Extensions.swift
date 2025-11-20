//
//  CGImage+Extensions.swift
//  ImageEditor
//

import CoreGraphics
import AppKit

extension CGImage {
    /// Crop image to specified rect
    func cropped(to rect: CGRect) -> CGImage? {
        let normalizedRect = CGRect(
            x: rect.origin.x * CGFloat(width),
            y: rect.origin.y * CGFloat(height),
            width: rect.size.width * CGFloat(width),
            height: rect.size.height * CGFloat(height)
        )
        
        return cropping(to: normalizedRect)
    }
    
    /// Apply transformations for display (rotation and translation only, no scale)
    /// Scale is handled by SwiftUI view sizing to maintain quality
    func transformedForDisplay(rotation: CGFloat, translation: CGSize) -> CGImage? {
        let size = CGSize(width: width, height: height)
        
        // Calculate bounds that fit rotated image
        let rotatedBounds = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: rotation))
        
        let outputSize = CGSize(
            width: abs(rotatedBounds.width),
            height: abs(rotatedBounds.height)
        )
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        
        // Move to center
        context.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
        
        // Apply rotation
        context.rotate(by: rotation)
        
        // Apply translation
        context.translateBy(x: translation.width, y: translation.height)
        
        // Draw image centered (no scaling applied here)
        context.draw(self, in: CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        ))
        
        return context.makeImage()
    }
    
    /// Apply transformations (scale, rotation, translation) to image
    func transformed(scale: CGFloat, rotation: CGFloat, translation: CGSize) -> CGImage? {
        let size = CGSize(width: width, height: height)
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // Calculate bounds that fit rotated image
        let rotatedBounds = CGRect(origin: .zero, size: scaledSize)
            .applying(CGAffineTransform(rotationAngle: rotation))
        
        let outputSize = CGSize(
            width: abs(rotatedBounds.width),
            height: abs(rotatedBounds.height)
        )
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        
        // Move to center
        context.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
        
        // Apply rotation
        context.rotate(by: rotation)
        
        // Apply translation
        context.translateBy(x: translation.width, y: translation.height)
        
        // Apply scale
        context.scaleBy(x: scale, y: scale)
        
        // Draw image centered
        context.draw(self, in: CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        ))
        
        return context.makeImage()
    }
}
