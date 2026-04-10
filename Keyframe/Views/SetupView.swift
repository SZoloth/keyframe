import SwiftUI

struct EditableBeat: Identifiable {
    let id = UUID()
    var title = ""
    var guidance = ""
}

struct SetupView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthManager.self) private var authManager
    @State private var apiKeyInput = ""
    @State private var showAPIKeyField = false
    @State private var showAPIKeyHelp = false
    @State private var codexDetected = false
    @State private var showCustomTemplateForm = false
    @State private var customName = ""
    @State private var customDescription = ""
    @State private var customBeats: [EditableBeat] = [EditableBeat()]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Setup")
                    .font(.title)
                    .fontWeight(.bold)

                authSection
                templateSection
                customTemplateSection
                proceedButton
            }
            .padding(32)
            .frame(maxWidth: 480, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            codexDetected = authManager.detectCodexTokens() != nil

            if appState.authMode == .none {
                let restored = authManager.resolveAuthMode()
                if restored != .none {
                    appState.authMode = restored
                }
            }
        }
    }

    // MARK: - Auth

    @ViewBuilder
    private var authSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connect OpenAI")
                .font(.subheadline)
                .fontWeight(.medium)

            if appState.isAuthenticated {
                connectedBadge
            } else {
                authOptions
            }
        }
    }

    private var connectedBadge: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("OpenAI connected")
                .font(.subheadline)
            Spacer()
            Button("Disconnect") {
                authManager.logout()
                appState.authMode = .none
            }
            .font(.caption)
        }
        .padding(12)
        .background(.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var authOptions: some View {
        VStack(spacing: 8) {
            if case .authenticating = authManager.status {
                authenticatingView
            } else {
                if codexDetected {
                    Button {
                        if let tokens = authManager.detectCodexTokens() {
                            authManager.loginWithCodexTokens(tokens)
                            appState.authMode = authManager.resolveAuthMode()
                        }
                    } label: {
                        Label("Use Codex CLI session", systemImage: "terminal")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                }

                Button {
                    Task {
                        await authManager.loginWithOAuth()
                        appState.authMode = authManager.resolveAuthMode()
                    }
                } label: {
                    Label("Sign in with ChatGPT", systemImage: "globe")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)

                if showAPIKeyField {
                    apiKeyField
                } else {
                    Button("Use API key instead") {
                        showAPIKeyField = true
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if case .failed(let msg) = authManager.status {
                Label(msg, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var authenticatingView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for browser sign-in...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            Button("Cancel") {
                Task { await authManager.cancelOAuth() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var apiKeyField: some View {
        VStack(spacing: 8) {
            SecureField("sk-...", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Connect") {
                    authManager.loginWithAPIKey(apiKeyInput)
                    appState.authMode = authManager.resolveAuthMode()
                    apiKeyInput = ""
                    showAPIKeyField = false
                }
                .disabled(apiKeyInput.isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(.primary)

                Button("Cancel") {
                    showAPIKeyField = false
                    apiKeyInput = ""
                }
            }
            .controlSize(.small)

            HStack(spacing: 4) {
                Text("Stored in macOS Keychain only.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    showAPIKeyHelp.toggle()
                } label: {
                    Label("How to get a key", systemImage: "questionmark.circle")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if showAPIKeyHelp {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Go to platform.openai.com/api-keys")
                    Text("2. Click \"Create new secret key\"")
                    Text("3. Copy and paste it above")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Templates

    @ViewBuilder
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose template")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Pick a storytelling framework or go freeform.")
                .font(.caption)
                .foregroundStyle(.secondary)

            templateButton(id: "freeform", name: "Freeform", description: "Create your own frames without a predefined structure.", badge: "Custom")

            ForEach(allTemplates) { template in
                templateButton(
                    id: template.id,
                    name: template.name,
                    description: template.description,
                    badge: "\(template.frames.count) frames"
                )
            }
        }
    }

    private func templateButton(id: String, name: String, description: String, badge: String) -> some View {
        Button {
            appState.selectTemplate(id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(badge)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        appState.project.selectedTemplateId == id ? Color.primary : Color(.separatorColor),
                        lineWidth: appState.project.selectedTemplateId == id ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom template form

    @ViewBuilder
    private var customTemplateSection: some View {
        if showCustomTemplateForm {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("New custom template")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Button("Cancel") {
                        showCustomTemplateForm = false
                        resetCustomForm()
                    }
                    .font(.caption)
                }

                TextField("Template name", text: $customName)
                    .textFieldStyle(.roundedBorder)

                TextField("Description", text: $customDescription)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Beats")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ForEach($customBeats) { $beat in
                        HStack(spacing: 4) {
                            TextField("Title", text: $beat.title)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120)
                            TextField("Guidance", text: $beat.guidance)
                                .textFieldStyle(.roundedBorder)
                            if customBeats.count > 1 {
                                Button {
                                    customBeats.removeAll { $0.id == beat.id }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        customBeats.append(EditableBeat())
                    } label: {
                        Label("Add beat", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Button("Create template") {
                    saveCustomTemplate()
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .controlSize(.small)
                .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty || customBeats.allSatisfy { $0.title.trimmingCharacters(in: .whitespaces).isEmpty })
            }
            .padding(12)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Button {
                showCustomTemplateForm = true
            } label: {
                Label("Create custom template", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func saveCustomTemplate() {
        let beats = customBeats
            .filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated()
            .map { index, beat in
                FrameBeat(
                    id: "beat-\(UUID().uuidString)",
                    title: beat.title.trimmingCharacters(in: .whitespaces),
                    guidance: beat.guidance.trimmingCharacters(in: .whitespaces).isEmpty
                        ? beat.title.trimmingCharacters(in: .whitespaces)
                        : beat.guidance.trimmingCharacters(in: .whitespaces)
                )
            }

        let template = Template(
            id: "custom-\(UUID().uuidString)",
            name: customName.trimmingCharacters(in: .whitespaces),
            description: customDescription.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Custom template with \(beats.count) beats"
                : customDescription.trimmingCharacters(in: .whitespaces),
            frames: beats
        )

        appState.addCustomTemplate(template)
        appState.selectTemplate(template.id)
        showCustomTemplateForm = false
        resetCustomForm()
    }

    private func resetCustomForm() {
        customName = ""
        customDescription = ""
        customBeats = [EditableBeat()]
    }

    // MARK: - Proceed

    private var proceedButton: some View {
        Button {
            if appState.canAdvanceToPhase(.style) {
                appState.setPhase(.style)
            }
        } label: {
            Text(appState.isAuthenticated ? "Continue to style definition" : "Connect OpenAI to continue")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(.primary)
        .disabled(!appState.isAuthenticated)
    }

    // MARK: - Helpers

    private var allTemplates: [Template] {
        BuiltInTemplates.all + appState.project.customTemplates
    }

}
