import SwiftUI

@main
@MainActor
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
                .onChange(of: appState.authMode) { _, newMode in
                    aiProvider.configure(authMode: newMode)
                }
        }
        .defaultSize(width: 1200, height: 800)
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
            }
        }
    }
}
