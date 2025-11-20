//
//  AspectRatio.swift
//  ImageEditor
//

import Foundation

enum AspectRatio: Hashable, CaseIterable, Identifiable {
    case square      // 1:1
    case standard    // 4:3
    case widescreen  // 16:9
    case portrait    // 3:4
    case tallscreen  // 9:16
    case photo       // 3:2
    case cinematic   // 21:9
    case banner      // 4:1
    case poster      // 2:3
    case free        // No constraint
    
    var id: String {
        name
    }
    
    var name: String {
        switch self {
        case .square: return "Square"
        case .standard: return "Standard"
        case .widescreen: return "Widescreen"
        case .portrait: return "Portrait"
        case .tallscreen: return "Tall"
        case .photo: return "Photo"
        case .cinematic: return "Cinematic"
        case .banner: return "Banner"
        case .poster: return "Poster"
        case .free: return "Free"
        }
    }
    
    var ratio: CGFloat? {
        switch self {
        case .square: return 1.0
        case .standard: return 4.0 / 3.0
        case .widescreen: return 16.0 / 9.0
        case .portrait: return 3.0 / 4.0
        case .tallscreen: return 9.0 / 16.0
        case .photo: return 3.0 / 2.0
        case .cinematic: return 21.0 / 9.0
        case .banner: return 4.0 / 1.0
        case .poster: return 2.0 / 3.0
        case .free: return nil
        }
    }
    
    var displayRatio: String {
        switch self {
        case .square: return "1:1"
        case .standard: return "4:3"
        case .widescreen: return "16:9"
        case .portrait: return "3:4"
        case .tallscreen: return "9:16"
        case .photo: return "3:2"
        case .cinematic: return "21:9"
        case .banner: return "4:1"
        case .poster: return "2:3"
        case .free: return "Free"
        }
    }
}
