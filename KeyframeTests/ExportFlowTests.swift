import Testing
import Foundation
@testable import Keyframe

@Suite("Export screen flow", .serialized)
@MainActor
struct ExportFlowTests {

    @Test func canAdvanceToExportRequiresCompleteFrame() {
        let state = AppState()
        state.selectTemplate("problem-solution")

        #expect(state.canAdvanceToPhase(.export) == false)

        state.updateFrame(state.project.frames[0].id, status: .complete)
        #expect(state.canAdvanceToPhase(.export) == true)
    }

    @Test func canAdvanceToExportFalseWhenAllEmpty() {
        let state = AppState()
        state.selectTemplate("raskin-pitch")

        #expect(state.project.frames.count == 5)
        #expect(state.canAdvanceToPhase(.export) == false)
    }

    @Test func canAdvanceToExportFalseWhenAllGenerating() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        for frame in state.project.frames {
            state.updateFrame(frame.id, status: .generating)
        }

        #expect(state.canAdvanceToPhase(.export) == false)
    }

    @Test func fullPhaseWalkthrough() {
        let state = AppState()

        // Setup: authenticate and select template
        #expect(state.project.currentPhase == .setup)
        state.authMode = .apiKey("sk-walk")
        state.selectTemplate("problem-solution")
        #expect(state.canAdvanceToPhase(.style) == true)
        state.setPhase(.style)

        // Style: add image, describe, lock
        state.addReferenceImage(Data([1, 2, 3]))
        state.setStyleDescription("Watercolor")
        state.lockStyle()
        #expect(state.project.currentPhase == .cast)

        // Cast: add character
        state.addCharacter(StoryboardCharacter(name: "Hero", role: "Lead", visualDescription: "Tall"))
        #expect(state.canAdvanceToPhase(.frames) == true)
        state.setPhase(.frames)

        // Frames: complete one frame
        let frameId = state.project.frames[0].id
        state.updateFrame(frameId, sceneDescription: "Office scene", imageData: Data([4, 5]), status: .complete)
        #expect(state.canAdvanceToPhase(.export) == true)
        state.setPhase(.export)

        // Export
        #expect(state.project.currentPhase == .export)
        #expect(state.project.frames.filter { $0.status == .complete }.count == 1)
    }
}
