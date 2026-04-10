import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var activeTab: Tab = .chat

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case cast = "Cast"
        case style = "Style"
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.project.currentPhase == .export {
                ExportSidebarView()
            } else {
                tabBar
                tabContent
            }
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 400)
        .background(.background)
        .onChange(of: appState.project.currentPhase, initial: true) { _, newPhase in
            syncTab(to: newPhase)
        }
    }

    private func syncTab(to phase: Phase) {
        switch phase {
        case .style: activeTab = .style
        case .cast: activeTab = .cast
        case .frames, .export: activeTab = .chat
        case .setup: break
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    activeTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(activeTab == tab ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(activeTab == tab ? .primary : .secondary)
                        .overlay(alignment: .bottom) {
                            if activeTab == tab {
                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundStyle(.primary)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .chat:
            ChatView()
        case .cast:
            CastView()
        case .style:
            StyleView()
        }
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
