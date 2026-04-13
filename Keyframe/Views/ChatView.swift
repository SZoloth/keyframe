import SwiftUI

struct ChatMessage: Identifiable {
    let id: String
    let role: ChatRole
    let content: String
    let imageData: Data?

    enum ChatRole { case user, assistant }
}

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(AIServiceProvider.self) private var aiProvider
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var loading = false
    @State private var currentScene = ""
    @State private var pendingImageData: Data?
    @State private var previousFrameId: String?
    private let requestPlaceholders = [
        "Thinking of a scene...",
        "Refining...",
        "Generating image..."
    ]

    var body: some View {
        let phase = appState.project.currentPhase
        if phase == .style {
            ContentUnavailableView(
                "Complete your style first",
                systemImage: "paintpalette",
                description: Text("Lock the style to begin directing scenes.")
            )
        } else if phase == .cast {
            ContentUnavailableView(
                "Add characters first",
                systemImage: "person.2",
                description: Text("Add at least one character in the Cast tab.")
            )
        } else if let frame = appState.selectedFrame {
            chatInterface(frame: frame)
                .onChange(of: appState.selectedFrameId) { _, newId in
                    guard newId != previousFrameId else { return }
                    previousFrameId = newId
                    resetChat(for: appState.selectedFrame)
                }
        } else {
            ContentUnavailableView(
                "Select a frame",
                systemImage: "rectangle.on.rectangle",
                description: Text("Choose a frame from the canvas to direct the scene.")
            )
        }
    }

    // MARK: - Chat interface

    private func chatInterface(frame: StoryboardFrame) -> some View {
        VStack(spacing: 0) {
            frameContext(frame: frame)
            messageList(frame: frame)
            actionButtons(frame: frame)
            inputBar
        }
    }

    // MARK: - Frame context

    private func frameContext(frame: StoryboardFrame) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Currently editing")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(frame.beatTitle)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3))
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Messages

    private func messageList(frame: StoryboardFrame) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyPrompt(frame: frame)
                    }

                    ForEach(messages) { msg in
                        messageBubble(msg)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
    }

    private func emptyPrompt(frame: StoryboardFrame) -> some View {
        VStack(spacing: 12) {
            Text("Let's create the \"\(frame.beatTitle)\" frame.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Suggest a scene") {
                suggestScene(for: frame)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .disabled(loading)
            .controlSize(.small)

            Text("Or describe the scene yourself below")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 24)
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 8) {
                Text(msg.content)
                    .font(.caption)

                if let data = msg.imageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(10)
            .background(msg.role == .user ? Theme.Colors.accent : Theme.Colors.tertiaryBackground)
            .foregroundStyle(msg.role == .user ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if msg.role == .assistant { Spacer(minLength: 40) }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionButtons(frame: StoryboardFrame) -> some View {
        if !currentScene.isEmpty && pendingImageData == nil {
            HStack {
                Button {
                    generateImage(for: frame)
                } label: {
                    HStack(spacing: 6) {
                        if loading { ProgressView().controlSize(.small) }
                        Text(loading ? "Generating image..." : "Generate image")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .disabled(loading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Divider() }
        }

        if let _ = pendingImageData, frame.status != .complete {
            HStack(spacing: 8) {
                Button {
                    acceptImage(frameId: frame.id)
                } label: {
                    Text("Accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    generateImage(for: frame)
                } label: {
                    HStack(spacing: 6) {
                        if loading { ProgressView().controlSize(.small) }
                        Text(loading ? "Generating..." : "Try again")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(loading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Divider() }
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(
                currentScene.isEmpty ? "Describe the scene..." : "Refine the scene...",
                text: $input
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit { send() }
            .disabled(loading)

            Button("Send") { send() }
                .disabled(loading || input.trimmingCharacters(in: .whitespaces).isEmpty)
                .controlSize(.small)
        }
        .padding(12)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Logic

    private func send() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        input = ""

        addMessage(.user, text)

        if currentScene.isEmpty {
            currentScene = text
            addMessage(.assistant, "Scene description set. Ready to generate the image when you are.")
        } else {
            refineScene(with: text)
        }
    }

    private func suggestScene(for frame: StoryboardFrame) {
        let expectedFrameId = frame.id
        loading = true
        addMessage(.assistant, "Thinking of a scene...")
        Task {
            do {
                await aiProvider.prepare(authMode: appState.authMode)
                let completedFrames = appState.project.frames.filter { $0.status == .complete }
                let scene = try await aiProvider.service.suggestScene(
                    beatTitle: frame.beatTitle,
                    beatGuidance: frame.caption,
                    style: appState.project.style,
                    characters: appState.project.characters,
                    previousFrames: completedFrames
                )
                guard appState.selectedFrameId == expectedFrameId else { return }
                currentScene = scene
                removePendingPlaceholderIfPresent()
                addMessage(.assistant, scene)
            } catch {
                guard appState.selectedFrameId == expectedFrameId else { return }
                removePendingPlaceholderIfPresent()
                addMessage(.assistant, "Failed to suggest a scene: \(error.localizedDescription)")
            }
            guard appState.selectedFrameId == expectedFrameId else { return }
            loading = false
        }
    }

    private func refineScene(with feedback: String) {
        guard let expectedFrameId = appState.selectedFrameId else { return }
        loading = true
        addMessage(.assistant, "Refining...")
        Task {
            do {
                await aiProvider.prepare(authMode: appState.authMode)
                let refined = try await aiProvider.service.refineScene(
                    currentScene: currentScene,
                    userFeedback: feedback,
                    style: appState.project.style,
                    characters: appState.project.characters
                )
                guard appState.selectedFrameId == expectedFrameId else { return }
                currentScene = refined
                removePendingPlaceholderIfPresent()
                addMessage(.assistant, refined)
            } catch {
                guard appState.selectedFrameId == expectedFrameId else { return }
                removePendingPlaceholderIfPresent()
                addMessage(.assistant, "Refinement failed: \(error.localizedDescription)")
            }
            guard appState.selectedFrameId == expectedFrameId else { return }
            loading = false
        }
    }

    private func generateImage(for frame: StoryboardFrame) {
        let expectedFrameId = frame.id
        loading = true
        addMessage(.assistant, "Generating image...")
        Task {
            do {
                await aiProvider.prepare(authMode: appState.authMode)
                let imageData = try await aiProvider.service.generateFrameImage(
                    sceneDescription: currentScene,
                    style: appState.project.style,
                    characters: appState.project.characters
                )
                guard appState.selectedFrameId == expectedFrameId else { return }
                pendingImageData = imageData
                removePendingPlaceholderIfPresent()
                addMessage(.assistant, "Here's what I came up with:", imageData: imageData)
            } catch {
                guard appState.selectedFrameId == expectedFrameId else { return }
                removePendingPlaceholderIfPresent()
                addMessage(.assistant, "Image generation failed: \(error.localizedDescription)")
            }
            guard appState.selectedFrameId == expectedFrameId else { return }
            loading = false
        }
    }

    private func acceptImage(frameId: String) {
        guard let data = pendingImageData else { return }
        appState.updateFrame(frameId, sceneDescription: currentScene, imageData: data, status: .complete)
        addMessage(.assistant, "Image added to your storyboard. Select another frame to continue.")
        pendingImageData = nil
    }

    private func addMessage(_ role: ChatMessage.ChatRole, _ content: String, imageData: Data? = nil) {
        messages.append(ChatMessage(
            id: "msg-\(UUID().uuidString)",
            role: role,
            content: content,
            imageData: imageData
        ))
    }

    private func resetChat(for frame: StoryboardFrame?) {
        messages = []
        currentScene = frame?.sceneDescription ?? ""
        pendingImageData = nil
        loading = false
    }

    private func removePendingPlaceholderIfPresent() {
        guard let last = messages.last else { return }
        guard last.role == .assistant, last.imageData == nil else { return }
        guard requestPlaceholders.contains(last.content) else { return }
        messages.removeLast()
    }
}
