import Foundation

// MARK: - Records DTOs

enum RecordStatus: String, Codable {
    case uploading = "uploading"
    case processing = "processing"
    case pendingReview = "pending_review"
    case completed = "completed"
    case failed = "failed"
}

struct UploadResponse: Codable {
    let recordId: String
    let status: RecordStatus
    let message: String?

    enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case status, message
    }
}

// MARK: - Correlation (Epic 2)

struct CorrelationResponse: Codable, Identifiable {
    var id: String { condition ?? markers.joined(separator: "-") }
    let markers: [String]
    let insight: String
    let severity: String
    let condition: String?
}

// MARK: - Food Recommendation (Epic 3)

struct FoodRecommendationResponse: Codable, Identifiable {
    var id: String { food }
    let food: String
    let portion: String
    let reason: String
    let targets: [String]?
}

// MARK: - Supplement (Epic 3)

struct SupplementResponse: Codable, Identifiable {
    var id: String { name }
    let name: String
    let dosage: String
    let reason: String
    let biomarkerLink: String
    let priority: String

    enum CodingKeys: String, CodingKey {
        case name, dosage, reason, priority
        case biomarkerLink = "biomarker_link"
    }
}

// MARK: - Health Record Response

struct HealthRecordResponse: Codable, Identifiable {
    let id: String
    let status: RecordStatus
    let originalFilename: String
    let recordDate: Date?
    let labProvider: String?
    let recordType: String?

    // Biomarkers
    let biomarkers: [[String: AnyCodable]]

    // Epic 2: AI Analysis
    let summary: String?
    let correlations: [[String: AnyCodable]]?
    let keyFindings: [String]?

    // Epic 3: Recommendations
    let recommendations: [String]
    let foodRecommendations: [[String: AnyCodable]]?
    let supplementProtocol: [[String: AnyCodable]]?

    // Epic 4: Health metrics
    let wellnessScore: Int?
    let healthAge: Int?

    let errorMessage: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status, biomarkers, recommendations, correlations
        case originalFilename = "original_filename"
        case recordDate = "record_date"
        case labProvider = "lab_provider"
        case recordType = "record_type"
        case summary
        case keyFindings = "key_findings"
        case foodRecommendations = "food_recommendations"
        case supplementProtocol = "supplement_protocol"
        case wellnessScore = "wellness_score"
        case healthAge = "health_age"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct HealthRecordListResponse: Codable {
    let records: [HealthRecordResponse]
    let total: Int
    let page: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
        case records, total, page
        case perPage = "per_page"
    }
}

// MARK: - Dashboard Response (Epic 4)

struct DashboardResponse: Codable {
    let wellnessScore: Int
    let healthAge: Int?
    let chronologicalAge: Int?
    let lastSync: String
    let summary: String?
    let scoreBreakdown: [String: Int]?
    let biomarkerTrends: [[String: AnyCodable]]?
    let keyFindings: [String]?
    let correlations: [[String: AnyCodable]]?
    let actionPlan: [[String: AnyCodable]]?
    let supplementProtocol: [[String: AnyCodable]]?
    let totalRecords: Int?

    enum CodingKeys: String, CodingKey {
        case wellnessScore = "wellness_score"
        case healthAge = "health_age"
        case chronologicalAge = "chronological_age"
        case lastSync = "last_sync"
        case summary
        case scoreBreakdown = "score_breakdown"
        case biomarkerTrends = "biomarker_trends"
        case keyFindings = "key_findings"
        case correlations
        case actionPlan = "action_plan"
        case supplementProtocol = "supplement_protocol"
        case totalRecords = "total_records"
    }
}

// MARK: - Comparison Response (Epic 4)

struct BiomarkerTrend: Codable, Identifiable {
    var id: String { name }
    let name: String
    let unit: String
    let dataPoints: [[String: AnyCodable]]
    let changePercent: Double?
    let trend: String

    enum CodingKeys: String, CodingKey {
        case name, unit, trend
        case dataPoints = "data_points"
        case changePercent = "change_percent"
    }
}

struct ComparisonResponse: Codable {
    let biomarkerTrends: [BiomarkerTrend]
    let recordsCompared: Int
    let dateRange: [String: String]

    enum CodingKeys: String, CodingKey {
        case biomarkerTrends = "biomarker_trends"
        case recordsCompared = "records_compared"
        case dateRange = "date_range"
    }
}

// MARK: - Doctor Brief (Epic 5)

struct DoctorBriefRequest: Codable {
    let includeTrends: Bool
    let includeCorrelations: Bool
    let recordsToInclude: Int

    enum CodingKeys: String, CodingKey {
        case includeTrends = "include_trends"
        case includeCorrelations = "include_correlations"
        case recordsToInclude = "records_to_include"
    }
}

struct DoctorBriefResponse: Codable {
    let pdfBase64: String?
    let generatedAt: Date

    enum CodingKeys: String, CodingKey {
        case pdfBase64 = "pdf_base64"
        case generatedAt = "generated_at"
    }
}

// MARK: - Verification (Epic 1)

