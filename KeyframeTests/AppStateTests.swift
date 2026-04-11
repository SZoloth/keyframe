import Testing
import Foundation
@testable import Keyframe

@Suite("AppState mutations and undo/redo", .serialized)
@MainActor
struct AppStateTests {

    @Test func selectTemplatePopulatesFrames() {
        let state = AppState()
        state.selectTemplate("raskin-pitch")

        #expect(state.project.selectedTemplateId == "raskin-pitch")
        #expect(state.project.frames.count == 5)
        #expect(state.project.frames[0].beatTitle == "The Old World")
        #expect(state.selectedFrameId == state.project.frames[0].id)
    }

    @Test func selectFreeformCreatesOneFrame() {
        let state = AppState()
        state.selectTemplate("freeform")

        #expect(state.project.selectedTemplateId == "freeform")
        #expect(state.project.frames.count == 1)
        #expect(state.project.frames[0].beatTitle == "Frame 1")
    }

    @Test func characterAddAndRemove() {
        let state = AppState()
        let char = StoryboardCharacter(name: "Alice", role: "Hero", visualDescription: "Tall")
        state.addCharacter(char)

        #expect(state.project.characters.count == 1)
        #expect(state.project.characters[0].name == "Alice")

        state.removeCharacter(char.id)
        #expect(state.project.characters.isEmpty)
    }

    @Test func updateFrameMergesPartialUpdates() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let frameId = state.project.frames[0].id

        state.updateFrame(frameId, caption: "New caption", status: .complete)

        #expect(state.project.frames[0].caption == "New caption")
        #expect(state.project.frames[0].status == .complete)
        #expect(state.project.frames[0].beatTitle == "Before")
    }

    @Test func undoReversesLastMutation() {
        let state = AppState()
        state.selectTemplate("raskin-pitch")
        #expect(state.project.frames.count == 5)

        state.undo()
        #expect(state.project.frames.isEmpty)
        #expect(state.project.selectedTemplateId == nil)
    }

    @Test func redoReappliesAfterUndo() {
        let state = AppState()
        state.selectTemplate("hero-journey")
        #expect(state.project.frames.count == 8)

        state.undo()
        #expect(state.project.frames.isEmpty)

        state.redo()
        #expect(state.project.frames.count == 8)
    }

    @Test func undoOnEmptyHistoryDoesNothing() {
        let state = AppState()
        state.undo()
        #expect(state.project == .empty)
    }

    @Test func phaseGating() {
        let state = AppState()

        #expect(state.canAdvanceToPhase(.setup) == true)
        #expect(state.canAdvanceToPhase(.style) == false)

        state.authMode = .oauth(accessToken: "tok-test", refreshToken: nil, accountId: "acc-test")
        #expect(state.canAdvanceToPhase(.style) == true)
        #expect(state.canAdvanceToPhase(.cast) == false)

        state.project.style.locked = true
        #expect(state.canAdvanceToPhase(.cast) == true)
        #expect(state.canAdvanceToPhase(.frames) == false)

        state.addCharacter(StoryboardCharacter(name: "Bob", role: "Lead", visualDescription: "Short"))
        #expect(state.canAdvanceToPhase(.frames) == true)
        #expect(state.canAdvanceToPhase(.export) == false)

        state.selectTemplate("problem-solution")
        let firstFrameId = state.project.frames[0].id
        state.updateFrame(firstFrameId, status: .complete)
        #expect(state.canAdvanceToPhase(.export) == true)
    }

    @Test func lockStyleAdvancesToCast() {
        let state = AppState()
        state.project.style.description = "Sketchy style"
        state.project.style.referenceImages = [Data([1, 2, 3])]
        state.lockStyle()

        #expect(state.project.style.locked == true)
        #expect(state.project.currentPhase == .cast)
    }

    @Test func addFrameInFreeform() {
        let state = AppState()
        state.selectTemplate("freeform")
        #expect(state.project.frames.count == 1)

        state.addFrame()
        #expect(state.project.frames.count == 2)
        #expect(state.project.frames[1].beatTitle == "Frame 2")
    }

    @Test func reorderFramesForward() {
        let state = AppState()
        state.selectTemplate("problem-solution")

        let ids = state.project.frames.map(\.id)
        state.reorderFrames(from: 0, to: 2)

        #expect(state.project.frames.count == 3)
        #expect(state.project.frames[2].id == ids[0])
    }

    @Test func reorderFramesUndoRestoresOriginal() {
        let state = AppState()
        state.selectTemplate("problem-solution")

        let originalIds = state.project.frames.map(\.id)
        state.reorderFrames(from: 0, to: 1)

        state.undo()
        let restoredIds = state.project.frames.map(\.id)
        #expect(restoredIds == originalIds)
    }

    @Test func newMutationClearsRedoStack() {
        let state = AppState()
        state.selectTemplate("raskin-pitch")
        state.undo()
        #expect(state.canRedo)

        state.selectTemplate("hero-journey")
        #expect(!state.canRedo)
    }

    @Test func canUndoCanRedo() {
        let state = AppState()
        #expect(!state.canUndo)
        #expect(!state.canRedo)

        state.selectTemplate("raskin-pitch")
        #expect(state.canUndo)
        #expect(!state.canRedo)

        state.undo()
        #expect(!state.canUndo)
        #expect(state.canRedo)
    }

    // MARK: - removeFrame

    @Test func removeFrameClearsSelectionIfSelected() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let targetId = state.project.frames[1].id
        state.selectFrame(targetId)

        state.removeFrame(targetId)

        #expect(state.project.frames.count == 2)
        #expect(!state.project.frames.contains { $0.id == targetId })
        #expect(state.selectedFrameId == state.project.frames.first?.id)
    }

    @Test func removeFramePreservesSelectionOfOtherFrame() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let keepId = state.project.frames[0].id
        let removeId = state.project.frames[2].id
        state.selectFrame(keepId)

        state.removeFrame(removeId)

        #expect(state.project.frames.count == 2)
        #expect(state.selectedFrameId == keepId)
    }

    @Test func removeFrameWithNonexistentIdDoesNothing() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let originalCount = state.project.frames.count
        let originalIds = state.project.frames.map(\.id)

        state.removeFrame("nonexistent-id")

        #expect(state.project.frames.count == originalCount)
        #expect(state.project.frames.map(\.id) == originalIds)
    }

    // MARK: - moveFrame

    @Test func moveFrameReordersCorrectly() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let ids = state.project.frames.map(\.id)

        state.moveFrame(sourceId: ids[0], beforeId: ids[2])

        #expect(state.project.frames[0].id == ids[1])
        #expect(state.project.frames[2].id == ids[0])
    }

    @Test func moveFrameSameSourceAndTargetDoesNothing() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let originalIds = state.project.frames.map(\.id)

        state.moveFrame(sourceId: originalIds[0], beforeId: originalIds[0])

        #expect(state.project.frames.map(\.id) == originalIds)
    }

    // MARK: - reorderFrames edge cases

    @Test func reorderFramesOutOfBoundsDoesNothing() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let originalIds = state.project.frames.map(\.id)

        state.reorderFrames(from: -1, to: 0)
        #expect(state.project.frames.map(\.id) == originalIds)

        state.reorderFrames(from: 0, to: 99)
        #expect(state.project.frames.map(\.id) == originalIds)
    }

    @Test func reorderFramesSameIndexDoesNothing() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let originalIds = state.project.frames.map(\.id)

        state.reorderFrames(from: 1, to: 1)

        #expect(state.project.frames.map(\.id) == originalIds)
    }
}
