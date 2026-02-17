import Foundation
import HealthKit
import Observation

@Observable
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var isAuthorized = false
    var isLoading = false
    var error: String?

    // Today's quick stats for dashboard
    var todaySteps: Int = 0
    var todaySleepHours: Double = 0
    var todayHRV: Double = 0
    var todayRestingHR: Double = 0
    var todayActiveEnergy: Double = 0
    var latestWeight: Double? = nil

    private let healthStore = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        // Characteristic types for profile auto-population
        if let dobType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dobType)
        }
        if let sexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(sexType)
        }
        return types
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else {
            error = "HealthKit is not available on this device"
            throw HealthKitError.notAvailable
        }

        // Capture for use in non-isolated task
        let store = healthStore
        let types = readTypes

        // Use a timeout to prevent hanging if the system dialog never appears
        // (e.g., missing entitlement or usage description)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    store.requestAuthorization(toShare: nil, read: types) { success, authError in
                        if let authError {
                            continuation.resume(throwing: authError)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                throw HealthKitError.authorizationTimeout
            }
            // Whichever finishes first wins; cancel the other
            _ = try await group.next()
            group.cancelAll()
        }

        checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() {
        guard isAvailable else {
            isAuthorized = false
            return
        }

        // HealthKit does not expose a simple "authorized" boolean for read types.
        // We check the authorization status for a key type (steps) as a proxy.
        // .sharingAuthorized is only for write; for read, the status is .notDetermined
        // if never asked. After the user responds, we simply trust the request succeeded.
        // A practical approach: try to query steps and see if data comes back.
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            isAuthorized = false
            return
        }

        _ = healthStore.authorizationStatus(for: stepsType)
        // For read-only, authorizationStatus is not reliable (Apple privacy design).
        // We set isAuthorized = true after a successful requestAuthorization call.
        // As a fallback, check if we previously stored the flag.
        let hasRequested = UserDefaults.standard.bool(forKey: "healthkit_authorized")
        isAuthorized = hasRequested
    }

    func markAuthorized() {
        UserDefaults.standard.set(true, forKey: "healthkit_authorized")
        isAuthorized = true
    }

    // MARK: - Profile Characteristics

    func getDateOfBirth() -> Date? {
        guard isAvailable else { return nil }
        do {
            let components = try healthStore.dateOfBirthComponents()
            return Calendar.current.date(from: components)
        } catch {
            return nil
        }
    }

    func getBiologicalSex() -> HKBiologicalSex? {
        guard isAvailable else { return nil }
        do {
            let bioSex = try healthStore.biologicalSex()
            return bioSex.biologicalSex
        } catch {
            return nil
        }
    }

    // MARK: - Data Fetching

    func fetchTodayStats() async {
        guard isAvailable else { return }

        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        async let steps = fetchSteps(start: startOfDay, end: now)
        async let sleep = fetchSleepAnalysis(start: calendar.date(byAdding: .day, value: -1, to: startOfDay)!, end: now)
        async let hrv = fetchHRV(start: startOfDay, end: now)
        async let restingHR = fetchRestingHeartRate(start: startOfDay, end: now)
        async let activeEnergy = fetchActiveEnergy(start: startOfDay, end: now)
        async let weight = fetchWeight()

        let (s, sl, h, rhr, ae, w) = await (steps, sleep, hrv, restingHR, activeEnergy, weight)

        todaySteps = Int(s)
        todaySleepHours = sl.total
        todayHRV = h
        todayRestingHR = rhr
        todayActiveEnergy = ae
        latestWeight = w
    }

    func fetchDailyMetrics(days: Int = 7) async -> [DailyMetric] {
        guard isAvailable else { return [] }

        let calendar = Calendar.current
        let now = Date()
        var metrics: [DailyMetric] = []

        for dayOffset in 0..<days {
            if dayOffset == 0 {
                // Today: use start of today to now
                let startOfToday = calendar.startOfDay(for: now)
                let endOfToday = now
                let sleepStart = calendar.date(byAdding: .day, value: -1, to: startOfToday)!

                async let steps = fetchSteps(start: startOfToday, end: endOfToday)
                async let activeEnergy = fetchActiveEnergy(start: startOfToday, end: endOfToday)
                async let sleep = fetchSleepAnalysis(start: sleepStart, end: endOfToday)
                async let heartRate = fetchHeartRate(start: startOfToday, end: endOfToday)
                async let restingHR = fetchRestingHeartRate(start: startOfToday, end: endOfToday)
                async let hrv = fetchHRV(start: startOfToday, end: endOfToday)
                async let weight = fetchWeight()

                let (s, ae, sl, hr, rhr, h, w) = await (steps, activeEnergy, sleep, heartRate, restingHR, hrv, weight)

                let metric = DailyMetric(
                    date: Self.dateFormatter.string(from: startOfToday),
                    steps: Int(s),
                    activeEnergyKcal: ae,
                    sleepHours: sl.total,
                    sleepDeepHours: sl.deep > 0 ? sl.deep : nil,
                    sleepRemHours: sl.rem > 0 ? sl.rem : nil,
                    heartRateAvg: hr.avg > 0 ? hr.avg : nil,
                    heartRateMin: hr.min > 0 ? hr.min : nil,
                    heartRateMax: hr.max > 0 ? hr.max : nil,
                    restingHeartRate: rhr > 0 ? rhr : nil,
                    hrvAvg: h > 0 ? h : nil,
                    weightKg: w
                )
                metrics.append(metric)
            } else {
                // Previous days: full day window
                let fullDayStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -dayOffset, to: now)!)
                let fullDayEnd = calendar.date(byAdding: .day, value: 1, to: fullDayStart)!
                let sleepStart = calendar.date(byAdding: .day, value: -1, to: fullDayStart)!

                async let steps = fetchSteps(start: fullDayStart, end: fullDayEnd)
                async let activeEnergy = fetchActiveEnergy(start: fullDayStart, end: fullDayEnd)
                async let sleep = fetchSleepAnalysis(start: sleepStart, end: fullDayEnd)
                async let heartRate = fetchHeartRate(start: fullDayStart, end: fullDayEnd)
                async let restingHR = fetchRestingHeartRate(start: fullDayStart, end: fullDayEnd)
                async let hrv = fetchHRV(start: fullDayStart, end: fullDayEnd)

                let (s, ae, sl, hr, rhr, h) = await (steps, activeEnergy, sleep, heartRate, restingHR, hrv)

                let metric = DailyMetric(
                    date: Self.dateFormatter.string(from: fullDayStart),
                    steps: Int(s),
                    activeEnergyKcal: ae,
                    sleepHours: sl.total,
                    sleepDeepHours: sl.deep > 0 ? sl.deep : nil,
                    sleepRemHours: sl.rem > 0 ? sl.rem : nil,
                    heartRateAvg: hr.avg > 0 ? hr.avg : nil,
                    heartRateMin: hr.min > 0 ? hr.min : nil,
                    heartRateMax: hr.max > 0 ? hr.max : nil,
                    restingHeartRate: rhr > 0 ? rhr : nil,
                    hrvAvg: h > 0 ? h : nil,
                    weightKg: nil // Only fetch latest weight for today
                )
                metrics.append(metric)
            }
        }

        return metrics.reversed() // Oldest first
    }

    func syncToBackend() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let metrics = await fetchDailyMetrics(days: 7)
            guard !metrics.isEmpty else {
                error = "No HealthKit data to sync"
                return
            }

            struct SyncRequest: Codable {
                let metrics: [DailyMetric]
            }

            let _: SyncResponse = try await APIClient.shared.post(
                "/healthkit/sync",
                body: SyncRequest(metrics: metrics)
            )

            print("[HealthKit] Synced \(metrics.count) days to backend")
        } catch {
            self.error = "Failed to sync health data: \(error.localizedDescription)"
            print("[HealthKit] Sync error: \(error)")
        }
    }

    // MARK: - Individual Queries

    private func fetchSteps(start: Date, end: Date) async -> Double {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchActiveEnergy(start: Date, end: Date) async -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepAnalysis(start: Date, end: Date) async -> (total: Double, deep: Double, rem: Double) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (0, 0, 0)
        }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: (0, 0, 0))
                    return
                }

                var totalSeconds: Double = 0
                var deepSeconds: Double = 0
                var remSeconds: Double = 0

                for sample in samples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)

                    switch value {
                    case .asleepCore:
                        totalSeconds += duration
                    case .asleepDeep:
                        totalSeconds += duration
                        deepSeconds += duration
                    case .asleepREM:
                        totalSeconds += duration
                        remSeconds += duration
                    case .asleepUnspecified:
                        totalSeconds += duration
                    default:
                        // .inBed, .awake, etc. -- do not count
                        break
                    }
                }

                let totalHours = totalSeconds / 3600.0
                let deepHours = deepSeconds / 3600.0
                let remHours = remSeconds / 3600.0

                continuation.resume(returning: (totalHours, deepHours, remHours))
            }
            healthStore.execute(query)
        }
    }

    private func fetchHeartRate(start: Date, end: Date) async -> (avg: Double, min: Double, max: Double) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return (0, 0, 0)
        }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: (0, 0, 0))
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let values = samples.map { $0.quantity.doubleValue(for: unit) }

                let avg = values.reduce(0, +) / Double(values.count)
                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 0

                continuation.resume(returning: (
                    (avg * 10).rounded() / 10,
                    (minVal * 10).rounded() / 10,
                    (maxVal * 10).rounded() / 10
                ))
            }
            healthStore.execute(query)
        }
    }

    private func fetchRestingHeartRate(start: Date, end: Date) async -> Double {
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return 0
        }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: (value * 10).rounded() / 10)
            }
            healthStore.execute(query)
        }
    }

    private func fetchHRV(start: Date, end: Date) async -> Double {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return 0
        }

        return await withCheckedContinuation { continuation in
            // For the most meaningful HRV, filter to nighttime samples (10pm-6am)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: 0)
                    return
                }

                let calendar = Calendar.current

                // Filter for nighttime samples (10pm - 6am) for a more stable reading
                let nighttimeSamples = samples.filter { sample in
                    let hour = calendar.component(.hour, from: sample.startDate)
                    return hour >= 22 || hour < 6
                }

                let samplesToUse = nighttimeSamples.isEmpty ? samples : nighttimeSamples
                let unit = HKUnit.secondUnit(with: .milli)
                let values = samplesToUse.map { $0.quantity.doubleValue(for: unit) }
                let avg = values.reduce(0, +) / Double(values.count)

                continuation.resume(returning: (avg * 10).rounded() / 10)
            }
            healthStore.execute(query)
        }
    }

    private func fetchWeight() async -> Double? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: (kg * 10).rounded() / 10)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationTimeout

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Apple Health is not available on this device."
        case .authorizationTimeout:
            return "Apple Health authorization timed out. Please check that HealthKit is enabled in Settings."
        }
    }
}
