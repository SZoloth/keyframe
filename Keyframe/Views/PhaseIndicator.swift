import SwiftUI

struct PhaseIndicator: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(Phase.allCases.enumerated()), id: \.element) { index, phase in
                if index > 0 {
                    Rectangle()
                        .fill(isPast(phase) ? Theme.Colors.primary : Theme.Colors.separator)
                        .frame(width: 20, height: 1)
                }

                Button {
                    if appState.canAdvanceToPhase(phase) {
                        appState.setPhase(phase)
                    }
                } label: {
                    Text(phase.label)
                        .font(.caption)
                        .fontWeight(isActive(phase) ? .semibold : .regular)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isActive(phase) ? Color.primary : Color.clear)
                        .foregroundStyle(foregroundColor(for: phase))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(!appState.canAdvanceToPhase(phase))
            }
        }
    }

    private func isActive(_ phase: Phase) -> Bool {
        appState.project.currentPhase == phase
    }

    private func isPast(_ phase: Phase) -> Bool {
        phase.index < appState.project.currentPhase.index
    }

    private func foregroundColor(for phase: Phase) -> Color {
        if isActive(phase) { return Theme.Colors.background }
        if isPast(phase) { return .primary }
        return .secondary
    }
}
