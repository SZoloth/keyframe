import Foundation

struct FrameBeat: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let guidance: String
}

struct Template: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let frames: [FrameBeat]

    var isCustom: Bool {
        id.hasPrefix("custom-")
    }
}
