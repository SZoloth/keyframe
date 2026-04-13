import Testing
import Foundation
@testable import Keyframe

@Suite("Undo/redo across phase mutations", .serialized)
@MainActor
struct UndoRedoFlowTests {

    @Test func undoAfterSetPhaseRestoresPreviousPhase() {
        let state = AppState()
        #expect(state.project.currentPhase == .setup)

        state.setPhase(.style)
        #expect(state.project.currentPhase == .style)

        state.undo()
        #expect(state.project.currentPhase == .setup)
    }

    @Test func undoAfterLockStyleRestoresUnlockedAndPhase() {
        let state = AppState()
        state.addReferenceImage(Data([1]))
        state.setStyleDescription("Sketch")
        state.lockStyle()

        #expect(state.project.style.locked == true)
        #expect(state.project.currentPhase == .cast)

        state.undo()
        #expect(state.project.style.locked == false)
        #expect(state.project.currentPhase != .cast)
    }

    @Test func undoAfterAddCharacterRestoresEmptyCharacters() {
        let state = AppState()
        state.addCharacter(StoryboardCharacter(name: "A", role: "R", visualDescription: "V"))
        #expect(state.project.characters.count == 1)

        state.undo()
        #expect(state.project.characters.isEmpty)
    }

    @Test func redoAfterUndoRestoresChange() {
        let state = AppState()
        state.addCharacter(StoryboardCharacter(name: "B", role: "R", visualDescription: "V"))
        state.undo()
        #expect(state.project.characters.isEmpty)

        state.redo()
        #expect(state.project.characters.count == 1)
        #expect(state.project.characters[0].name == "B")
    }

    @Test func multipleUndosWalkBackThroughHistory() {
        let state = AppState()
        state.setPhase(.style)
        state.addReferenceImage(Data([1]))
        state.setStyleDescription("Pencil")

        state.undo()
        #expect(state.project.style.description == "")

        state.undo()
        #expect(state.project.style.referenceImages.isEmpty)

        state.undo()
        #expect(state.project.currentPhase == .setup)
    }

    @Test func historyIsCappedAt50() {
        let state = AppState()
        for i in 1...55 {
            state.addCharacter(StoryboardCharacter(
                name: "Char\(i)", role: "R", visualDescription: "V"
            ))
        }
        #expect(state.project.characters.count == 55)

        var undoCount = 0
        while state.canUndo {
            state.undo()
            undoCount += 1
        }
        #expect(undoCount == 50)
    }

    @Test func interleavedMutationsWithUndo() {
        let state = AppState()
        state.setPhase(.style)
        state.lockStyle()
        state.addCharacter(StoryboardCharacter(name: "X", role: "R", visualDescription: "V"))

        state.undo()
        #expect(state.project.characters.isEmpty)
        #expect(state.project.currentPhase == .cast)

        state.undo()
        #expect(state.project.style.locked == false)

        state.undo()
        #expect(state.project.currentPhase == .setup)
    }
}
