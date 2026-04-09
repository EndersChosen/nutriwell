import Foundation

/// Unified food result from any data source (USDA, Open Food Facts, etc.)
struct FoodResult: Identifiable {
    let id: String
    let name: String
    let brand: String
    let barcode: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let saturatedFat: Double
    let sugar: Double
    let servingSize: String
    let source: FoodSource

    var points: Int {
        PointsCalculator.calculate(
            calories: calories,
            saturatedFat: saturatedFat,
            sugar: sugar,
            protein: protein,
            fiber: fiber
        )
    }

    enum FoodSource: String {
        case usda = "USDA"
        case openFoodFacts = "Open Food Facts"
    }

    // MARK: - From USDA

    static func from(usdaFood: USDAFood) -> FoodResult {
        FoodResult(
            id: "usda-\(usdaFood.fdcId)",
            name: usdaFood.description,
            brand: usdaFood.displayBrand,
            barcode: usdaFood.gtinUpc,
            calories: usdaFood.calories,
            protein: usdaFood.protein,
            carbs: usdaFood.carbs,
            fat: usdaFood.fat,
            fiber: usdaFood.fiber,
            saturatedFat: usdaFood.saturatedFat,
            sugar: usdaFood.sugar,
            servingSize: usdaFood.servingDescription,
            source: .usda
        )
    }

    // MARK: - From Open Food Facts

    static func from(offProduct: OFFProduct, barcode: String) -> FoodResult {
        let n = offProduct.nutriments

        // Prefer per-serving values, fall back to per-100g
        let cal = n?.energyKcalServing ?? n?.energyKcal100g ?? 0
        let pro = n?.proteinsServing ?? n?.proteins100g ?? 0
        let carb = n?.carbohydratesServing ?? n?.carbohydrates100g ?? 0
        let f = n?.fatServing ?? n?.fat100g ?? 0
        let fib = n?.fiberServing ?? n?.fiber100g ?? 0
        let satFat = n?.saturatedFatServing ?? n?.saturatedFat100g ?? 0
        let sug = n?.sugarsServing ?? n?.sugars100g ?? 0

        let serving = offProduct.servingSize ?? "1 serving"

        return FoodResult(
            id: "off-\(barcode)",
            name: offProduct.productName ?? "Unknown",
            brand: offProduct.brands ?? "",
            barcode: barcode,
            calories: cal,
            protein: pro,
            carbs: carb,
            fat: f,
            fiber: fib,
            saturatedFat: satFat,
            sugar: sug,
            servingSize: serving,
            source: .openFoodFacts
        )
    }
}
