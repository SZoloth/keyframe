import Testing
import Foundation
@testable import Keyframe

@Suite("Style screen flow", .serialized)
@MainActor
struct StyleFlowTests {

    // MARK: - Unit 4: Reference image management

    @Test func addReferenceImageIncreasesCount() {
        let state = AppState()
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])

        state.addReferenceImage(imageData)

        #expect(state.project.style.referenceImages.count == 1)
        #expect(state.project.style.referenceImages[0] == imageData)
    }

    @Test func addThreeImagesAllRetained() {
        let state = AppState()
        let images = (1...3).map { Data([$0]) }

        for img in images { state.addReferenceImage(img) }

        #expect(state.project.style.referenceImages.count == 3)
    }

    @Test func fourthImageIsIgnored() {
        let state = AppState()
        for i in 1...4 { state.addReferenceImage(Data([UInt8(i)])) }

        #expect(state.project.style.referenceImages.count == 3)
    }

    @Test func removeReferenceImageAtValidIndex() {
        let state = AppState()
        let images = (1...3).map { Data([$0]) }
        for img in images { state.addReferenceImage(img) }

        state.removeReferenceImage(at: 1)

        #expect(state.project.style.referenceImages.count == 2)
        #expect(state.project.style.referenceImages[0] == Data([1]))
        #expect(state.project.style.referenceImages[1] == Data([3]))
    }

    @Test func removeReferenceImageAtOutOfBoundsDoesNothing() {
        let state = AppState()
        state.addReferenceImage(Data([1]))

        state.removeReferenceImage(at: 5)

        #expect(state.project.style.referenceImages.count == 1)
    }

    @Test func removeReferenceImageOnEmptyDoesNothing() {
        let state = AppState()
        state.removeReferenceImage(at: 0)

        #expect(state.project.style.referenceImages.isEmpty)
    }

    // MARK: - Unit 5: Description and lock flow

    @Test func setStyleDescriptionStoresValue() {
        let state = AppState()
        state.setStyleDescription("Pencil sketch, high contrast")

        #expect(state.project.style.description == "Pencil sketch, high contrast")
    }

    @Test func lockStyleSetsLockedAndAdvancesToCast() {
        let state = AppState()
        state.addReferenceImage(Data([1]))
        state.setStyleDescription("Watercolor")
        state.lockStyle()

        #expect(state.project.style.locked == true)
        #expect(state.project.currentPhase == .cast)
    }

    @Test func canAdvanceToCastRequiresLockedStyle() {
        let state = AppState()
        #expect(state.canAdvanceToPhase(.cast) == false)

        state.project.style.locked = true
        #expect(state.canAdvanceToPhase(.cast) == true)
    }

    @Test func canAdvanceToCastFalseWhenUnlocked() {
        let state = AppState()
        state.project.style.locked = false
        #expect(state.canAdvanceToPhase(.cast) == false)
    }

    @Test func fullStyleFlowFromImageToLock() {
        let state = AppState()
        state.authMode = .apiKey("sk-test")
        state.setPhase(.style)

        state.addReferenceImage(Data([0x89, 0x50]))
        state.setStyleDescription("Minimalist line art")
        state.lockStyle()

        #expect(state.project.style.locked == true)
        #expect(state.project.style.referenceImages.count == 1)
        #expect(state.project.style.description == "Minimalist line art")
        #expect(state.project.currentPhase == .cast)
    }
}
