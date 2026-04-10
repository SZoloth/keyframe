import Testing
import Foundation
@testable import Keyframe

@Suite("Edge cases and reset", .serialized)
@MainActor
struct EdgeCaseTests {

    @Test func resetProjectReturnsToEmpty() {
        let state = AppState()
        state.authMode = .apiKey("sk-test")
        state.selectTemplate("raskin-pitch")
        state.addCharacter(StoryboardCharacter(name: "A", role: "R", visualDescription: "V"))
        state.setPhase(.frames)

        state.resetProject()

        #expect(state.project == .empty)
        #expect(state.selectedFrameId == nil)
    }

    @Test func undoAfterResetRestoresPreviousState() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let frameCount = state.project.frames.count

        state.resetProject()
        #expect(state.project.frames.isEmpty)

        state.undo()
        #expect(state.project.frames.count == frameCount)
    }

    @Test func addFrameOnEmptyProjectWorks() {
        let state = AppState()
        #expect(state.project.frames.isEmpty)

        state.addFrame()

        #expect(state.project.frames.count == 1)
        #expect(state.project.frames[0].beatTitle == "Frame 1")
        #expect(state.selectedFrameId == state.project.frames[0].id)
    }

    @Test func moveFrameWithSingleFrameDoesNothing() {
        let state = AppState()
        state.addFrame()
        let id = state.project.frames[0].id

        state.moveFrame(sourceId: id, beforeId: id)

        #expect(state.project.frames.count == 1)
        #expect(state.project.frames[0].id == id)
    }

    @Test func rapidPhaseChangesProduceCorrectUndoHistory() {
        let state = AppState()
        state.setPhase(.style)
        state.setPhase(.cast)
        state.setPhase(.frames)

        state.undo()
        #expect(state.project.currentPhase == .cast)

        state.undo()
        #expect(state.project.currentPhase == .style)

        state.undo()
        #expect(state.project.currentPhase == .setup)
    }

    @Test func setStyleDescriptionWithEmptyString() {
        let state = AppState()
        state.setStyleDescription("Something")
        state.setStyleDescription("")

        #expect(state.project.style.description == "")
    }

    // MARK: - Phase gating enforcement

    @Test func cannotSkipFromSetupToFrames() {
        let state = AppState()
        #expect(state.canAdvanceToPhase(.frames) == false)
    }

    @Test func cannotSkipFromSetupToExport() {
        let state = AppState()
        #expect(state.canAdvanceToPhase(.export) == false)
    }

    @Test func cannotAdvanceToCastWithoutLockedStyle() {
        let state = AppState()
        state.authMode = .apiKey("sk-test")
        state.setPhase(.style)
        state.addReferenceImage(Data([1]))
        state.setStyleDescription("Test")

        #expect(state.canAdvanceToPhase(.cast) == false)
        #expect(state.project.style.locked == false)
    }

    @Test func cannotAdvanceToFramesWithoutCharacters() {
        let state = AppState()
        state.authMode = .apiKey("sk-test")
        state.setPhase(.style)
        state.lockStyle()

        #expect(state.project.currentPhase == .cast)
        #expect(state.canAdvanceToPhase(.frames) == false)
    }

    @Test func cannotAdvanceToExportWithoutCompleteFrame() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        state.addCharacter(StoryboardCharacter(name: "A", role: "R", visualDescription: "V"))
        state.setPhase(.frames)

        #expect(state.canAdvanceToPhase(.export) == false)

        state.updateFrame(state.project.frames[0].id, status: .generating)
        #expect(state.canAdvanceToPhase(.export) == false)
    }

    // MARK: - Template switching

    @Test func switchingTemplatesResetsFrames() {
        let state = AppState()
        state.selectTemplate("raskin-pitch")
        #expect(state.project.frames.count == 5)

        state.selectTemplate("problem-solution")
        #expect(state.project.frames.count == 3)
        #expect(state.project.selectedTemplateId == "problem-solution")
    }

    @Test func switchingTemplatesClearsSelection() {
        let state = AppState()
        state.selectTemplate("raskin-pitch")
        let originalSelection = state.selectedFrameId
        #expect(originalSelection != nil)

        state.selectTemplate("hero-journey")
        #expect(state.selectedFrameId != originalSelection)
        #expect(state.selectedFrameId == state.project.frames.first?.id)
    }

    @Test func switchingToFreeformCreatesOneFrame() {
        let state = AppState()
        state.selectTemplate("raskin-pitch")
        #expect(state.project.frames.count == 5)

        state.selectTemplate("freeform")
        #expect(state.project.frames.count == 1)
        #expect(state.project.frames[0].beatTitle == "Frame 1")
    }

    @Test func addCustomTemplateThenResetClearsAll() {
        let state = AppState()
        let template = Template(
            id: "custom-reset-test",
            name: "Reset",
            description: "Test",
            frames: [FrameBeat(id: "b1", title: "Beat", guidance: "Go")]
        )
        state.addCustomTemplate(template)
        state.selectTemplate("custom-reset-test")
        #expect(state.project.customTemplates.count == 1)
        #expect(state.project.frames.count == 1)

        state.resetProject()

        #expect(state.project.customTemplates.isEmpty)
        #expect(state.project.frames.isEmpty)
    }
}
