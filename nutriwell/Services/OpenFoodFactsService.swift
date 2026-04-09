import Foundation

// MARK: - Open Food Facts API Models

struct OFFProduct: Codable {
    let code: String?
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
    let servingSize: String?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case imageUrl = "image_url"
    }
}

struct OFFNutriments: Codable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let saturatedFat100g: Double?
    let sugars100g: Double?

    // Per-serving values
    let energyKcalServing: Double?
    let proteinsServing: Double?
    let carbohydratesServing: Double?
    let fatServing: Double?
    let fiberServing: Double?
    let saturatedFatServing: Double?
    let sugarsServing: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case sugars100g = "sugars_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteinsServing = "proteins_serving"
        case carbohydratesServing = "carbohydrates_serving"
        case fatServing = "fat_serving"
        case fiberServing = "fiber_serving"
        case saturatedFatServing = "saturated-fat_serving"
        case sugarsServing = "sugars_serving"
    }
}

struct OFFBarcodeResponse: Codable {
    let status: Int
    let product: OFFProduct?
}

struct OFFSearchResponse: Codable {
    let products: [OFFProduct]
    let count: Int
}

// MARK: - Service

final class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    private let baseURL = "https://world.openfoodfacts.org"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    /// Look up a product by barcode
    func fetchByBarcode(_ barcode: String) async throws -> FoodResult? {
        guard !barcode.isEmpty else { return nil }

        guard let url = URL(string: "\(baseURL)/api/v0/product/\(barcode).json") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("NutriWell iOS App", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        let result = try JSONDecoder().decode(OFFBarcodeResponse.self, from: data)

        guard result.status == 1, let product = result.product,
              let name = product.productName, !name.isEmpty else {
            return nil
        }

        return FoodResult.from(offProduct: product, barcode: barcode)
    }

    /// Search for products by name
    func searchFoods(query: String, pageSize: Int = 25) async throws -> [FoodResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var components = URLComponents(string: "\(baseURL)/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("NutriWell iOS App", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        let result = try JSONDecoder().decode(OFFSearchResponse.self, from: data)

        return result.products.compactMap { product in
            guard let name = product.productName, !name.isEmpty else { return nil }
            return FoodResult.from(offProduct: product, barcode: product.code ?? "")
        }
    }
}
