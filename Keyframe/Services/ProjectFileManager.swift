import Foundation
import AppKit
import UniformTypeIdentifiers

enum ProjectFileManager {

    static let fileExtension = "keyframe"
    static let contentType = UTType(filenameExtension: fileExtension) ?? .json

    struct ProjectFile: Codable {
        var version: Int = 1
        var project: Project
        var selectedFrameId: String?
    }

    // MARK: - Save

    @MainActor
    static func save(state: AppState) {
        let file = ProjectFile(
            project: state.project,
            selectedFrameId: state.selectedFrameId
        )

        guard let data = try? JSONEncoder().encode(file) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = sanitizeFilename(state.project.selectedTemplateId ?? "untitled")
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url)
            state.currentFileURL = url
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    // MARK: - Open

    @MainActor
    static func open(into state: AppState) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [contentType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        load(url: url, into: state)
    }

    @MainActor
    static func load(url: URL, into state: AppState) {
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(ProjectFile.self, from: data)
            state.project = file.project
            state.selectedFrameId = file.selectedFrameId
            state.currentFileURL = url
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    // MARK: - Save to existing file

    @MainActor
    static func saveToCurrentFile(state: AppState) {
        guard let url = state.currentFileURL else {
            save(state: state)
            return
        }

        let file = ProjectFile(
            project: state.project,
            selectedFrameId: state.selectedFrameId
        )

        guard let data = try? JSONEncoder().encode(file) else { return }

        do {
            try data.write(to: url)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    // MARK: - Helpers

    private static func sanitizeFilename(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "-", options: .regularExpression)
        return cleaned.isEmpty ? "untitled" : cleaned
    }
}
