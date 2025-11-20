//
//  ImageEditorView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//
//  DEPRECATED: This standalone window-based image editor has been replaced
//  with integrated editing in the Media tab using ImageCanvasView and MediaInspectorView.
//  This file is kept for reference but is no longer used in the app.
//


import SwiftUI
import AppKit

struct ImageEditorView: View {
    let originalURL: URL
    let editedURL: URL
    let label: ImageLabel?
    let initialTargetAspect: CGSize?
    let preferredMax: CGSize?
    let onSaved: () -> Void

    @State private var nsImage: NSImage?
    @State private var targetAspect: CGSize?

    // Normalized transform
    @State private var scaleRelCover: CGFloat = 1.0
    @State private var zoomText: String = "1.0x"
    @State private var rotation: CGFloat = 0.0 // degrees
    @State private var translationNorm: CGSize = .zero
    @State private var message: String = ""

    // Freeform crop rect, normalized to the view (x,y,width,height in 0...1)
    @State private var cropRectNorm: CGRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)

    var body: some View {
        VStack(spacing: 10) {
            controls.zIndex(1) 

            ZStack {
                if let img = nsImage {
                    CropCanvas(nsImage: img,
                               targetAspect: targetAspect,
                               scaleRelCover: $scaleRelCover,
                               rotation: $rotation,
                               translationNorm: $translationNorm,
                               cropRectNorm: $cropRectNorm)
                    .overlay(alignment: .bottomLeading) {
                        if !message.isEmpty {
                            Text(message)
                                .font(.footnote)
                                .padding(6)
                                .background(.thinMaterial)
                                .cornerRadius(6)
                                .padding()
                        }
                    }
                } else {
                    Text("Loading…").foregroundColor(.secondary)
                }
            }
            .frame(minHeight: 400)

            HStack {
                Button("Done") { save() }
                Button("Reset") {
                    scaleRelCover = 1.0
                    rotation = 0.0
                    translationNorm = .zero
                }
                Spacer()
                Button("Cancel") { closeWindow() }
            }
        }
        .padding(12)
        .padding(12)
        .onAppear { load() }
        .onChange(of: scaleRelCover) { _, newValue in
            zoomText = String(format: "%.2fx", newValue)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Zoom")

                Button {
                    adjustScale(by: 0.9)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }

                TextField("1.0x", text: $zoomText, onCommit: {
                    applyZoomText()
                })
                .frame(width: 70)
                .multilineTextAlignment(.center)

                Button {
                    adjustScale(by: 1.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
            }

            HStack(spacing: 8) {
                Text("Rot")
                Slider(value: $rotation, in: -180...180, step: 1)
                    .frame(width: 180)
                Stepper("", value: $rotation, in: -360...360, step: 1)
                    .labelsHidden()
                Text(String(format: "%.0f°", rotation))
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
            
            let nudge: CGFloat = 0.05

            VStack(spacing: 4) {
                Text("Position")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Button {
                        translationNorm.height -= nudge
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 4) {
                    Button {
                        translationNorm.width -= nudge
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Spacer()
                        .frame(width: 12)

                    Button {
                        translationNorm.width += nudge
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Button {
                        translationNorm.height += nudge
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    Spacer(minLength: 0)
                }
            }

            if label == .poster {
                Button("Flip 90°") {
                    if let aspect = targetAspect {
                        targetAspect = CGSize(width: aspect.height, height: aspect.width)
                        scaleRelCover = 1.0
                        rotation = 0.0
                        translationNorm = .zero
                    }
                }
            }

            Spacer()
        }
    }

    private func load() {
        if let img = NSImage(contentsOf: editedURL) ?? NSImage(contentsOf: originalURL) {
            nsImage = img
        }
        if let sidecar = EditedSidecarIO.load(for: editedURL) {
            scaleRelCover = max(0.1, sidecar.transform.scale)
            rotation = sidecar.transform.rotationDegrees
            translationNorm = sidecar.transform.translation
            targetAspect = sidecar.aspectOverride ?? initialTargetAspect
        } else {
            targetAspect = initialTargetAspect
        }

        zoomText = String(format: "%.2fx", scaleRelCover)
    }
    
    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(8.0, max(0.1, value))
    }

    private func adjustScale(by factor: CGFloat) {
        scaleRelCover = clampedScale(scaleRelCover * factor)
    }

    private func applyZoomText() {
        let cleaned = zoomText
            .replacingOccurrences(of: "x", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let val = Double(cleaned) {
            scaleRelCover = clampedScale(CGFloat(val))
            zoomText = String(format: "%.2fx", scaleRelCover)
        } else {
            // Invalid input: revert to current valid value
            zoomText = String(format: "%.2fx", scaleRelCover)
        }
    }

    private func save() {
        guard let img = nsImage else { return }

        let effectiveAspect: CGSize = {
            if let t = targetAspect { return t }
            // Use current freeform crop aspect; only the ratio matters
            return CGSize(width: max(cropRectNorm.width, 0.0001),
                          height: max(cropRectNorm.height, 0.0001))
        }()

        let options = CoverRenderOptions(
            targetAspect: effectiveAspect,
            targetMaxPixels: preferredMax,
            output: .png,
            enforceCover: false
        )

        let transform = UserTransform(scale: scaleRelCover,
                                      rotationDegrees: rotation,
                                      translation: translationNorm)
        guard let rendered = CoverRender.renderCover(nsImage: img, options: options, userTransform: transform) else {
            message = "Render failed"
            return
        }

        var outURL = editedURL
        if editedURL.pathExtension.lowercased() != "png" {
            outURL = editedURL.deletingPathExtension().appendingPathExtension("png")
        }

        do {
            let dir = outURL.deletingLastPathComponent()
            let tmp = dir.appendingPathComponent(".tmp-\(UUID().uuidString)").appendingPathExtension(outURL.pathExtension)
            switch options.output {
            case .jpeg(let q): try rendered.writeJPEG(to: tmp, quality: q)
            case .png: try rendered.writePNG(to: tmp)
            }
            if FileManager.default.fileExists(atPath: outURL.path) {
                try SafeFileWriter.atomicReplaceFile(at: outURL, from: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: outURL)
            }

            EditedSidecarIO.save(EditedSidecar(transform: transform, aspectOverride: effectiveAspect), for: outURL)

            message = "Saved"
            onSaved()
            closeWindow()
        } catch {
            message = "Save error: \(error.localizedDescription)"
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}
