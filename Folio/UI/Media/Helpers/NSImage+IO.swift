//
//  NSImage+IO.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import Foundation
import AppKit

extension NSImage {
    func resized(to target: CGSize) -> NSImage {
        let img = NSImage(size: target)
        img.lockFocus()
        NSColor.clear.set()
        let rect = NSRect(origin: .zero, size: target)
        self.draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)
        img.unlockFocus()
        return img
    }

    func writeJPEG(to url: URL, quality: CGFloat = 0.95) throws {
        guard let tiffData = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            throw NSError(domain: "ImageWrite", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JPEG"])
        }
        try data.write(to: url, options: .atomic)
    }

    func writePNG(to url: URL) throws {
        guard let tiffData = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImageWrite", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
        }
        try data.write(to: url, options: .atomic)
    }
}
