//
//  Item.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
