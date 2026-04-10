import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let keyframeProject = UTType(
        exportedAs: "com.keyframe.project",
        conformingTo: .json
    )
}

struct Project: Codable, Equatable {
    var currentPhase: Phase
    var selectedTemplateId: String?
    var frames: [StoryboardFrame]
    var style: StyleDefinition
    var characters: [StoryboardCharacter]
    var customTemplates: [Template]

    static let empty = Project(
        currentPhase: .setup,
        selectedTemplateId: nil,
        frames: [],
        style: .empty,
        characters: [],
        customTemplates: []
    )

    var selectedFrameId: String?
}
