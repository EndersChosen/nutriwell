import Foundation

/// Calculates points using WW SmartPoints-style coefficients.
/// Calories, saturated fat, and sugar increase points.
/// Protein decreases points (capped so high-protein items don't zero out).
/// Minimum is 0 points.
struct PointsCalculator {
    static func calculate(
        calories: Double,
        saturatedFat: Double,
        sugar: Double,
        protein: Double,
        fiber: Double
    ) -> Int {
        // SmartPoints-style coefficients
        let caloriePart = calories * 0.0305
        let satFatPart = saturatedFat * 0.275
        let sugarPart = sugar * 0.12
        let proteinPart = protein * 0.098

        let raw = caloriePart + satFatPart + sugarPart - proteinPart
        return max(0, Int(round(raw)))
    }
}
