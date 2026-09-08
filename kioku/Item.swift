//
//  Item.swift
//  kioku
//
//  Created by Cristobal Flores Villegas on 08-09-26.
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
