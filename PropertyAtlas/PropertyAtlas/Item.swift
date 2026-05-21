//
//  Item.swift
//  PropertyAtlas
//
//  Created by fujie on 2026/5/21.
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
