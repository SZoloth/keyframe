import Foundation

struct StoryboardCharacter: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var role: String
    var visualDescription: String
    var referenceImageData: Data?

    init(
        id: String = "char-\(UUID().uuidString)",
        name: String,
        role: String,
        visualDescription: String,
        referenceImageData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.visualDescription = visualDescription
        self.referenceImageData = referenceImageData
    }
}
