
import Foundation

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var title: String
    var body: String
    var tag: String?

    init(id: UUID = UUID(), date: Date = Date(), title: String = "", body: String = "", tag: String? = nil) {
        self.id = id
        self.date = date
        self.title = title
        self.body = body
        self.tag = tag
    }
}
