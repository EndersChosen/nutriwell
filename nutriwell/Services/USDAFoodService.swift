import Foundation

// MARK: - USDA FoodData Central API Models

struct USDASearchResponse: Codable {
    let foods: [USDAFood]
    let totalHits: Int
}

struct USDAFood: Codable, Identifiable {
    let fdcId: Int
    let description: String
    let brandName: String?
    let brandOwner: String?
    let gtinUpc: String?
    let foodNutrients: [USDANutrient]
    let servingSize: Double?
    let servingSizeUnit: String?

    var id: Int { fdcId }

    var displayBrand: String {
        brandName ?? brandOwner ?? ""
    }

    var calories: Double { nutrientValue(for: 1008) }
    var protein: Double { nutrientValue(for: 1003) }
    var carbs: Double { nutrientValue(for: 1005) }
    var fat: Double { nutrientValue(for: 1004) }
    var fiber: Double { nutrientValue(for: 1079) }
    var saturatedFat: Double { nutrientValue(for: 1258) }
    var sugar: Double { nutrientValue(for: 2000) }

    var servingDescription: String {
        if let size = servingSize, let unit = servingSizeUnit {
            return "\(Int(size)) \(unit)"
        }
        return "1 serving"
    }

    var points: Int {
        PointsCalculator.calculate(
            calories: calories,
            saturatedFat: saturatedFat,
            sugar: sugar,
            protein: protein,
            fiber: fiber
        )
    }

    private func nutrientValue(for nutrientId: Int) -> Double {
        foodNutrients.first { $0.nutrientId == nutrientId }?.value ?? 0
    }
}

struct USDANutrient: Codable {
    let nutrientId: Int
    let nutrientName: String
    let value: Double
    let unitName: String
}

// MARK: - API Service

final class USDAFoodService {
    static let shared = USDAFoodService()

    // Free USDA API key — users should register at https://fdc.nal.usda.gov/api-key-signup
    // and replace this with their own key.
    private let apiKey = "DEMO_KEY"
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    /// Search foods by text query
    func searchFoods(query: String, pageSize: Int = 25) async throws -> [USDAFood] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var components = URLComponents(string: "\(baseURL)/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "\(pageSize)"),
            URLQueryItem(name: "dataType", value: "Branded,Survey (FNDDS)")
        ]

        guard let url = components.url else {
            throw USDAError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDAError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw USDAError.httpError(httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        return result.foods
    }

    /// Look up a food item by barcode (GTIN/UPC)
    func searchByBarcode(_ barcode: String) async throws -> [USDAFood] {
        guard !barcode.isEmpty else { return [] }

        var components = URLComponents(string: "\(baseURL)/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: barcode),
            URLQueryItem(name: "pageSize", value: "5"),
            URLQueryItem(name: "dataType", value: "Branded")
        ]

        guard let url = components.url else {
            throw USDAError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDAError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw USDAError.httpError(httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        // Filter to exact barcode matches when possible
        let exactMatches = result.foods.filter { $0.gtinUpc == barcode }
        return exactMatches.isEmpty ? result.foods : exactMatches
    }
}

enum USDAError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "Server error (HTTP \(code))"
        }
    }
}
