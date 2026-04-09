import SwiftUI
import SwiftData

struct FoodReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let food: FoodResult
    let mealType: MealType
    let date: Date
    var onAdded: () -> Void

    // Editable fields
    @State private var servingSizeText: String
    @State private var numberOfServings: Double
    @State private var servingsText: String

    // Base per-serving nutrition (from the scanned data)
    private let baseCalories: Double
    private let baseFat: Double
    private let baseSaturatedFat: Double
    private let baseProtein: Double
    private let baseCarbs: Double
    private let baseSugar: Double
    private let baseFiber: Double

    init(food: FoodResult, mealType: MealType, date: Date, onAdded: @escaping () -> Void) {
        self.food = food
        self.mealType = mealType
        self.date = date
        self.onAdded = onAdded

        _servingSizeText = State(initialValue: food.servingSize)
        _numberOfServings = State(initialValue: 1.0)
        _servingsText = State(initialValue: "1")

        self.baseCalories = food.calories
        self.baseFat = food.fat
        self.baseSaturatedFat = food.saturatedFat
        self.baseProtein = food.protein
        self.baseCarbs = food.carbs
        self.baseSugar = food.sugar
        self.baseFiber = food.fiber
    }

    // Scaled nutrition values
    private var scaledCalories: Double { baseCalories * numberOfServings }
    private var scaledFat: Double { baseFat * numberOfServings }
    private var scaledSaturatedFat: Double { baseSaturatedFat * numberOfServings }
    private var scaledProtein: Double { baseProtein * numberOfServings }
    private var scaledCarbs: Double { baseCarbs * numberOfServings }
    private var scaledSugar: Double { baseSugar * numberOfServings }
    private var scaledFiber: Double { baseFiber * numberOfServings }

    private var scaledPoints: Int {
        PointsCalculator.calculate(
            calories: scaledCalories,
            saturatedFat: scaledSaturatedFat,
            sugar: scaledSugar,
            protein: scaledProtein,
            fiber: scaledFiber
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Food header
                    VStack(spacing: 6) {
                        Text(food.name.capitalized)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                        if !food.brand.isEmpty {
                            Text(food.brand)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(food.source.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 8)

                    // Points badge
                    VStack(spacing: 2) {
                        Text("\(scaledPoints)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.green)
                        Text("SmartPoints")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Serving controls
                    VStack(spacing: 16) {
                        Text("Serving")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            HStack {
                                Text("Serving Size")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("e.g. 1 cup", text: $servingSizeText)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 160)
                            }

                            HStack {
                                Text("Number of Servings")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("1", text: $servingsText)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)
                                    .frame(maxWidth: 80)
                                    .onChange(of: servingsText) { _, newValue in
                                        parseServings(newValue)
                                    }
                            }

                            // Quick serving buttons
                            HStack(spacing: 8) {
                                ForEach(quickServings, id: \.label) { option in
                                    Button {
                                        numberOfServings = option.value
                                        servingsText = option.label
                                    } label: {
                                        Text(option.label)
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                numberOfServings == option.value
                                                    ? Color.green
                                                    : Color(.systemGray5)
                                            )
                                            .foregroundStyle(
                                                numberOfServings == option.value
                                                    ? .white
                                                    : .primary
                                            )
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Nutrition facts
                    VStack(spacing: 12) {
                        Text("Nutrition Facts")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if numberOfServings != 1.0 {
                            Text("Values shown for \(formattedServings) serving\(numberOfServings == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(spacing: 0) {
                            NutritionRow(label: "Calories", value: formatNutrition(scaledCalories), unit: "kcal", bold: true)
                            Divider()
                            NutritionRow(label: "Total Fat", value: formatNutrition(scaledFat), unit: "g")
                            Divider()
                            NutritionRow(label: "  Saturated Fat", value: formatNutrition(scaledSaturatedFat), unit: "g", indented: true)
                            Divider()
                            NutritionRow(label: "Protein", value: formatNutrition(scaledProtein), unit: "g")
                            Divider()
                            NutritionRow(label: "Total Carbs", value: formatNutrition(scaledCarbs), unit: "g")
                            Divider()
                            NutritionRow(label: "  Sugar", value: formatNutrition(scaledSugar), unit: "g", indented: true)
                            Divider()
                            NutritionRow(label: "Fiber", value: formatNutrition(scaledFiber), unit: "g")
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Per-serving reference (when servings != 1)
                    if numberOfServings != 1.0 {
                        VStack(spacing: 8) {
                            Text("Per Serving (\(servingSizeText))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 16) {
                                MiniNutrientPill(label: "Cal", value: formatNutrition(baseCalories))
                                MiniNutrientPill(label: "Fat", value: formatNutrition(baseFat))
                                MiniNutrientPill(label: "Protein", value: formatNutrition(baseProtein))
                                MiniNutrientPill(label: "Carbs", value: formatNutrition(baseCarbs))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
            .navigationTitle("Review Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    addFood()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to \(mealType.rawValue)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Helpers

    private var quickServings: [(label: String, value: Double)] {
        [("½", 0.5), ("1", 1.0), ("1½", 1.5), ("2", 2.0), ("3", 3.0)]
    }

    private var formattedServings: String {
        if numberOfServings == numberOfServings.rounded() {
            return String(format: "%.0f", numberOfServings)
        }
        return String(format: "%.1f", numberOfServings)
    }

    private func formatNutrition(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func parseServings(_ text: String) {
        // Handle fraction inputs like "1/2"
        if text.contains("/") {
            let parts = text.split(separator: "/")
            if parts.count == 2,
               let num = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let den = Double(parts[1].trimmingCharacters(in: .whitespaces)),
               den != 0 {
                numberOfServings = max(0.01, num / den)
                return
            }
        }
        if let val = Double(text), val > 0 {
            numberOfServings = val
        } else if text.isEmpty {
            numberOfServings = 1.0
        }
    }

    private func addFood() {
        let entry = FoodEntry(
            name: food.name,
            brand: food.brand,
            barcode: food.barcode,
            calories: scaledCalories,
            protein: scaledProtein,
            carbs: scaledCarbs,
            fat: scaledFat,
            fiber: scaledFiber,
            saturatedFat: scaledSaturatedFat,
            sugar: scaledSugar,
            points: scaledPoints,
            servingSize: servingSizeText,
            numberOfServings: numberOfServings,
            mealType: mealType,
            date: date,
            fdcId: food.id
        )
        modelContext.insert(entry)
        onAdded()
    }
}

// MARK: - Subviews

private struct NutritionRow: View {
    let label: String
    let value: String
    let unit: String
    var bold: Bool = false
    var indented: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(indented ? .secondary : .primary)
            Spacer()
            Text("\(value) \(unit)")
                .font(bold ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct MiniNutrientPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
    }
}
