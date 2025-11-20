//
//  SeedLedger.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import Foundation
import SwiftData

@Model
final class SeedLedger {
    // Unique key per seed task, so you can track multiple seeders independently.
    @Attribute(.unique) var key: String
    var version: Int
    var seededAt: Date

    init(key: String, version: Int) {
        self.key = key
        self.version = version
        self.seededAt = Date()
    }
}
