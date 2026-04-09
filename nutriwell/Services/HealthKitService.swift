import Foundation
import HealthKit

@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    var isAuthorized = false
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // Today's activity data
    var stepCount: Int = 0
    var activeCalories: Int = 0
    var exerciseMinutes: Int = 0
    var distanceWalking: Double = 0 // in miles
    var heartRate: Int = 0

    // Weekly summaries
    var weeklySteps: [(date: Date, value: Int)] = []
    var weeklyCalories: [(date: Date, value: Int)] = []

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let calories = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(calories)
        }
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exercise)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(hr)
        }
        if let workoutType = HKObjectType.workoutType() as HKObjectType? {
            types.insert(workoutType)
        }
        return types
    }()

    private init() {}

    func requestAuthorization() async {
        guard isAvailable else { return }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await refreshAllData()
        } catch {
            print("HealthKit authorization failed: \(error)")
        }
    }

    func refreshAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchSteps() }
            group.addTask { await self.fetchActiveCalories() }
            group.addTask { await self.fetchExerciseMinutes() }
            group.addTask { await self.fetchDistance() }
            group.addTask { await self.fetchHeartRate() }
            group.addTask { await self.fetchWeeklySteps() }
            group.addTask { await self.fetchWeeklyCalories() }
        }
    }

    // MARK: - Fetch Today's Data

    private func fetchSteps() async {
        let value = await fetchTodaySum(for: .stepCount, unit: .count())
        await MainActor.run { self.stepCount = Int(value) }
    }

    private func fetchActiveCalories() async {
        let value = await fetchTodaySum(for: .activeEnergyBurned, unit: .kilocalorie())
        await MainActor.run { self.activeCalories = Int(value) }
    }

    private func fetchExerciseMinutes() async {
        let value = await fetchTodaySum(for: .appleExerciseTime, unit: .minute())
        await MainActor.run { self.exerciseMinutes = Int(value) }
    }

    private func fetchDistance() async {
        let value = await fetchTodaySum(for: .distanceWalkingRunning, unit: .mile())
        await MainActor.run { self.distanceWalking = (value * 10).rounded() / 10 }
    }

    private func fetchHeartRate() async {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let value: Int = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                let bpm = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
        await MainActor.run { self.heartRate = value }
    }

    // MARK: - Weekly Data

    private func fetchWeeklySteps() async {
        let data = await fetchWeeklyData(for: .stepCount, unit: .count())
        await MainActor.run { self.weeklySteps = data }
    }

    private func fetchWeeklyCalories() async {
        let data = await fetchWeeklyData(for: .activeEnergyBurned, unit: .kilocalorie())
        await MainActor.run { self.weeklyCalories = data }
    }

    // MARK: - Workouts

    func fetchRecentWorkouts() async -> [HKWorkout] {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 20, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Helpers

    private func fetchTodaySum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchWeeklyData(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> [(date: Date, value: Int)] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        var interval = DateComponents()
        interval.day = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: sevenDaysAgo,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, _ in
                var results: [(date: Date, value: Int)] = []
                collection?.enumerateStatistics(from: sevenDaysAgo, to: now) { statistics, _ in
                    let value = Int(statistics.sumQuantity()?.doubleValue(for: unit) ?? 0)
                    results.append((date: statistics.startDate, value: value))
                }
                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }
}
