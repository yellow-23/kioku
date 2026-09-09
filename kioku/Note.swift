import Foundation
import SwiftData

@Model
final class Note {
    var title: String = ""
    var body: String = ""
    var tags: String = ""
    var pinned: Bool = false
    var completed: Bool = false
    var colorHex: String = "#FFE07A"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}
}
