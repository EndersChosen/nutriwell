import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "leaf.fill"
        }
    }
}

@Model
final class FoodEntry {
    var name: String
    var brand: String
    var barcode: String?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var saturatedFat: Double
    var sugar: Double
    var points: Int
    var servingSize: String
    var mealType: MealType
    var date: Date
    var fdcId: String?

    init(
        name: String,
        brand: String = "",
        barcode: String? = nil,
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double = 0,
        saturatedFat: Double = 0,
        sugar: Double = 0,
        points: Int = 0,
        servingSize: String = "",
        mealType: MealType = .breakfast,
        date: Date = Date(),
        fdcId: String? = nil
    ) {
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.saturatedFat = saturatedFat
        self.sugar = sugar
        self.points = points
        self.servingSize = servingSize
        self.mealType = mealType
        self.date = date
        self.fdcId = fdcId
    }
}