struct BiomarkerResponse: Codable, Identifiable {
    var id: String { name }
    let name: String
    let value: Double
    let unit: String
    let status: String
    let referenceRange: String?
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case name, value, unit, status, confidence
        case referenceRange = "reference_range"
    }
}

struct RecordResponse: Codable, Identifiable {
    let id: String
    let filename: String
    let status: RecordStatus
    let uploadedAt: Date
    let processedAt: Date?
    let biomarkers: [BiomarkerResponse]
    let summary: String?
    let correlations: [CorrelationResponse]?
    let keyFindings: [String]?
    let wellnessScore: Int?
    let healthAge: Int?

    enum CodingKeys: String, CodingKey {
        case id, filename, status, biomarkers, summary, correlations
        case uploadedAt = "uploaded_at"
        case processedAt = "processed_at"
        case keyFindings = "key_findings"
        case wellnessScore = "wellness_score"
        case healthAge = "health_age"
    }
}

struct BiomarkerEdit: Codable {
    let name: String
    let newValue: Double
    let newUnit: String?

    enum CodingKeys: String, CodingKey {
        case name
        case newValue = "new_value"
        case newUnit = "new_unit"
    }
}

struct VerifyRecordRequest: Codable {
    let biomarkerEdits: [BiomarkerEdit]
    let approved: Bool

    enum CodingKeys: String, CodingKey {
        case biomarkerEdits = "biomarker_edits"
        case approved
    }
}

