import SwiftUI

struct CanvasView: View {
    @Environment(AppState.self) private var appState
    @State private var draggedFrameId: String?

    private var isFreeform: Bool {
        appState.project.selectedTemplateId == "freeform"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.Colors.background
                .ignoresSafeArea()

            if appState.project.frames.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                frameGrid
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No frames yet",
            systemImage: "film",
            description: Text("Select a template or add frames to get started.")
        )
    }

    private var frameGrid: some View {
        ScrollView(.vertical) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 20)],
                spacing: 20
            ) {
                ForEach(appState.project.frames) { frame in
                    FrameCard(frame: frame, isSelected: frame.id == appState.selectedFrameId)
                        .onTapGesture {
                            appState.selectFrame(frame.id)
                        }
                        .contextMenu {
                            if isFreeform {
                                Button("Delete frame", role: .destructive) {
                                    appState.removeFrame(frame.id)
                                }
                            }
                        }
                        .draggable(frame.id) {
                            FrameCard(frame: frame, isSelected: false)
                                .frame(width: 200)
                                .opacity(0.8)
                                .onAppear { draggedFrameId = frame.id }
                        }
                        .dropDestination(for: String.self) { droppedIds, _ in
                            guard let sourceId = droppedIds.first else { return false }
                            appState.moveFrame(sourceId: sourceId, beforeId: frame.id)
                            return true
                        } isTargeted: { targeted in
                            // visual feedback handled by SwiftUI
                        }
                }

                if isFreeform {
                    addFrameButton
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var addFrameButton: some View {
        Button {
            appState.addFrame()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Add frame")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(.quaternary)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FrameCard: View {
    let frame: StoryboardFrame
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            imageArea

            VStack(alignment: .leading, spacing: 4) {
                Text(frame.beatTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if !frame.caption.isEmpty {
                    Text(frame.caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Theme.Colors.accent : Theme.Colors.separator, lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.1 : 0.04), radius: isSelected ? 4 : 2)
    }

    @ViewBuilder
    private var imageArea: some View {
        if let imageData = frame.imageData, let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(height: 200)
                .clipped()
        } else {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text(statusLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
        }
    }

    private var statusIcon: String {
        switch frame.status {
        case .empty: return "photo"
        case .generating: return "hourglass"
        case .complete: return "checkmark.circle"
        }
    }

    private var statusLabel: String {
        switch frame.status {
        case .empty: return "No image"
        case .generating: return "Generating..."
        case .complete: return "Complete"
        }
    }
}
