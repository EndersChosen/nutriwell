import Foundation
import SwiftData

@Model
final class UserProfile {
    var dailyPointsBudget: Int
    var name: String

    // Weight goal fields
    var startingWeight: Double?
    var goalWeight: Double?
    var goalWeeks: Int?
    var goalStartDate: Date?
    var lastRecalcDate: Date?
    var useGoalBasedPoints: Bool

    init(name: String = "", dailyPointsBudget: Int = 40) {
        self.name = name
        self.dailyPointsBudget = dailyPointsBudget
        self.useGoalBasedPoints = false
    }
}
