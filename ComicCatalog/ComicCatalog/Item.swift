//
//  Item.swift
//  ComicCatalog
//
//  Created by Russell Allen on 2/2/26.
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
