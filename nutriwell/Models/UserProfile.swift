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

    // RMR / body stats
    var rmr: Int?
    var heightFeet: Int?
    var heightInches: Int?
    var age: Int?
    var sex: String?  // "male" or "female"

    init(name: String = "", dailyPointsBudget: Int = 40) {
        self.name = name
        self.dailyPointsBudget = dailyPointsBudget
        self.useGoalBasedPoints = false
    }
}
