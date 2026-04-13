import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            switch appState.project.currentPhase {
            case .setup:
                EmptyView()
            case .style:
                StyleView()
            case .cast:
                CastView()
            case .frames:
                ChatView()
            case .export:
                ExportSidebarView()
            }
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 400)
        .background(.background)
    }
}

struct ExportSidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var exporting = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc.richtext")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Export storyboard")
                .font(.headline)

            Text("\(completedCount) of \(appState.project.frames.count) frames complete")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                exportPDF()
            } label: {
                Text(exporting ? "Exporting..." : "Export PDF")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .disabled(completedCount == 0 || exporting)
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var completedCount: Int {
        appState.project.frames.filter { $0.status == .complete }.count
    }

    private func exportPDF() {
        exporting = true
        let templateName = appState.selectedTemplate?.name ?? "Freeform"
        let config = PDFExporter.Config(
            projectName: "Storyboard",
            templateName: templateName
        )
        PDFExporter.export(frames: appState.project.frames, config: config)
        exporting = false
    }
}
