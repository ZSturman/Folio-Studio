//
//  ImageEditorCoordinator.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//


// ImageEditorCoordinator.swift

import SwiftUI
import AppKit

enum ImageEditorCoordinator {
    static func openEditor(originalURL: URL,
                           editedURL: URL,
                           label: ImageLabel,
                           onSaved: @escaping () -> Void) {
        let sidecar = EditedSidecarIO.load(for: editedURL)
        let initialAspect = sidecar?.aspectOverride ?? label.targetAspect(using: nil)

        let view = ImageEditorView(originalURL: originalURL,
                                   editedURL: editedURL,
                                   label: label,
                                   initialTargetAspect: initialAspect,
                                   preferredMax: label.preferredMaxPixels,
                                   onSaved: onSaved)
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Edit \(editedURL.lastPathComponent)"
        win.setContentSize(NSSize(width: 900, height: 620))
        win.styleMask = [.titled, .closable, .resizable]
        win.center()
        win.makeKeyAndOrderFront(nil as Any?)
    }

    static func openEditorAllowingAspectChoice(originalURL: URL,
                                               editedURL: URL,
                                               suggestedAspect: CGSize?,
                                               onSaved: @escaping () -> Void) {
        let chosen = AspectPrompt.chooseAspect(originalURL: originalURL, suggested: suggestedAspect)
        let target = chosen ?? (NSImage(contentsOf: originalURL)?.size ?? CGSize(width: 1, height: 1))
        let view = ImageEditorView(originalURL: originalURL,
                                   editedURL: editedURL,
                                   label: nil,
                                   initialTargetAspect: target,
                                   preferredMax: nil,
                                   onSaved: onSaved)
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Edit \(editedURL.lastPathComponent)"
        win.setContentSize(NSSize(width: 900, height: 620))
        win.styleMask = [.titled, .closable, .resizable]
        win.center()
        win.makeKeyAndOrderFront(nil as Any?)
    }

    static func openEditorFreeform(originalURL: URL,
                                   editedURL: URL,
                                   onSaved: @escaping () -> Void) {
        let view = ImageEditorView(originalURL: originalURL,
                                   editedURL: editedURL,
                                   label: nil,
                                   initialTargetAspect: nil,
                                   preferredMax: nil,
                                   onSaved: onSaved)
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Edit \(editedURL.lastPathComponent)"
        win.setContentSize(NSSize(width: 900, height: 620))
        win.styleMask = [.titled, .closable, .resizable]
        win.center()
        win.makeKeyAndOrderFront(nil as Any?)
    }

    private enum AspectPrompt {
        static func chooseAspect(originalURL: URL, suggested: CGSize?) -> CGSize? {
            let alert = NSAlert()
            alert.messageText = "Choose Aspect Ratio"
            alert.informativeText = "Pick a target aspect ratio for this edit."

            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            popup.addItems(withTitles: ["Use image aspect", "Square 1:1", "16:9", "4:5", "3:2", "Custom…"])
            popup.selectItem(at: 0)

            let customField = NSTextField(string: "1:1")
            customField.isEnabled = false
            customField.placeholderString = "W:H"

            let stack = NSStackView()
            stack.orientation = .vertical
            stack.spacing = 8
            stack.addArrangedSubview(popup)
            stack.addArrangedSubview(customField)

            let targetToggle = BlockTarget { customField.isEnabled = (popup.indexOfSelectedItem == 5) }
            popup.target = targetToggle
            popup.action = #selector(BlockTarget.fire)

            alert.accessoryView = stack
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let resp = alert.runModal()
            guard resp == .alertFirstButtonReturn else { return nil }

            let imgSize = NSImage(contentsOf: originalURL)?.size
            let fallback = suggested ?? imgSize ?? CGSize(width: 1, height: 1)

            switch popup.indexOfSelectedItem {
            case 0: return imgSize ?? fallback
            case 1: return CGSize(width: 1, height: 1)
            case 2: return CGSize(width: 16, height: 9)
            case 3: return CGSize(width: 4, height: 5)
            case 4: return CGSize(width: 3, height: 2)
            case 5:
                let parts = customField.stringValue.split(separator: ":")
                if parts.count == 2,
                   let w = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let h = Double(parts[1].trimmingCharacters(in: .whitespaces)),
                   w > 0, h > 0 {
                    return CGSize(width: w, height: h)
                }
                return fallback
            default:
                return fallback
            }
        }
    }

    private final class BlockTarget: NSObject {
        private let block: () -> Void
        init(_ block: @escaping () -> Void) { self.block = block }
        @objc func fire() { block() }
    }
}
