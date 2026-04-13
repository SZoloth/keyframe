import Foundation

enum Phase: String, Codable, CaseIterable, Identifiable {
    case setup
    case style
    case cast
    case frames
    case export

    var id: String { rawValue }

    var label: String {
        switch self {
        case .setup: "Setup"
        case .style: "Style"
        case .cast: "Cast"
        case .frames: "Frames"
        case .export: "Export"
        }
    }

    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}
