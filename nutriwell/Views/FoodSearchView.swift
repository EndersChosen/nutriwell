import SwiftUI
import SwiftData

struct FoodSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mealType: MealType
    let date: Date

    @State private var searchText = ""
    @State private var searchResults: [FoodResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showScanner = false
    @State private var scannedBarcode: String?
    @State private var selectedFood: FoodResult?
    @State private var showReview = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search foods...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit { performSearch() }
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title2)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)

                if isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No results found")
                            .foregroundStyle(.secondary)
                        if scannedBarcode != nil {
                            Text("Barcode: \(searchText)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                            Text("This item wasn't found in any database.\nTry searching by product name instead.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Search for a food or scan a barcode")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List(searchResults) { food in
                        FoodResultRow(food: food) {
                            selectedFood = food
                            showReview = true
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add to \(mealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView(scannedCode: $scannedBarcode)
            }
            .sheet(isPresented: $showReview) {
                if let food = selectedFood {
                    FoodReviewView(food: food, mealType: mealType, date: date) {
                        dismiss()
                    }
                }
            }
            .onChange(of: scannedBarcode) { _, newValue in
                if let barcode = newValue {
                    searchText = barcode
                    performBarcodeSearch(barcode)
                }
            }
        }
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        errorMessage = nil

        Task {
            do {
                // Search both sources in parallel
                async let offResults = OpenFoodFactsService.shared.searchFoods(query: searchText, pageSize: 15)
                async let usdaResults = USDAFoodService.shared.searchFoods(query: searchText, pageSize: 15)

                let off = (try? await offResults) ?? []
                let usda = (try? await usdaResults).map { $0.map(FoodResult.from(usdaFood:)) } ?? []

                await MainActor.run {
                    // OFF results first, then USDA
                    searchResults = off + usda
                    isSearching = false
                }
            }
        }
    }

    private func performBarcodeSearch(_ barcode: String) {
        isSearching = true
        errorMessage = nil

        Task {
            // Try Open Food Facts first (best barcode coverage)
            if let offResult = try? await OpenFoodFactsService.shared.fetchByBarcode(barcode) {
                await MainActor.run {
                    searchResults = [offResult]
                    isSearching = false
                }
                return
            }

            // Fall back to USDA
            do {
                let usdaResults = try await USDAFoodService.shared.searchByBarcode(barcode)
                await MainActor.run {
                    searchResults = usdaResults.map(FoodResult.from(usdaFood:))
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }


}

struct FoodResultRow: View {
    let food: FoodResult
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name.capitalized)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if !food.brand.isEmpty {
                        Text(food.brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Label("\(Int(food.calories)) cal", systemImage: "flame.fill")
                        Label(food.servingSize, systemImage: "scalemass")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack {
                    Text("\(food.points)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.green)
                    Text("pts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
