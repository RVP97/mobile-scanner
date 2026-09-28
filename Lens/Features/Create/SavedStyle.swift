import Foundation
import SwiftData

// OWNER: Create module. A reusable look for created codes ("My styles").
@Model
final class SavedStyle {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now
    /// Encoded `CodeStyle`.
    var styleData: Data = Data()

    init(name: String, styleData: Data) {
        self.name = name
        self.styleData = styleData
    }
}
