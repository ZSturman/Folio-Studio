//
//  ImageTransform.swift
//  ImageEditor
//

import Foundation
import CoreGraphics

struct ImageTransform: Equatable {
    // Crop region in normalized coordinates (0.0 - 1.0)
    var cropRect: CGRect
    
    // Scale factor (1.0 = original size)
    var scale: CGFloat
    
    // Translation offset in points
    var translation: CGSize
    
    // Rotation in radians
    var rotation: CGFloat
    
    static let identity = ImageTransform(
        cropRect: CGRect(x: 0, y: 0, width: 1, height: 1),
        scale: 1.0,
        translation: .zero,
        rotation: 0
    )
    
    init(cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
         scale: CGFloat = 1.0,
         translation: CGSize = .zero,
         rotation: CGFloat = 0) {
        self.cropRect = cropRect
        self.scale = scale
        self.translation = translation
        self.rotation = rotation
    }
}
