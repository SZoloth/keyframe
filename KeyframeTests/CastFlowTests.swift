import Testing
import Foundation
@testable import Keyframe

@Suite("Cast screen flow", .serialized)
@MainActor
struct CastFlowTests {

    @Test func addCharacterIncreasesCount() {
        let state = AppState()
        let char = StoryboardCharacter(name: "Alice", role: "Hero", visualDescription: "Tall with red hair")
        state.addCharacter(char)

        #expect(state.project.characters.count == 1)
        #expect(state.project.characters[0].name == "Alice")
        #expect(state.project.characters[0].role == "Hero")
        #expect(state.project.characters[0].visualDescription == "Tall with red hair")
    }

    @Test func updateCharacterNameOnly() {
        let state = AppState()
        let char = StoryboardCharacter(name: "Bob", role: "Villain", visualDescription: "Dark cloak")
        state.addCharacter(char)

        state.updateCharacter(char.id, name: "Robert")

        #expect(state.project.characters[0].name == "Robert")
        #expect(state.project.characters[0].role == "Villain")
        #expect(state.project.characters[0].visualDescription == "Dark cloak")
    }

    @Test func updateCharacterRoleOnly() {
        let state = AppState()
        let char = StoryboardCharacter(name: "Eve", role: "Sidekick", visualDescription: "Small and quick")
        state.addCharacter(char)

        state.updateCharacter(char.id, role: "Mentor")

        #expect(state.project.characters[0].name == "Eve")
        #expect(state.project.characters[0].role == "Mentor")
    }

    @Test func updateCharacterVisualDescriptionOnly() {
        let state = AppState()
        let char = StoryboardCharacter(name: "Dan", role: "Lead", visualDescription: "Glasses")
        state.addCharacter(char)

        state.updateCharacter(char.id, visualDescription: "Sunglasses, leather jacket")

        #expect(state.project.characters[0].visualDescription == "Sunglasses, leather jacket")
        #expect(state.project.characters[0].name == "Dan")
    }

    @Test func removeCharacterByID() {
        let state = AppState()
        let char1 = StoryboardCharacter(name: "A", role: "R", visualDescription: "V")
        let char2 = StoryboardCharacter(name: "B", role: "R", visualDescription: "V")
        state.addCharacter(char1)
        state.addCharacter(char2)

        state.removeCharacter(char1.id)

        #expect(state.project.characters.count == 1)
        #expect(state.project.characters[0].name == "B")
    }

    @Test func updateCharacterWithNonexistentIdDoesNothing() {
        let state = AppState()
        let char = StoryboardCharacter(name: "A", role: "R", visualDescription: "V")
        state.addCharacter(char)

        state.updateCharacter("nonexistent-id", name: "Changed")

        #expect(state.project.characters[0].name == "A")
    }

    @Test func removeCharacterWithNonexistentIdDoesNothing() {
        let state = AppState()
        let char = StoryboardCharacter(name: "A", role: "R", visualDescription: "V")
        state.addCharacter(char)

        state.removeCharacter("nonexistent-id")

        #expect(state.project.characters.count == 1)
    }

    @Test func canAdvanceToFramesRequiresCharacters() {
        let state = AppState()
        #expect(state.canAdvanceToPhase(.frames) == false)

        state.addCharacter(StoryboardCharacter(name: "A", role: "R", visualDescription: "V"))
        #expect(state.canAdvanceToPhase(.frames) == true)
    }

    @Test func addCharacterThenProceedToFrames() {
        let state = AppState()
        state.addCharacter(StoryboardCharacter(name: "Hero", role: "Lead", visualDescription: "Tall"))
        state.setPhase(.frames)

        #expect(state.project.currentPhase == .frames)
    }
}
