//
//  CropCanvas.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//


import SwiftUI
import AppKit

struct CropCanvas: View {
    let nsImage: NSImage
    let targetAspect: CGSize?
    
    @Binding var scaleRelCover: CGFloat
    @Binding var rotation: CGFloat
    @Binding var translationNorm: CGSize
    
    // When targetAspect == nil, this rect defines the crop area in 0...1 normalized coordinates
    @Binding var cropRectNorm: CGRect
    
    @State private var canDrag = false
    @State private var lastDrag: CGSize = .zero
    
    var body: some View {
        GeometryReader { geo in
            let container = geo.size
            let cropRect: CGRect = targetAspect.map { fixed in
                fitAspectRect(in: container, aspect: fixed)
            } ?? CGRect(x: cropRectNorm.origin.x * container.width,
                        y: cropRectNorm.origin.y * container.height,
                        width: cropRectNorm.size.width * container.width,
                        height: cropRectNorm.size.height * container.height)
            
            ZStack {
                // 1) Faded, desaturated overflow preview
                transformedImage(in: cropRect)
                    .saturation(0)
                    .opacity(0.35)
                    .allowsHitTesting(false)
                
                // 2) Scrim outside crop
                Group {
                    Path { p in p.addRect(CGRect(origin: .zero, size: container)) }
                        .fill(Color.black.opacity(0.5))
                        .allowsHitTesting(false)
                    
                    Path { p in p.addRect(cropRect) }
                        .fill(Color.clear)
                        .blendMode(.destinationOut)
                        .allowsHitTesting(false)
                }
                .compositingGroup()
                
                // 3) Full-strength image clipped to crop
                transformedImage(in: cropRect)
                    .clipShape(Rectangle().path(in: cropRect))
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(Color.white.opacity(0.9), lineWidth: 1)
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY) 
                    )
                
                if targetAspect == nil {
                    // Draw corner handles
                    ForEach(handlePoints(for: cropRect), id: \.self) { pt in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .position(pt)
                            .gesture(resizeGesture(from: pt, in: container))
                    }
                }
                
                // 4) Gestures
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(canvasGesture(container: container, cropRect: cropRect))
                
           
                ScrollWheelCaptureView(scale: $scaleRelCover, rotation: $rotation, translation: $translationNorm)
                    .frame(width: container.width, height: container.height)
                    .allowsHitTesting(true)
        
            }
            .clipped()
            .position(x: container.width / 2, y: container.height / 2)
            .compositingGroup()
        }
    }
    
    private func transformedImage(in cropRect: CGRect) -> some View {
        let imageAspect = nsImage.size.width / max(nsImage.size.height, 0.0001)
        let cropAspect: CGFloat = {
            if let t = targetAspect { return t.width / max(t.height, 0.0001) }
            return cropRect.width / max(cropRect.height, 0.0001)
        }()
        let coverMultiplier = max(cropAspect / imageAspect, imageAspect / cropAspect)

        let visualScale = scaleRelCover * coverMultiplier
        let pixelOffset = CGSize(width: translationNorm.width * cropRect.width,
                                 height: translationNorm.height * cropRect.height)

        return Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()
            .scaleEffect(visualScale)
            .rotationEffect(.degrees(rotation))
            .offset(pixelOffset)
            .frame(width: cropRect.width, height: cropRect.height)
            .position(x: cropRect.midX, y: cropRect.midY)
    }
    
    private func dragGesture(in cropRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { v in
                if !canDrag { canDrag = cropRect.contains(v.startLocation); lastDrag = .zero }
                if canDrag {
                    let delta = CGSize(width: v.translation.width - lastDrag.width,
                                       height: v.translation.height - lastDrag.height)
                    translationNorm = CGSize(width: translationNorm.width + delta.width / max(cropRect.width, 0.0001),
                                             height: translationNorm.height + delta.height / max(cropRect.height, 0.0001))
                    lastDrag = v.translation
                }
            }
            .onEnded { _ in
                canDrag = false
                lastDrag = .zero
            }
    }
    
    private func canvasGesture(container: CGSize, cropRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { v in
                if targetAspect == nil {
                    // Freeform: move the crop rect
                    let dx = v.translation.width / max(container.width, 0.0001)
                    let dy = v.translation.height / max(container.height, 0.0001)
                    var r = cropRectNorm
                    r.origin.x = clamp(r.origin.x + dx, 0.0, 1.0 - r.size.width)
                    r.origin.y = clamp(r.origin.y + dy, 0.0, 1.0 - r.size.height)
                    cropRectNorm = r
                } else {
                    // Constrained: drag the image under the fixed crop
                    if !canDrag { canDrag = cropRect.contains(v.startLocation); lastDrag = .zero }
                    if canDrag {
                        let delta = CGSize(width: v.translation.width - lastDrag.width,
                                           height: v.translation.height - lastDrag.height)
                        translationNorm = CGSize(width: translationNorm.width + delta.width / max(cropRect.width, 0.0001),
                                                 height: translationNorm.height + delta.height / max(cropRect.height, 0.0001))
                        lastDrag = v.translation
                    }
                }
            }
            .onEnded { _ in
                // Reset drag state for constrained mode
                canDrag = false
                lastDrag = .zero
            }
    }
    
    // MARK: - Freeform helpers
    
    private func clamp(_ value: CGFloat, _ minV: CGFloat, _ maxV: CGFloat) -> CGFloat {
        return max(minV, min(value, maxV))
    }
    
    private func handlePoints(for rect: CGRect) -> [CGPoint] {
        return [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
    }
    
    private func moveCropGesture(in container: CGSize, current: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { v in
                let dx = v.translation.width / max(container.width, 0.0001)
                let dy = v.translation.height / max(container.height, 0.0001)
                var r = cropRectNorm
                r.origin.x = clamp(r.origin.x + dx, 0.0, 1.0 - r.size.width)
                r.origin.y = clamp(r.origin.y + dy, 0.0, 1.0 - r.size.height)
                cropRectNorm = r
            }
    }
    
    private func resizeGesture(from handle: CGPoint, in container: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                // Convert current rect to absolute
                var rect = CGRect(x: cropRectNorm.origin.x * container.width,
                                  y: cropRectNorm.origin.y * container.height,
                                  width: cropRectNorm.size.width * container.width,
                                  height: cropRectNorm.size.height * container.height)
                // Determine which corner is being dragged by comparing distances
                let corners = [
                    ("tl", CGPoint(x: rect.minX, y: rect.minY)),
                    ("bl", CGPoint(x: rect.minX, y: rect.maxY)),
                    ("tr", CGPoint(x: rect.maxX, y: rect.minY)),
                    ("br", CGPoint(x: rect.maxX, y: rect.maxY))
                ]
                let tag = corners.min(by: { a, b in
                    hypot(handle.x - a.1.x, handle.y - a.1.y) < hypot(handle.x - b.1.x, handle.y - b.1.y)
                })!.0
    
                let newPoint = CGPoint(x: handle.x + v.translation.width,
                                       y: handle.y + v.translation.height)
                let minSize: CGFloat = 32.0
    
                switch tag {
                case "tl":
                    let nx = clamp(newPoint.x, 0, rect.maxX - minSize)
                    let ny = clamp(newPoint.y, 0, rect.maxY - minSize)
                    rect.origin.x = nx
                    rect.origin.y = ny
                    rect.size.width = rect.maxX - nx
                    rect.size.height = rect.maxY - ny
                case "bl":
                    let nx = clamp(newPoint.x, 0, rect.maxX - minSize)
                    let ny = clamp(newPoint.y, rect.minY + minSize, container.height)
                    rect.size.width = rect.maxX - nx
                    rect.size.height = ny - rect.minY
                    rect.origin.x = nx
                case "tr":
                    let nx = clamp(newPoint.x, rect.minX + minSize, container.width)
                    let ny = clamp(newPoint.y, 0, rect.maxY - minSize)
                    rect.size.width = nx - rect.minX
                    rect.size.height = rect.maxY - ny
                    rect.origin.y = ny
                case "br":
                    let nx = clamp(newPoint.x, rect.minX + minSize, container.width)
                    let ny = clamp(newPoint.y, rect.minY + minSize, container.height)
                    rect.size.width = nx - rect.minX
                    rect.size.height = ny - rect.minY
                default: break
                }
    
                // Normalize back
                var r = CGRect(x: rect.origin.x / max(container.width, 0.0001),
                               y: rect.origin.y / max(container.height, 0.0001),
                               width: rect.size.width / max(container.width, 0.0001),
                               height: rect.size.height / max(container.height, 0.0001))
                // Clamp to 0...1
                r.origin.x = clamp(r.origin.x, 0, 1 - r.size.width)
                r.origin.y = clamp(r.origin.y, 0, 1 - r.size.height)
                r.size.width = clamp(r.size.width, 0.01, 1.0)
                r.size.height = clamp(r.size.height, 0.01, 1.0)
                cropRectNorm = r
            }
    }
    
    private func fitAspectRect(in container: CGSize, aspect: CGSize) -> CGRect {
        let a = aspect.width / max(aspect.height, 0.0001)
        let w = container.width
        let h = w / a
        if h <= container.height {
            return CGRect(x: 0, y: (container.height - h)/2, width: w, height: h)
        } else {
            let hh = container.height
            let ww = hh * a
            return CGRect(x: (container.width - ww)/2, y: 0, width: ww, height: hh)
        }
    }
}
