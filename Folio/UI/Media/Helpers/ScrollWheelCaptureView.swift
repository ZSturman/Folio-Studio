//
//  ScrollWheelCaptureView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import SwiftUI


struct ScrollWheelCaptureView: NSViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var rotation: CGFloat
    @Binding var translation: CGSize

    func makeNSView(context: Context) -> NSView {
        MouseCaptureView(scale: $scale, rotation: $rotation, translation: $translation)
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class MouseCaptureView: NSView {
        @Binding var scale: CGFloat
        @Binding var rotation: CGFloat
        @Binding var translation: CGSize

        init(scale: Binding<CGFloat>, rotation: Binding<CGFloat>, translation: Binding<CGSize>) {
            _scale = scale
            _rotation = rotation
            _translation = translation
            super.init(frame: .zero)
            wantsLayer = true
        }
        @available(*, unavailable) required init?(coder: NSCoder) { nil }

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            if event.modifierFlags.contains(.option) {
                rotation += event.scrollingDeltaY * 0.2
            } else if event.modifierFlags.contains(.shift) {
                translation.width += event.scrollingDeltaY * 0.6
            } else {
                let delta = -event.scrollingDeltaY * 0.002
                scale = max(0.1, min(8.0, scale * (1.0 + delta)))
            }
        }

        private var isRightDragging = false
        private var lastDragPoint: NSPoint = .zero

        override func rightMouseDown(with event: NSEvent) {
            isRightDragging = true
            lastDragPoint = convert(event.locationInWindow, from: nil)
        }
        override func rightMouseDragged(with event: NSEvent) {
            guard isRightDragging else { return }
            let p = convert(event.locationInWindow, from: nil)
            rotation += (p.x - lastDragPoint.x) * 0.5
            lastDragPoint = p
        }
        override func rightMouseUp(with event: NSEvent) {
            isRightDragging = false
        }

        override func mouseEntered(with event: NSEvent) { _ = window?.makeFirstResponder(self) }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach { removeTrackingArea($0) }
            let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
            let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
        }

        override func keyDown(with event: NSEvent) {
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
            switch event.keyCode {
            case 123: // left arrow
                translation.width -= step
            case 124: // right arrow
                translation.width += step
            case 125: // down arrow
                translation.height += step
            case 126: // up arrow
                translation.height -= step
            default:
                super.keyDown(with: event)
            }
        }
    }
}

