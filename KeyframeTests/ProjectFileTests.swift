import Testing
import Foundation
@testable import Keyframe

@Suite("Project file persistence")
struct ProjectFileTests {

    @Test func roundTripEncodeDecode() throws {
        var project = Project.empty
        project.selectedTemplateId = "raskin-pitch"
        project.frames = [
            StoryboardFrame(beatId: "b1", beatTitle: "Opening"),
            StoryboardFrame(beatId: "b2", beatTitle: "Conflict"),
        ]
        project.characters = [
            StoryboardCharacter(name: "Alice", role: "Lead", visualDescription: "Tall, red hair"),
        ]
        project.style = StyleDefinition(referenceImages: [], description: "Pencil sketch", locked: true)
        project.currentPhase = .frames

        let file = ProjectFileManager.ProjectFile(
            project: project,
            selectedFrameId: project.frames.first?.id
        )

        let data = try JSONEncoder().encode(file)
        #expect(!data.isEmpty)

        let decoded = try JSONDecoder().decode(ProjectFileManager.ProjectFile.self, from: data)
        #expect(decoded.version == 1)
        #expect(decoded.project.selectedTemplateId == "raskin-pitch")
        #expect(decoded.project.frames.count == 2)
        #expect(decoded.project.characters.count == 1)
        #expect(decoded.project.characters[0].name == "Alice")
        #expect(decoded.project.style.locked)
        #expect(decoded.project.style.description == "Pencil sketch")
        #expect(decoded.project.currentPhase == .frames)
        #expect(decoded.selectedFrameId == project.frames.first?.id)
    }

    @Test func emptyProjectRoundTrips() throws {
        let file = ProjectFileManager.ProjectFile(project: .empty, selectedFrameId: nil)
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ProjectFileManager.ProjectFile.self, from: data)
        #expect(decoded.project.frames.isEmpty)
        #expect(decoded.project.characters.isEmpty)
        #expect(decoded.selectedFrameId == nil)
    }

    @Test func customTemplatesRoundTrip() throws {
        var project = Project.empty
        let template = Template(
            id: "custom-123",
            name: "Weekly Update",
            description: "For team updates",
            frames: [
                FrameBeat(id: "beat-1", title: "Week highlights", guidance: "What went well"),
                FrameBeat(id: "beat-2", title: "Challenges", guidance: "Blockers and risks"),
            ]
        )
        project.customTemplates = [template]

        let file = ProjectFileManager.ProjectFile(project: project, selectedFrameId: nil)
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ProjectFileManager.ProjectFile.self, from: data)

        #expect(decoded.project.customTemplates.count == 1)
        #expect(decoded.project.customTemplates[0].name == "Weekly Update")
        #expect(decoded.project.customTemplates[0].frames.count == 2)
        #expect(decoded.project.customTemplates[0].isCustom)
    }

    @Test func characterWithReferenceImageRoundTrips() throws {
        var project = Project.empty
        let imgData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        project.characters = [
            StoryboardCharacter(name: "Hero", role: "Lead", visualDescription: "Tall", referenceImageData: imgData),
            StoryboardCharacter(name: "Sidekick", role: "Support", visualDescription: ""),
        ]

        let file = ProjectFileManager.ProjectFile(project: project, selectedFrameId: nil)
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ProjectFileManager.ProjectFile.self, from: data)

        #expect(decoded.project.characters.count == 2)
        #expect(decoded.project.characters[0].referenceImageData == imgData)
        #expect(decoded.project.characters[0].name == "Hero")
        #expect(decoded.project.characters[1].referenceImageData == nil)
        #expect(decoded.project.characters[1].visualDescription == "")
    }

    @Test func fullProjectWithAllFieldsRoundTrips() throws {
        var project = Project.empty
        project.currentPhase = .export
        project.selectedTemplateId = "hero-journey"
        project.style = StyleDefinition(
            referenceImages: [Data([1, 2]), Data([3, 4])],
            description: "Watercolor with bold outlines",
            locked: true
        )
        project.characters = [
            StoryboardCharacter(name: "Alice", role: "Hero", visualDescription: "Red hair"),
            StoryboardCharacter(name: "Bob", role: "Villain", visualDescription: "", referenceImageData: Data([5, 6])),
        ]
        project.frames = [
            StoryboardFrame(beatId: "b1", beatTitle: "Opening", sceneDescription: "A forest", imageData: Data([7, 8]), status: .complete),
            StoryboardFrame(beatId: "b2", beatTitle: "Climax", caption: "The battle", status: .generating),
            StoryboardFrame(beatId: "b3", beatTitle: "Resolution", status: .empty),
        ]
        project.customTemplates = [
            Template(id: "custom-rt", name: "My Flow", description: "Custom", frames: [
                FrameBeat(id: "fb1", title: "Act 1", guidance: "Setup")
            ])
        ]

        let file = ProjectFileManager.ProjectFile(project: project, selectedFrameId: project.frames[1].id)
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ProjectFileManager.ProjectFile.self, from: data)

        #expect(decoded.project.currentPhase == .export)
        #expect(decoded.project.selectedTemplateId == "hero-journey")
        #expect(decoded.project.style.locked == true)
        #expect(decoded.project.style.referenceImages.count == 2)
        #expect(decoded.project.style.description == "Watercolor with bold outlines")
        #expect(decoded.project.characters.count == 2)
        #expect(decoded.project.characters[1].referenceImageData == Data([5, 6]))
        #expect(decoded.project.frames.count == 3)
        #expect(decoded.project.frames[0].imageData == Data([7, 8]))
        #expect(decoded.project.frames[0].status == .complete)
        #expect(decoded.project.frames[1].caption == "The battle")
        #expect(decoded.project.frames[1].status == .generating)
        #expect(decoded.project.frames[2].status == .empty)
        #expect(decoded.project.customTemplates.count == 1)
        #expect(decoded.selectedFrameId == project.frames[1].id)
    }

    @Test func imageDataSurvivesRoundTrip() throws {
        var project = Project.empty
        let fakeImage = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
        project.frames = [
            StoryboardFrame(beatId: "b1", beatTitle: "Scene", imageData: fakeImage, status: .complete),
        ]
        project.style = StyleDefinition(referenceImages: [fakeImage], description: "test", locked: false)

        let file = ProjectFileManager.ProjectFile(project: project, selectedFrameId: nil)
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ProjectFileManager.ProjectFile.self, from: data)

        #expect(decoded.project.frames[0].imageData == fakeImage)
        #expect(decoded.project.style.referenceImages[0] == fakeImage)
    }
}
