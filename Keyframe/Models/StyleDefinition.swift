import Foundation

struct StyleDefinition: Codable, Hashable {
    var referenceImages: [Data]
    var description: String
    var locked: Bool

    static let empty = StyleDefinition(
        referenceImages: [],
        description: "",
        locked: false
    )
}
