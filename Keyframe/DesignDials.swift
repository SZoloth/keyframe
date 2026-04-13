#if DEBUG
import DialKit
import SwiftUI

struct ThemeDials: Codable, Equatable {
    var cornerRadius: Double = 12
    var spacing: Double = 16
    var animationDuration: Double = 0.25
    var animationDamping: Double = 0.8
    var accentHue: Double = 210
}

@MainActor
let themeDials = DialPanelState(
    name: "Theme",
    initial: ThemeDials(),
    controls: [
        .slider("cornerRadius", keyPath: \.cornerRadius, label: "Corner Radius", range: 0...32),
        .slider("spacing", keyPath: \.spacing, label: "Spacing", range: 4.0...48.0),
        .slider("animationDuration", keyPath: \.animationDuration, label: "Duration", range: 0.1...1.0),
        .slider("animationDamping", keyPath: \.animationDamping, label: "Damping", range: 0.1...1.0),
        .slider("accentHue", keyPath: \.accentHue, label: "Accent Hue", range: 0.0...360.0),
    ]
)
#endif
