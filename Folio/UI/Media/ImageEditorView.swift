//
//  ImageEditorView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//
//


import SwiftUI
import AppKit

struct ImageEditorView: View {
    let originalURL: URL
    let editedURL: URL
    let targetAspect: CGSize?
    let preferredMax: CGSize?
    let onSaved: () -> Void

    @State private var nsImage: NSImage?

    // Normalized transform
    @State private var scaleRelCover: CGFloat = 1.0
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
        .onAppear { load() }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Scale")
                Slider(value: $scaleRelCover, in: 0.1...8.0)
                    .frame(width: 180)
                Stepper("", value: $scaleRelCover, in: 0.1...8.0, step: 0.05)
                    .labelsHidden()
                Text(String(format: "%.2fx cover", scaleRelCover))
                    .monospacedDigit()
                    .frame(width: 90, alignment: .trailing)
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

            HStack(spacing: 8) {
                Text("X")
                Slider(value: $translationNorm.width, in: -5...5)
                    .frame(width: 180)
                Stepper("", value: $translationNorm.width, in: -5...5, step: 0.01)
                    .labelsHidden()
                Text(String(format: "%0.2f W", translationNorm.width))
                    .monospacedDigit()
                    .frame(width: 70, alignment: .trailing)
            }

            HStack(spacing: 8) {
                Text("Y")
                Slider(value: $translationNorm.height, in: -5...5)
                    .frame(width: 180)
                Stepper("", value: $translationNorm.height, in: -5...5, step: 0.01)
                    .labelsHidden()
                Text(String(format: "%0.2f H", translationNorm.height))
                    .monospacedDigit()
                    .frame(width: 70, alignment: .trailing)
            }

            Spacer()
        }
    }

    private func load() {
        if let img = NSImage(contentsOf: originalURL) {
            nsImage = img
        }
        if let sidecar = EditedSidecarIO.load(for: editedURL) {
            // Interpret stored transform as normalized
            scaleRelCover = max(0.1, sidecar.transform.scale)
            rotation = sidecar.transform.rotationDegrees
            translationNorm = sidecar.transform.translation
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

            EditedSidecarIO.save(EditedSidecar(transform: transform), for: outURL)

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
