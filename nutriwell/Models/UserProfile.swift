import Foundation
import SwiftData

@Model
final class UserProfile {
    var dailyPointsBudget: Int
    var name: String

    init(name: String = "", dailyPointsBudget: Int = 40) {
        self.name = name
        self.dailyPointsBudget = dailyPointsBudget
    }
}
