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

    /// Calculate the daily points budget based on current weight, goal, and timeline.
    /// - Parameters:
    ///   - currentWeight: Current weight in lbs
    ///   - goalWeight: Target weight in lbs
    ///   - weeksRemaining: Weeks left to reach goal
    /// - Returns: Recommended daily points budget
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

        // Daily calorie deficit needed
        let dailyDeficit = (weeklyLoss * caloriesPerPound) / 7.0

        // Baseline maintenance calories (Mifflin-St Jeor rough estimate for moderate activity)
        // Using a simplified formula: ~15 cal/lb for moderately active
        let maintenanceCalories = currentWeight * 15.0

        // Target daily calories
        let targetCalories = maintenanceCalories - dailyDeficit

        // Convert to points
        let points = Int(round(targetCalories / caloriesPerPoint))

        return max(minimumDailyPoints, points)
    }

    /// Baseline maintenance points for a given weight (no deficit).
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
