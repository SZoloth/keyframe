import Testing
import Foundation
@testable import Keyframe

@Suite("Frames screen flow", .serialized)
@MainActor
struct FramesFlowTests {

    @Test func newFrameStartsEmpty() {
        let state = AppState()
        state.selectTemplate("problem-solution")

        for frame in state.project.frames {
            #expect(frame.status == .empty)
        }
    }

    @Test func updateFrameStatusToGenerating() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let frameId = state.project.frames[0].id

        state.updateFrame(frameId, status: .generating)

        #expect(state.project.frames[0].status == .generating)
    }

    @Test func updateFrameWithSceneAndImageCompletes() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let frameId = state.project.frames[0].id
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])

        state.updateFrame(frameId, sceneDescription: "A busy office", imageData: imageData, status: .complete)

        #expect(state.project.frames[0].status == .complete)
        #expect(state.project.frames[0].sceneDescription == "A busy office")
        #expect(state.project.frames[0].imageData == imageData)
    }

    @Test func selectFrameSetsSelectedFrameId() {
        let state = AppState()
        state.selectTemplate("raskin-pitch")
        let secondId = state.project.frames[1].id

        state.selectFrame(secondId)

        #expect(state.selectedFrameId == secondId)
        #expect(state.selectedFrame?.beatTitle == "The Shift")
    }

    @Test func selectFrameNilClearsSelection() {
        let state = AppState()
        state.selectTemplate("raskin-pitch")
        state.selectFrame(state.project.frames[0].id)

        state.selectFrame(nil)

        #expect(state.selectedFrameId == nil)
        #expect(state.selectedFrame == nil)
    }

    @Test func updateNonexistentFrameDoesNothing() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        let originalCaption = state.project.frames[0].caption

        state.updateFrame("nonexistent", caption: "Changed")

        #expect(state.project.frames[0].caption == originalCaption)
    }

    @Test func selectedFrameReturnsNilWhenNoMatch() {
        let state = AppState()
        state.selectTemplate("problem-solution")
        state.selectFrame("bogus-id")

        #expect(state.selectedFrame == nil)
    }
}
