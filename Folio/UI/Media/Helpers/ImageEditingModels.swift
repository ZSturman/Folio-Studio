//
//  ImageEditingModels.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import Foundation
import CoreGraphics

struct UserTransform: Codable, Equatable {
    var scale: CGFloat = 1.0        // relative to base cover fit
    var rotationDegrees: CGFloat = 0 // clockwise degrees
    var translation: CGSize = .zero  // in target pixel space
}

//enum FillMode: String, Codable, CaseIterable {
//    case black, white, blur, transparent
//}
