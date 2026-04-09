import Foundation

/// Calculates Weight-Watchers-style points from nutritional info.
/// Formula: points = (calories / 50) + (saturatedFat / 4) + (sugar / 9) - (protein / 10) - (fiber / 4)
/// Minimum is 0 points.
struct PointsCalculator {
    static func calculate(
        calories: Double,
        saturatedFat: Double,
        sugar: Double,
        protein: Double,
        fiber: Double
    ) -> Int {
        let raw = (calories / 50.0)
            + (saturatedFat / 4.0)
            + (sugar / 9.0)
            - (protein / 10.0)
            - (min(fiber, 4.0) / 4.0)
        return max(0, Int(round(raw)))
    }
}
