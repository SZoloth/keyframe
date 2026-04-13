import Testing
import Foundation
@testable import Keyframe

@Suite("Setup screen flow", .serialized)
@MainActor
struct SetupFlowTests {

    // MARK: - Unit 1: Auth resolution and phase entry

    @Test func freshAppStateStartsInSetupPhase() {
        let state = AppState()
        #expect(state.project.currentPhase == .setup)
    }

    @Test func setPhaseToSetupAlwaysSucceeds() {
        let state = AppState()
        state.authMode = .oauth(accessToken: "tok", refreshToken: nil, accountId: "acc-1")
        state.setPhase(.style)
        #expect(state.project.currentPhase == .style)

        state.setPhase(.setup)
        #expect(state.project.currentPhase == .setup)
    }

    @Test func canAdvanceToSetupIsAlwaysTrue() {
        let state = AppState()
        #expect(state.canAdvanceToPhase(.setup) == true)

        state.authMode = .oauth(accessToken: "tok", refreshToken: nil, accountId: "acc-1")
        state.setPhase(.style)
        #expect(state.canAdvanceToPhase(.setup) == true)
    }

    @Test func isAuthenticatedWithOAuth() {
        let state = AppState()
        state.authMode = .oauth(accessToken: "token", refreshToken: nil, accountId: "acc-123")
        #expect(state.isAuthenticated == true)
    }

    @Test func oauthWithoutAccountIdIsNotAuthenticated() {
        let state = AppState()
        state.authMode = .oauth(accessToken: "token", refreshToken: nil, accountId: nil)
        #expect(state.isAuthenticated == false)
        #expect(state.canAdvanceToPhase(.style) == false)
    }

    @Test func oauthWithEmptyAccountIdIsNotAuthenticated() {
        let state = AppState()
        state.authMode = .oauth(accessToken: "token", refreshToken: nil, accountId: "")
        #expect(state.isAuthenticated == false)
        #expect(state.canAdvanceToPhase(.style) == false)
    }

    @Test func isNotAuthenticatedWithNone() {
        let state = AppState()
        #expect(state.isAuthenticated == false)
        #expect(state.authMode == .none)
    }

    // MARK: - Unit 2: Template selection and custom templates

    @Test func selectHeroJourneyProduces8Frames() {
        let state = AppState()
        state.selectTemplate("hero-journey")

        #expect(state.project.frames.count == 8)
        #expect(state.project.frames[0].beatTitle == "Ordinary World")
        #expect(state.project.selectedTemplateId == "hero-journey")
    }

    @Test func selectProblemSolutionProduces3Frames() {
        let state = AppState()
        state.selectTemplate("problem-solution")

        #expect(state.project.frames.count == 3)
        #expect(state.project.frames[0].beatTitle == "Before")
    }

    @Test func addCustomTemplateThenSelectIt() {
        let state = AppState()
        let template = Template(
            id: "custom-test-123",
            name: "Test Template",
            description: "A test",
            frames: [
                FrameBeat(id: "b1", title: "Opening", guidance: "Start here"),
                FrameBeat(id: "b2", title: "Closing", guidance: "End here"),
            ]
        )
        state.addCustomTemplate(template)
        state.selectTemplate("custom-test-123")

        #expect(state.project.frames.count == 2)
        #expect(state.project.frames[0].beatTitle == "Opening")
        #expect(state.project.selectedTemplateId == "custom-test-123")
    }

    @Test func customTemplateAppearsInLookup() {
        let custom = Template(
            id: "custom-lookup",
            name: "Lookup Test",
            description: "For lookup",
            frames: [FrameBeat(id: "b1", title: "Beat", guidance: "Go")]
        )
        let found = BuiltInTemplates.find(byId: "custom-lookup", customTemplates: [custom])
        #expect(found != nil)
        #expect(found?.isCustom == true)
    }

    @Test func selectNonexistentTemplateDoesNothing() {
        let state = AppState()
        state.selectTemplate("nonexistent-id")

        #expect(state.project.frames.isEmpty)
        #expect(state.project.selectedTemplateId == nil)
    }

    @Test func customTemplateIsCustomFlag() {
        let custom = Template(id: "custom-flag", name: "T", description: "D", frames: [])
        #expect(custom.isCustom == true)

        let builtin = Template(id: "builtin-flag", name: "T", description: "D", frames: [])
        #expect(builtin.isCustom == false)
    }

    // MARK: - Unit 3: Proceed gating (setup -> style)

    @Test func unauthenticatedCannotAdvanceToStyle() {
        let state = AppState()
        #expect(state.authMode == .none)
        #expect(state.canAdvanceToPhase(.style) == false)
    }

    @Test func oauthAuthEnablesStyleAdvancement() {
        let state = AppState()
        state.authMode = .oauth(accessToken: "token", refreshToken: nil, accountId: "acc-123")
        #expect(state.canAdvanceToPhase(.style) == true)
    }

    @Test func authenticateThenProceedToStyle() {
        let state = AppState()
        #expect(state.project.currentPhase == .setup)

        state.authMode = .oauth(accessToken: "tok-proceed", refreshToken: nil, accountId: "acc-proceed")
        #expect(state.canAdvanceToPhase(.style) == true)

        state.setPhase(.style)
        #expect(state.project.currentPhase == .style)
    }
}
