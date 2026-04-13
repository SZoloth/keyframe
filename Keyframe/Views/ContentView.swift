import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthManager.self) private var authManager
    @Environment(AIServiceProvider.self) private var aiProvider
    @State private var refreshTimer: Timer?

    private var windowTitle: String {
        if let url = appState.currentFileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return "Untitled"
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            if appState.project.currentPhase == .setup {
                SetupView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.windowBackgroundColor))
            } else {
                HSplitView {
                    CanvasView()
                        .frame(minWidth: 400)

                    SidebarView()
                }
                .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle(windowTitle)
        .frame(minWidth: 800, minHeight: 500)
        .task { scheduleTokenRefresh() }
        .onDisappear { refreshTimer?.invalidate() }
    }

    private func scheduleTokenRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 50 * 60, repeats: true) { _ in
            Task { @MainActor in
                guard case .oauth = appState.authMode else { return }
                let success = await authManager.refreshOAuthToken()
                if success {
                    appState.authMode = authManager.resolveAuthMode()
                    aiProvider.configure(authMode: appState.authMode)
                }
            }
        }
    }
}
