import Foundation

struct HealthRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let date: Date
    let provider: String
    let type: RecordType
    let biomarkers: [Biomarker]

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        provider: String,
        type: RecordType,
        biomarkers: [Biomarker] = []
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.provider = provider
        self.type = type
        self.biomarkers = biomarkers
    }

    var formattedDate: String {
        date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits))
    }
}

enum RecordType: String, Codable, CaseIterable {
    case bloodPanel = "Blood Panel"
    case annualPhysical = "Annual Physical"
    case hormonePanel = "Hormone Panel"

    var iconName: String {
        switch self {
        case .bloodPanel: "drop.fill"
        case .annualPhysical: "heart.text.square.fill"
        case .hormonePanel: "flask.fill"
        }
    }

    var tintColorName: String {
        switch self {
        case .bloodPanel: "red"
        case .annualPhysical: "blue"
        case .hormonePanel: "purple"
        }
    }
}
