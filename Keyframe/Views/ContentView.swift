import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    private var windowTitle: String {
        if let url = appState.currentFileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return "Untitled"
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            HSplitView {
                CanvasView()
                    .frame(minWidth: 400)

                Divider()

                SidebarView()
            }
        }
        .navigationTitle(windowTitle)
    }
}
