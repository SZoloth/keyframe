import Foundation
import Observation

enum AuthMode: Equatable {
    case none
    case apiKey(String)
    case oauth(accessToken: String, refreshToken: String?)
}

@MainActor
@Observable
final class AppState {
    var project = Project.empty
    var authMode: AuthMode = .none
    var selectedFrameId: String?
    var currentFileURL: URL?

    private var history: [Snapshot] = []
    private var future: [Snapshot] = []
    private static let maxHistory = 50

    var canUndo: Bool { !history.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    var isAuthenticated: Bool {
        authMode != .none
    }

    // MARK: - Undo infrastructure

    private struct Snapshot {
        let project: Project
        let selectedFrameId: String?
    }

    private func pushHistory() {
        history.append(Snapshot(project: project, selectedFrameId: selectedFrameId))
        if history.count > Self.maxHistory {
            history.removeFirst()
        }
        future.removeAll()
    }

    func undo() {
        guard let prev = history.popLast() else { return }
        future.append(Snapshot(project: project, selectedFrameId: selectedFrameId))
        project = prev.project
        selectedFrameId = prev.selectedFrameId
    }

    func redo() {
        guard let next = future.popLast() else { return }
        history.append(Snapshot(project: project, selectedFrameId: selectedFrameId))
        project = next.project
        selectedFrameId = next.selectedFrameId
    }

    // MARK: - Phase gating

    func canAdvanceToPhase(_ phase: Phase) -> Bool {
        switch phase {
        case .setup:
            return true
        case .style:
            return isAuthenticated
        case .cast:
            return project.style.locked
        case .frames:
            return !project.characters.isEmpty
        case .export:
            return project.frames.contains { $0.status == .complete }
        }
    }

    // MARK: - Phase

    func setPhase(_ phase: Phase) {
        pushHistory()
        project.currentPhase = phase
    }

    // MARK: - Template

    func selectTemplate(_ templateId: String) {
        pushHistory()
        if templateId == "freeform" {
            let initial = StoryboardFrame(beatId: "custom", beatTitle: "Frame 1")
            project.selectedTemplateId = "freeform"
            project.frames = [initial]
            selectedFrameId = initial.id
        } else if let template = BuiltInTemplates.find(
            byId: templateId, customTemplates: project.customTemplates
        ) {
            let frames = template.frames.map { beat in
                StoryboardFrame(
                    id: "frame-\(beat.id)",
                    beatId: beat.id,
                    beatTitle: beat.title,
                    caption: beat.guidance
                )
            }
            project.selectedTemplateId = templateId
            project.frames = frames
            selectedFrameId = frames.first?.id
        }
    }

    // MARK: - Frames

    func selectFrame(_ id: String?) {
        selectedFrameId = id
    }

    func updateFrame(_ id: String, caption: String? = nil, sceneDescription: String? = nil, imageData: Data? = nil, status: FrameStatus? = nil) {
        guard let index = project.frames.firstIndex(where: { $0.id == id }) else { return }
        pushHistory()
        if let caption { project.frames[index].caption = caption }
        if let sceneDescription { project.frames[index].sceneDescription = sceneDescription }
        if let imageData { project.frames[index].imageData = imageData }
        if let status { project.frames[index].status = status }
    }

    func addFrame() {
        pushHistory()
        let newIndex = project.frames.count + 1
        let frame = StoryboardFrame(beatId: "custom", beatTitle: "Frame \(newIndex)")
        project.frames.append(frame)
        selectedFrameId = frame.id
    }

    func removeFrame(_ id: String) {
        pushHistory()
        project.frames.removeAll { $0.id == id }
        if selectedFrameId == id {
            selectedFrameId = project.frames.first?.id
        }
    }

    func moveFrame(sourceId: String, beforeId: String) {
        guard sourceId != beforeId,
              let fromIndex = project.frames.firstIndex(where: { $0.id == sourceId }),
              let toIndex = project.frames.firstIndex(where: { $0.id == beforeId })
        else { return }
        reorderFrames(from: fromIndex, to: toIndex)
    }

    func reorderFrames(from fromIndex: Int, to toIndex: Int) {
        let count = project.frames.count
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < count,
              toIndex >= 0, toIndex < count else { return }
        pushHistory()
        var frames = project.frames
        let item = frames.remove(at: fromIndex)
        frames.insert(item, at: toIndex)
        project.frames = frames
    }

    // MARK: - Style

    func addReferenceImage(_ data: Data) {
        guard project.style.referenceImages.count < 3 else { return }
        pushHistory()
        project.style.referenceImages.append(data)
    }

    func removeReferenceImage(at index: Int) {
        guard project.style.referenceImages.indices.contains(index) else { return }
        pushHistory()
        project.style.referenceImages.remove(at: index)
    }

    func setStyleDescription(_ description: String) {
        pushHistory()
        project.style.description = description
    }

    func lockStyle() {
        pushHistory()
        project.style.locked = true
        project.currentPhase = .cast
    }

    // MARK: - Cast

    func addCharacter(_ character: StoryboardCharacter) {
        pushHistory()
        project.characters.append(character)
    }

    func updateCharacter(_ id: String, name: String? = nil, role: String? = nil, visualDescription: String? = nil, referenceImageData: Data?? = nil) {
        guard let index = project.characters.firstIndex(where: { $0.id == id }) else { return }
        pushHistory()
        if let name { project.characters[index].name = name }
        if let role { project.characters[index].role = role }
        if let visualDescription { project.characters[index].visualDescription = visualDescription }
        if let imageData = referenceImageData { project.characters[index].referenceImageData = imageData }
    }

    func removeCharacter(_ id: String) {
        pushHistory()
        project.characters.removeAll { $0.id == id }
    }

    // MARK: - Custom templates

    func addCustomTemplate(_ template: Template) {
        pushHistory()
        project.customTemplates.append(template)
    }

    // MARK: - Project

    func resetProject() {
        pushHistory()
        project = .empty
        selectedFrameId = nil
    }

    // MARK: - Convenience

    var selectedFrame: StoryboardFrame? {
        project.frames.first { $0.id == selectedFrameId }
    }

    var selectedTemplate: Template? {
        guard let id = project.selectedTemplateId else { return nil }
        return BuiltInTemplates.find(byId: id, customTemplates: project.customTemplates)
    }
}
