import SwiftUI
import UniformTypeIdentifiers

struct StyleView: View {
    @Environment(AppState.self) private var appState
    @Environment(AIServiceProvider.self) private var aiProvider
    @State private var mode: StyleMode = .upload
    @State private var descriptionInput = ""
    @State private var generating = false
    @State private var analyzing = false
    @State private var errorMessage: String?

    enum StyleMode: String, CaseIterable {
        case upload = "Upload"
        case describe = "Describe"
    }

    var body: some View {
        if appState.project.style.locked {
            lockedView
        } else {
            editingView
        }
    }

    // MARK: - Locked state

    private var lockedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Style locked", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !appState.project.style.referenceImages.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(appState.project.style.referenceImages.enumerated()), id: \.offset) { _, data in
                            if let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }

                if !appState.project.style.description.isEmpty {
                    Text(appState.project.style.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
    }

    // MARK: - Editing state

    private var editingView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Define your style")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    modePicker

                    switch mode {
                    case .upload: uploadSection
                    case .describe: describeSection
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if !appState.project.style.description.isEmpty {
                        styleDescriptionEditor
                    }
                }
                .padding()
            }

            if appState.project.currentPhase == .style {
                lockButton
            }
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(StyleMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Upload

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upload 1-3 reference sketches to establish your visual style.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Array(appState.project.style.referenceImages.enumerated()), id: \.offset) { index, data in
                    ZStack(alignment: .topTrailing) {
                        if let nsImage = NSImage(data: data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Button {
                            appState.removeReferenceImage(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white, .red)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: -4)
                    }
                }

                if appState.project.style.referenceImages.count < 3 {
                    Button {
                        pickImageFile()
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(.quaternary)
                            .frame(width: 72, height: 72)
                            .overlay {
                                Image(systemName: "plus")
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            if !appState.project.style.referenceImages.isEmpty && appState.project.style.description.isEmpty {
                Button {
                    runStyleAnalysis()
                } label: {
                    Text(analyzing ? "Analyzing..." : "Analyze style")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .disabled(analyzing)
            }
        }
    }

    // MARK: - Describe

    private var describeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Describe your desired visual style and AI will generate a reference sketch.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $descriptionInput)
                .font(.caption)
                .frame(minHeight: 80, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                runStyleGeneration()
            } label: {
                Text(generating ? "Generating..." : "Generate reference")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .disabled(generating || descriptionInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Description editor

    private var styleDescriptionEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Style description")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            @Bindable var state = appState
            TextEditor(text: Binding(
                get: { state.project.style.description },
                set: { state.setStyleDescription($0) }
            ))
            .font(.caption)
            .frame(minHeight: 100, maxHeight: 160)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Edit if needed. This will be used for all generated frames.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Lock

    private var lockButton: some View {
        VStack {
            Divider()
            Button {
                appState.lockStyle()
            } label: {
                Text("Lock style & continue")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .disabled(!canLock)
            .padding()
        }
    }

    private var canLock: Bool {
        !appState.project.style.referenceImages.isEmpty && !appState.project.style.description.isEmpty
    }

    // MARK: - API calls

    private func runStyleAnalysis() {
        analyzing = true
        errorMessage = nil
        Task {
            do {
                let description = try await aiProvider.service.analyzeStyle(
                    referenceImages: appState.project.style.referenceImages
                )
                appState.setStyleDescription(description)
            } catch {
                errorMessage = "Style analysis failed: \(error.localizedDescription)"
            }
            analyzing = false
        }
    }

    private func runStyleGeneration() {
        generating = true
        errorMessage = nil
        Task {
            do {
                let imageData = try await aiProvider.service.generateStyleReference(
                    description: descriptionInput.trimmingCharacters(in: .whitespaces)
                )
                appState.addReferenceImage(imageData)
                generating = false

                runStyleAnalysis()
            } catch {
                errorMessage = "Reference generation failed: \(error.localizedDescription)"
                generating = false
            }
        }
    }

    // MARK: - File picking

    private func pickImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard appState.project.style.referenceImages.count < 3,
                  let data = try? Data(contentsOf: url) else { continue }
            appState.addReferenceImage(data)
        }
    }
}
