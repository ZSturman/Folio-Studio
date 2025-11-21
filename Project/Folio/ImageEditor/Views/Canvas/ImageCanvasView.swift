//
//  ImageCanvasView.swift
//  ImageEditor
//

import SwiftUI
import UniformTypeIdentifiers

struct ImageCanvasView: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    @State private var isDraggingImage = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(NSColor.controlBackgroundColor)
                
                if viewModel.editingState.isImageLoaded {
                    // Calculate the aspect ratio frame size
                    let aspectFrameSize = calculateAspectFrameSize(in: geometry.size)
                    
                    // Display the image with scale applied via SwiftUI (maintains quality)
                    if let displayImage = viewModel.displayImage {
                        Image(nsImage: displayImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(viewModel.currentTransform.scale)
                            .frame(width: aspectFrameSize.width, height: aspectFrameSize.height)
                    }
                    
                    // Aspect ratio crop overlay (shows what will be exported)
                    if viewModel.selectedAspectRatio != .free {
                        cropOverlay(in: geometry.size, aspectFrameSize: aspectFrameSize)
                    }
                } else {
                    // Empty state with aspect ratio preview
                    emptyStateView(in: geometry.size)
                }
            }
            .onAppear {
                viewModel.updateCanvasSize(geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                viewModel.updateCanvasSize(newSize)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private func calculateAspectFrameSize(in canvasSize: CGSize) -> CGSize {
        guard let ratio = viewModel.selectedAspectRatio.ratio else {
            return canvasSize
        }
        
        // Calculate the size that fits 95% of canvas while maintaining aspect ratio
        let maxWidth = canvasSize.width * 0.95
        let maxHeight = canvasSize.height * 0.95
        
        let widthForHeight = maxHeight * ratio
        let heightForWidth = maxWidth / ratio
        
        if widthForHeight <= maxWidth {
            return CGSize(width: widthForHeight, height: maxHeight)
        } else {
            return CGSize(width: maxWidth, height: heightForWidth)
        }
    }
    
    @ViewBuilder
    private func emptyStateView(in size: CGSize) -> some View {
        VStack(spacing: 20) {
            if let ratio = viewModel.selectedAspectRatio.ratio {
                // Show aspect ratio preview box
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 3, dash: [10, 5])
                    )
                    .foregroundColor(.secondary.opacity(0.5))
                    .aspectRatio(ratio, contentMode: .fit)
                    .frame(maxWidth: size.width * 0.7, maxHeight: size.height * 0.7)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("Import an image")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Text("\(viewModel.selectedAspectRatio.displayRatio) ratio")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            } else {
                // Free form - just show import message
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("Import an image to begin")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func cropOverlay(in size: CGSize, aspectFrameSize: CGSize) -> some View {
        // Show the crop region as an overlay with dimmed areas outside
        if viewModel.selectedAspectRatio.ratio != nil {
            ZStack {
                // Dimmed overlay for areas outside crop
                Color.black.opacity(0.5)
                
                // Clear area showing the crop region
                Rectangle()
                    .frame(width: aspectFrameSize.width, height: aspectFrameSize.height)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .allowsHitTesting(false)
            
            // Border showing crop bounds
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white, lineWidth: 2)
                .frame(width: aspectFrameSize.width, height: aspectFrameSize.height)
                .shadow(color: .black.opacity(0.3), radius: 2)
                .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private func aspectRatioGuide(in size: CGSize, ratio: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
            )
            .foregroundColor(.accentColor.opacity(0.6))
            .aspectRatio(ratio, contentMode: .fit)
            .frame(maxWidth: size.width * 0.95, maxHeight: size.height * 0.95)
            .allowsHitTesting(false)
    }
}
