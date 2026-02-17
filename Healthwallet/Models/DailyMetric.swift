import Foundation

struct DailyMetric: Codable {
    let date: String // YYYY-MM-DD
    let steps: Int
    let activeEnergyKcal: Double
    let sleepHours: Double
    let sleepDeepHours: Double?
    let sleepRemHours: Double?
    let heartRateAvg: Double?
    let heartRateMin: Double?
    let heartRateMax: Double?
    let restingHeartRate: Double?
    let hrvAvg: Double?
    let weightKg: Double?

    enum CodingKeys: String, CodingKey {
        case date
        case steps
        case activeEnergyKcal = "active_energy_kcal"
        case sleepHours = "sleep_hours"
        case sleepDeepHours = "sleep_deep_hours"
        case sleepRemHours = "sleep_rem_hours"
        case heartRateAvg = "heart_rate_avg"
        case heartRateMin = "heart_rate_min"
        case heartRateMax = "heart_rate_max"
        case restingHeartRate = "resting_heart_rate"
        case hrvAvg = "hrv_avg"
        case weightKg = "weight_kg"
    }
}

struct SyncResponse: Codable {
    let status: String
    let daysSynced: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case daysSynced = "days_synced"
    }
}
