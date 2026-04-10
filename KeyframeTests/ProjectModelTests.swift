import Testing
import Foundation
@testable import Keyframe

@Suite("Project model round-trip encoding")
struct ProjectModelTests {

    @Test("Empty project round-trips through JSON")
    func emptyProjectRoundTrip() throws {
        let project = Project.empty
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        #expect(decoded.currentPhase == .setup)
        #expect(decoded.frames.isEmpty)
        #expect(decoded.characters.isEmpty)
        #expect(decoded.style == .empty)
        #expect(decoded.selectedTemplateId == nil)
        #expect(decoded.customTemplates.isEmpty)
    }

    @Test("Project with frames and characters round-trips")
    func populatedProjectRoundTrip() throws {
        var project = Project.empty
        project.selectedTemplateId = "raskin-pitch"
        project.currentPhase = .frames
        project.frames = [
            StoryboardFrame(beatId: "raskin-1", beatTitle: "The Old World"),
            StoryboardFrame(beatId: "raskin-2", beatTitle: "The Shift", status: .complete),
        ]
        project.characters = [
            StoryboardCharacter(name: "Alice", role: "Protagonist", visualDescription: "Tall with red hair"),
        ]
        project.style = StyleDefinition(
            referenceImages: [Data([0x89, 0x50, 0x4E, 0x47])],
            description: "Pencil sketch style",
            locked: true
        )

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        #expect(decoded.selectedTemplateId == "raskin-pitch")
        #expect(decoded.currentPhase == .frames)
        #expect(decoded.frames.count == 2)
        #expect(decoded.frames[1].status == .complete)
        #expect(decoded.characters.count == 1)
        #expect(decoded.characters[0].name == "Alice")
        #expect(decoded.style.locked == true)
        #expect(decoded.style.referenceImages.count == 1)
    }

    @Test("Template lookup finds built-in templates")
    func templateLookup() {
        let raskin = BuiltInTemplates.find(byId: "raskin-pitch")
        #expect(raskin != nil)
        #expect(raskin?.frames.count == 5)
        #expect(raskin?.name == "Raskin Pitch")

        let hero = BuiltInTemplates.find(byId: "hero-journey")
        #expect(hero != nil)
        #expect(hero?.frames.count == 8)

        let ps = BuiltInTemplates.find(byId: "problem-solution")
        #expect(ps != nil)
        #expect(ps?.frames.count == 3)

        let missing = BuiltInTemplates.find(byId: "nonexistent")
        #expect(missing == nil)
    }

    @Test("Template lookup finds custom templates")
    func customTemplateLookup() {
        let custom = Template(
            id: "custom-123",
            name: "My Template",
            description: "A custom template",
            frames: [FrameBeat(id: "b1", title: "Beat 1", guidance: "Do something")]
        )
        let found = BuiltInTemplates.find(byId: "custom-123", customTemplates: [custom])
        #expect(found != nil)
        #expect(found?.name == "My Template")
        #expect(found?.isCustom == true)
    }

    @Test("Phase ordering is correct")
    func phaseOrdering() {
        let phases = Phase.allCases
        #expect(phases == [.setup, .style, .cast, .frames, .export])
        #expect(Phase.setup.index == 0)
        #expect(Phase.export.index == 4)
    }
}
