import SwiftUI
import SwiftData

struct FoodSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mealType: MealType
    let date: Date

    @State private var searchText = ""
    @State private var searchResults: [USDAFood] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showScanner = false
    @State private var scannedBarcode: String?

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
                            addFoodEntry(food)
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
                let results = try await USDAFoodService.shared.searchFoods(query: searchText)
                await MainActor.run {
                    searchResults = results
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

    private func performBarcodeSearch(_ barcode: String) {
        isSearching = true
        errorMessage = nil

        Task {
            do {
                let results = try await USDAFoodService.shared.searchByBarcode(barcode)
                await MainActor.run {
                    searchResults = results
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

    private func addFoodEntry(_ food: USDAFood) {
        let entry = FoodEntry(
            name: food.description,
            brand: food.displayBrand,
            barcode: food.gtinUpc,
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            fiber: food.fiber,
            saturatedFat: food.saturatedFat,
            sugar: food.sugar,
            points: food.points,
            servingSize: food.servingDescription,
            mealType: mealType,
            date: date,
            fdcId: "\(food.fdcId)"
        )
        modelContext.insert(entry)
        dismiss()
    }
}

struct FoodResultRow: View {
    let food: USDAFood
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.description.capitalized)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if !food.displayBrand.isEmpty {
                        Text(food.displayBrand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Label("\(Int(food.calories)) cal", systemImage: "flame.fill")
                        Label(food.servingDescription, systemImage: "scalemass")
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
