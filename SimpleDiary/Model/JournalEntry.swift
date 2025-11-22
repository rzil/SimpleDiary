
import Foundation

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var title: String
    var body: String

    init(id: UUID = UUID(), date: Date = Date(), title: String = "", body: String = "") {
        self.id = id
        self.date = date
        self.title = title
        self.body = body
    }
}
