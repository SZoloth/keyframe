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

    @Test func canAdvanceToExportWithMultipleFramesMixedStatus() {
        let state = AppState()
        state.selectTemplate("raskin-pitch")

        state.updateFrame(state.project.frames[0].id, status: .generating)
        state.updateFrame(state.project.frames[1].id, status: .generating)
        #expect(state.canAdvanceToPhase(.export) == false)

        state.updateFrame(state.project.frames[2].id, status: .complete)
        #expect(state.canAdvanceToPhase(.export) == true)
    }

    @Test func fullPhaseWalkthrough() {
        let state = AppState()

        // Setup: authenticate and select template
        #expect(state.project.currentPhase == .setup)
        state.authMode = .oauth(accessToken: "tok-walk", refreshToken: nil, accountId: "acc-walk")
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

    @Test func fullPhaseWalkthroughDescriptionOnlyStyle() {
        let state = AppState()

        // Setup: authenticate with OAuth
        state.authMode = .oauth(accessToken: "tok", refreshToken: nil, accountId: "acc-1")
        #expect(state.isAuthenticated == true)
        state.selectTemplate("hero-journey")
        #expect(state.project.frames.count == 8)
        state.setPhase(.style)

        // Style: description only, no images
        state.setStyleDescription("Anime style with bold colors")
        state.lockStyle()
        #expect(state.project.currentPhase == .cast)
        #expect(state.project.style.referenceImages.isEmpty)
        #expect(state.project.style.locked == true)

        // Cast: add character with minimal info
        state.addCharacter(StoryboardCharacter(name: "Hero", role: "Protagonist", visualDescription: ""))
        #expect(state.canAdvanceToPhase(.frames) == true)
        state.setPhase(.frames)

        // Frames: complete multiple frames
        state.updateFrame(state.project.frames[0].id, sceneDescription: "Scene 1", imageData: Data([1]), status: .complete)
        state.updateFrame(state.project.frames[1].id, sceneDescription: "Scene 2", imageData: Data([2]), status: .complete)
        state.setPhase(.export)

        // Export
        #expect(state.project.currentPhase == .export)
        #expect(state.project.frames.filter { $0.status == .complete }.count == 2)
        #expect(state.project.characters[0].visualDescription == "")
    }

    @Test func phaseGatingBlocksBackwardSkip() {
        let state = AppState()
        state.authMode = .oauth(accessToken: "tok-test", refreshToken: nil, accountId: "acc-test")
        state.selectTemplate("problem-solution")
        state.setPhase(.style)
        state.addReferenceImage(Data([1]))
        state.lockStyle()
        state.addCharacter(StoryboardCharacter(name: "A", role: "R", visualDescription: "V"))
        state.setPhase(.frames)
        state.updateFrame(state.project.frames[0].id, status: .complete)
        state.setPhase(.export)

        // Can always go back to setup
        #expect(state.canAdvanceToPhase(.setup) == true)
        // Gating still requires prerequisites
        #expect(state.canAdvanceToPhase(.style) == true)
        #expect(state.canAdvanceToPhase(.cast) == true)
        #expect(state.canAdvanceToPhase(.frames) == true)
        #expect(state.canAdvanceToPhase(.export) == true)
    }
}