struct VerifyRecordResponse: Codable {
    let id: String
    let status: RecordStatus
    let biomarkers: [[String: AnyCodable]]
    let message: String
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Records Service

actor RecordsService {
    static let shared = RecordsService()
    private init() {}

    func uploadRecord(fileData: Data, filename: String) async throws -> UploadResponse {
        return try await APIClient.shared.upload("/records/upload", fileData: fileData, filename: filename)
    }

    func getRecord(id: String) async throws -> HealthRecordResponse {
        return try await APIClient.shared.get("/records/\(id)")
    }

    func listRecords(page: Int = 1, perPage: Int = 10) async throws -> HealthRecordListResponse {
        return try await APIClient.shared.get("/records?page=\(page)&per_page=\(perPage)")
    }

    func pollRecordStatus(id: String, maxAttempts: Int = 20, interval: TimeInterval = 3) async throws -> HealthRecordResponse {
        for _ in 0..<maxAttempts {
            let record: HealthRecordResponse = try await APIClient.shared.get("/records/\(id)")

            switch record.status {
            case .completed, .failed, .pendingReview:
                return record
            case .uploading, .processing:
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }

        throw APIError.serverError(408, "Processing timeout")
    }

    func getRecordForVerification(id: String) async throws -> HealthRecordResponse {
        return try await APIClient.shared.get("/records/\(id)")
    }

    // MARK: - Epic 1: Verification

    func verifyRecord(id: String, edits: [BiomarkerEdit], approved: Bool) async throws {
        let request = VerifyRecordRequest(biomarkerEdits: edits, approved: approved)
        let _: VerifyRecordResponse = try await APIClient.shared.post("/records/\(id)/verify", body: request)
    }

    // MARK: - Epic 4: Dashboard

    func getDashboard() async throws -> DashboardResponse {
        return try await APIClient.shared.get("/records/dashboard/summary")
    }

    // MARK: - Epic 4: Comparison

    func getComparison() async throws -> ComparisonResponse {
        return try await APIClient.shared.get("/records/comparison")
    }

    // MARK: - Epic 5: Doctor Brief

    func exportDoctorBrief(includeTrends: Bool = true, includeCorrelations: Bool = true, recordCount: Int = 3) async throws -> Data {
        let request = DoctorBriefRequest(
            includeTrends: includeTrends,
            includeCorrelations: includeCorrelations,
            recordsToInclude: recordCount
        )
        let response: DoctorBriefResponse = try await APIClient.shared.post("/records/export/doctor-brief", body: request)

        guard let base64 = response.pdfBase64,
              let pdfData = Data(base64Encoded: base64) else {
            throw APIError.invalidResponse
        }

        return pdfData
    }
}

// MARK: - HealthRecordResponse to HealthRecord Conversion

extension HealthRecordResponse {
    func toHealthRecord() -> HealthRecord {
        let parsedBiomarkers = biomarkers.compactMap { dict -> Biomarker? in
            guard let nameValue = dict["name"]?.value as? String,
                  let valueNum = dict["value"]?.value as? Double,
                  let unitStr = dict["unit"]?.value as? String else {
                return nil
            }

            let statusStr = dict["status"]?.value as? String ?? "optimal"
            let status: BiomarkerStatus = switch statusStr.lowercased() {
            case "low": .low
            case "high": .high
            default: .optimal
            }

            var minRange: Double = 0
            var maxRange: Double = 100
            if let refRange = dict["reference_range"]?.value as? [String: Any] {
                minRange = refRange["min"] as? Double ?? 0
                maxRange = refRange["max"] as? Double ?? 100
            }

            return Biomarker(
                name: nameValue,
                value: valueNum,
                unit: unitStr,
                status: status,
                optimalRange: minRange...maxRange,
                description: getDescription(for: nameValue),
                whyItMatters: getWhyItMatters(for: nameValue),
                foodFixes: getFoodFixes(for: nameValue, status: status)
            )
        }

        return HealthRecord(
            title: originalFilename.replacingOccurrences(of: ".pdf", with: ""),
            date: recordDate ?? createdAt,
            provider: labProvider ?? "Uploaded",
            type: .bloodPanel,
            biomarkers: parsedBiomarkers
        )
    }
}

// MARK: - Biomarker Content Helpers

private func getDescription(for name: String) -> String {
    let descriptions: [String: String] = [
        "Vitamin D": "Vitamin D is crucial for bone health, immune function, and mood regulation. It helps your body absorb calcium and supports muscle function.",
        "LDL Cholesterol": "LDL (Low-Density Lipoprotein) is often called 'bad' cholesterol. High levels can lead to plaque buildup in arteries.",
        "HDL Cholesterol": "HDL (High-Density Lipoprotein) is 'good' cholesterol that helps remove other forms of cholesterol from your bloodstream.",
        "Glucose": "Blood glucose is your body's main source of energy. Maintaining healthy levels is essential for overall metabolic health.",
        "Fasting Glucose": "Fasting glucose measures blood sugar after not eating for 8+ hours. It's a key indicator of metabolic health.",
        "Iron": "Iron is essential for producing hemoglobin, which carries oxygen in your blood. It also supports energy and cognitive function.",
        "Ferritin": "Ferritin reflects your body's iron stores. Low levels can cause fatigue even before anemia develops.",
        "Vitamin B12": "Vitamin B12 is vital for nerve function, DNA production, and red blood cell formation.",
        "TSH": "Thyroid Stimulating Hormone controls your thyroid. High TSH often indicates underactive thyroid.",
        "Hemoglobin": "Hemoglobin carries oxygen throughout your body. Low levels indicate anemia.",
    ]
    return descriptions[name] ?? "This biomarker is important for your overall health."
}

private func getWhyItMatters(for name: String) -> [String] {
    let reasons: [String: [String]] = [
        "Vitamin D": [
            "Linked to lower energy levels",
            "Important for bone density",
            "Affects immune system function",
            "May impact mood and mental health"
        ],
        "LDL Cholesterol": [
            "Risk factor for heart disease",
            "Can cause arterial plaque buildup",
            "Affects cardiovascular health",
            "Manageable through diet and exercise"
        ],
        "Glucose": [
            "Primary energy source for cells",
            "Indicator of metabolic health",
            "Important for diabetes prevention",
            "Affects energy levels throughout the day"
        ],
        "Ferritin": [
            "Reflects total body iron stores",
            "Low levels cause fatigue",
            "Important for oxygen transport",
            "Affects energy and cognition"
        ],
    ]
    return reasons[name] ?? ["Important for overall health", "Should be monitored regularly"]
}

private func getFoodFixes(for name: String, status: BiomarkerStatus) -> [FoodFix] {
    guard status != .optimal else { return [] }

    let fixes: [String: [FoodFix]] = [
        "Vitamin D": [
            FoodFix(name: "Cod Liver Oil", portion: "1 tbsp (1360 IU)", iconName: "drop.fill"),
            FoodFix(name: "Sockeye Salmon", portion: "3 oz (570 IU)", iconName: "fish.fill"),
            FoodFix(name: "Fortified Milk", portion: "1 cup (120 IU)", iconName: "cup.and.saucer.fill"),
            FoodFix(name: "Egg Yolks", portion: "2 large (80 IU)", iconName: "oval.fill")
        ],
        "LDL Cholesterol": [
            FoodFix(name: "Oatmeal", portion: "1 cup daily", iconName: "leaf.fill"),
            FoodFix(name: "Almonds", portion: "1 oz (23 nuts)", iconName: "tree.fill"),
            FoodFix(name: "Olive Oil", portion: "2 tbsp daily", iconName: "drop.fill"),
            FoodFix(name: "Fatty Fish", portion: "2 servings/week", iconName: "fish.fill")
        ],
        "Iron": [
            FoodFix(name: "Red Meat", portion: "3 oz serving", iconName: "flame.fill"),
            FoodFix(name: "Spinach", portion: "1 cup cooked", iconName: "leaf.fill"),
            FoodFix(name: "Lentils", portion: "1 cup cooked", iconName: "circle.grid.3x3.fill"),
            FoodFix(name: "Dark Chocolate", portion: "1 oz (85% cacao)", iconName: "square.fill")
        ],
        "Ferritin": [
            FoodFix(name: "Beef Liver", portion: "3 oz, 2x/week", iconName: "flame.fill"),
            FoodFix(name: "Spinach + Lemon", portion: "2 cups salad", iconName: "leaf.fill"),
            FoodFix(name: "Pumpkin Seeds", portion: "1/4 cup daily", iconName: "circle.fill"),
        ],
    ]

    return fixes[name] ?? []
}
