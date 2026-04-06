//
//  Item.swift
//  PerchNotes
//
//  Created by TJ and Brianna Olsen on 4/5/26.
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
