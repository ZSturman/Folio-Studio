//
//  EditedSidecar.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

// EditedSidecar.swift
import Foundation
import CoreGraphics

struct EditedSidecar: Codable {
    var transform: UserTransform
    var aspectOverride: CGSize?
}

enum EditedSidecarIO {
    static func url(for editedURL: URL) -> URL {
        editedURL.deletingPathExtension().appendingPathExtension("json")
    }

    static func load(for editedURL: URL) -> EditedSidecar? {
        let u = url(for: editedURL)
        guard let data = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(EditedSidecar.self, from: data)
    }

    static func save(_ sidecar: EditedSidecar, for editedURL: URL) {
        let u = url(for: editedURL)
        if let data = try? JSONEncoder().encode(sidecar) {
            try? SafeFileWriter.atomicReplace(at: u, data: data)
        }
    }
}
