//
//  AspectRatioPreviewBox.swift
//  ImageEditor
//

import SwiftUI

struct AspectRatioPreviewBox: View {
    let aspectRatio: AspectRatio
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Container box
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 80, height: 80)
                
                // Aspect ratio preview
                if let ratio = aspectRatio.ratio {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                        )
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .aspectRatio(ratio, contentMode: .fit)
                        .padding(12)
                } else {
                    // Free form - show full box
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                        )
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .padding(12)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            
            VStack(spacing: 2) {
                Text(aspectRatio.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text(aspectRatio.displayRatio)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct AspectRatioSidebarView: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Aspect Ratio")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(AspectRatio.allCases) { ratio in
                        Button(action: {
                            viewModel.updateAspectRatio(ratio)
                        }) {
                            AspectRatioPreviewBox(
                                aspectRatio: ratio,
                                isSelected: viewModel.selectedAspectRatio == ratio
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 250)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
