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

    var body: some View {
        GeometryReader { geo in
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFill()
                .frame(width: geo.size.width,
                       height: geo.size.height,
                       alignment: .center)
        }
    }
}
