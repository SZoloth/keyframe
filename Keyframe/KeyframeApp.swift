import SwiftUI

@main
struct KeyframeApp: App {
    @State private var appState = AppState()
    @State private var authManager = AuthManager()
    @State private var aiProvider = AIServiceProvider()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(authManager)
                .environment(aiProvider)
                .task {
                    let restored = authManager.resolveAuthMode()
                    if restored != .none {
                        appState.authMode = restored
                    }
                    aiProvider.configure(authMode: appState.authMode)
                }
                .onChange(of: appState.authMode) { _, newMode in
                    aiProvider.configure(authMode: newMode)
                }
        }
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { appState.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!appState.canUndo)

                Button("Redo") { appState.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!appState.canRedo)
            }

            CommandGroup(replacing: .newItem) {
                Button("New project") {
                    appState.resetProject()
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Open...") {
                    ProjectFileManager.open(into: appState)
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") {
                    ProjectFileManager.saveToCurrentFile(state: appState)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save as...") {
                    ProjectFileManager.save(state: appState)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Export PDF...") {
                    let templateName = appState.selectedTemplate?.name ?? "Freeform"
                    PDFExporter.export(
                        frames: appState.project.frames,
                        config: PDFExporter.Config(projectName: "Storyboard", templateName: templateName)
                    )
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.project.frames.filter { $0.status == .complete }.isEmpty)
            }
        }
    }
}
