import SwiftUI

enum BiomarkerStatus: String, Codable, CaseIterable {
    case low = "Low"
    case optimal = "Optimal"
    case high = "High"

    var color: Color {
        switch self {
        case .low: .yellow
        case .optimal: .green
        case .high: .red
        }
    }

    var iconName: String {
        switch self {
        case .low: "arrow.down.circle.fill"
        case .optimal: "checkmark.circle.fill"
        case .high: "arrow.up.circle.fill"
        }
    }
}
