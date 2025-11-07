//
//  SafeFileWriter.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//


import Foundation

enum SafeFileWriter {
    static func atomicReplace(at destination: URL, data: Data) throws {
        let dir = destination.deletingLastPathComponent()
        let tmp = dir.appendingPathComponent(".tmp-\(UUID().uuidString)")
        try data.write(to: tmp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: tmp, backupItemName: nil, options: .usingNewMetadataOnly)
    }

    static func atomicReplaceFile(at destination: URL, from source: URL) throws {
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: source, backupItemName: nil, options: .usingNewMetadataOnly)
    }
}
