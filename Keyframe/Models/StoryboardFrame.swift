import Foundation

enum FrameStatus: String, Codable {
    case empty
    case generating
    case complete
}

struct StoryboardFrame: Codable, Identifiable, Hashable {
    let id: String
    let beatId: String
    var beatTitle: String
    var caption: String
    var sceneDescription: String?
    var imageData: Data?
    var status: FrameStatus

    init(
        id: String = "frame-\(UUID().uuidString)",
        beatId: String,
        beatTitle: String,
        caption: String? = nil,
        sceneDescription: String? = nil,
        imageData: Data? = nil,
        status: FrameStatus = .empty
    ) {
        self.id = id
        self.beatId = beatId
        self.beatTitle = beatTitle
        self.caption = caption ?? beatTitle
        self.sceneDescription = sceneDescription
        self.imageData = imageData
        self.status = status
    }
}
