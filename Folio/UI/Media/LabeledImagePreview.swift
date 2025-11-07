//
//  LabeledImagePreview.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import SwiftUI
import AppKit

struct LabeledImagePreview: View {
    let nsImage: NSImage
    private let maxHeight: CGFloat = 160
    
    var aspectRatio: CGFloat {
        CGFloat(nsImage.size.width) / CGFloat(nsImage.size.height)
    }


    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            let heightFromWidth = containerWidth / aspectRatio
            let height = min(heightFromWidth, maxHeight)
            let width = min(containerWidth, height * aspectRatio)

            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: width, height: height, alignment: .center)
                .clipped()
                .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .center)
        }
        .frame(height: maxHeight)
        .padding()
    }
}
