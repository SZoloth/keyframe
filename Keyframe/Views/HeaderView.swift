import SwiftUI

struct HeaderView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        HStack(spacing: 0) {
            leadingSection
            Spacer()
            PhaseIndicator()
            Spacer()
            trailingSection
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(.background)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var leadingSection: some View {
        HStack(spacing: 8) {
            Text("Keyframe")
                .font(.title3)
                .fontWeight(.semibold)

            if let template = appState.selectedTemplate {
                Text(template.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if appState.project.selectedTemplateId == "freeform" {
                Text("Freeform")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trailingSection: some View {
        HStack(spacing: 8) {
            Button("Undo") { appState.undo() }
                .disabled(!appState.canUndo)
                .keyboardShortcut("z", modifiers: .command)

            Button("Redo") { appState.redo() }
                .disabled(!appState.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])

            Divider()
                .frame(height: 20)

            authSection
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var authSection: some View {
        if appState.isAuthenticated {
            Menu {
                Text(authMethodLabel)
                    .font(.caption)
                Divider()
                Button("Sign out") {
                    authManager.logout()
                    appState.authMode = .none
                }
            } label: {
                Label(authBadgeLabel, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } else {
            Button("Sign in") {
                appState.setPhase(.setup)
            }
        }
    }

    private var authBadgeLabel: String {
        switch appState.authMode {
        case .oauth: return "ChatGPT"
        case .apiKey: return "API Key"
        case .none: return "Connected"
        }
    }

    private var authMethodLabel: String {
        switch appState.authMode {
        case .oauth: return "Signed in with ChatGPT"
        case .apiKey: return "Using API key"
        case .none: return ""
        }
    }
}
