import Foundation

/// Calculates daily points budget based on weight goals.
///
/// Uses the principle that ~3,500 calories = 1 lb of fat.
/// Each point ≈ 33 calories (based on SmartPoints formula).
/// Weekly weight loss is capped at 2 lbs/week for safety.
struct GoalCalculator {
    private static let caloriesPerPound: Double = 3500
    private static let caloriesPerPoint: Double = 33.0
    private static let maxWeeklyLossLbs: Double = 2.0
    private static let minimumDailyPoints: Int = 18

    /// Activity multiplier applied to RMR to estimate TDEE (moderate activity).
    private static let activityMultiplier: Double = 1.55

    // MARK: - RMR Calculation

    /// Calculate RMR using the Mifflin-St Jeor equation.
    /// - Parameters:
    ///   - weightLbs: Weight in pounds
    ///   - heightInches: Total height in inches
    ///   - age: Age in years
    ///   - isMale: true for male, false for female
    /// - Returns: Resting Metabolic Rate in calories/day
    static func calculateRMR(weightLbs: Double, heightInches: Double, age: Int, isMale: Bool) -> Int {
        // RMR = (4.54 × weight in lbs) + (15.88 × height in inches) - (5 × age) - offset
        // offset: 5 for men, 161 for women
        let offset: Double = isMale ? 5.0 : 161.0
        let rmr = (4.54 * weightLbs) + (15.88 * heightInches) - (5.0 * Double(age)) - offset
        return max(800, Int(round(rmr)))
    }

    /// Convert feet + inches to total inches.
    static func totalInches(feet: Int, inches: Int) -> Double {
        Double(feet * 12 + inches)
    }

    // MARK: - Daily Points Calculation

    /// Calculate daily points using RMR for accurate maintenance calories.
    static func calculateDailyPoints(
        currentWeight: Double,
        goalWeight: Double,
        weeksRemaining: Int,
        rmr: Int
    ) -> Int {
        guard weeksRemaining > 0, currentWeight > goalWeight else {
            return baselinePoints(forRMR: rmr)
        }

        let totalToLose = currentWeight - goalWeight
        let weeklyLoss = min(totalToLose / Double(weeksRemaining), maxWeeklyLossLbs)
        let dailyDeficit = (weeklyLoss * caloriesPerPound) / 7.0

        // TDEE = RMR × activity multiplier
        let maintenanceCalories = Double(rmr) * activityMultiplier
        let targetCalories = maintenanceCalories - dailyDeficit

        let points = Int(round(targetCalories / caloriesPerPoint))
        return max(minimumDailyPoints, points)
    }

    /// Fallback: calculate daily points without RMR (uses ~15 cal/lb estimate).
    static func calculateDailyPoints(
        currentWeight: Double,
        goalWeight: Double,
        weeksRemaining: Int
    ) -> Int {
        guard weeksRemaining > 0, currentWeight > goalWeight else {
            return baselinePoints(for: currentWeight)
        }

        let totalToLose = currentWeight - goalWeight
        let weeklyLoss = min(totalToLose / Double(weeksRemaining), maxWeeklyLossLbs)
        let dailyDeficit = (weeklyLoss * caloriesPerPound) / 7.0
        let maintenanceCalories = currentWeight * 15.0
        let targetCalories = maintenanceCalories - dailyDeficit
        let points = Int(round(targetCalories / caloriesPerPoint))

        return max(minimumDailyPoints, points)
    }

    /// Baseline maintenance points using RMR.
    static func baselinePoints(forRMR rmr: Int) -> Int {
        let maintenanceCalories = Double(rmr) * activityMultiplier
        return max(minimumDailyPoints, Int(round(maintenanceCalories / caloriesPerPoint)))
    }

    /// Baseline maintenance points for a given weight (no RMR available).
    static func baselinePoints(for weight: Double) -> Int {
        let maintenanceCalories = weight * 15.0
        return max(minimumDailyPoints, Int(round(maintenanceCalories / caloriesPerPoint)))
    }

    /// Calculate weeks remaining from the goal start date and total weeks.
    static func weeksRemaining(startDate: Date, totalWeeks: Int) -> Int {
        let calendar = Calendar.current
        let weeksPassed = calendar.dateComponents([.weekOfYear], from: startDate, to: Date()).weekOfYear ?? 0
        return max(1, totalWeeks - weeksPassed)
    }

    /// Determine the expected weekly loss rate.
    static func weeklyLossRate(currentWeight: Double, goalWeight: Double, weeksRemaining: Int) -> Double {
        guard weeksRemaining > 0, currentWeight > goalWeight else { return 0 }
        let totalToLose = currentWeight - goalWeight
        return min(totalToLose / Double(weeksRemaining), maxWeeklyLossLbs)
    }
}
