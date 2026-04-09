import Foundation
import SwiftData

@Model
final class WeightEntry {
    var weight: Double
    var date: Date
    var unit: String

    init(weight: Double, date: Date = Date(), unit: String = "lbs") {
        self.weight = weight
        self.date = date
        self.unit = unit
    }
}
