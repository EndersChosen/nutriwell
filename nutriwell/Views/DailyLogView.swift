import SwiftUI
import SwiftData

struct DailyLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]

    @State private var selectedDate = Date()
    @State private var showAddFood = false
    @State private var selectedMealType: MealType = .breakfast

    private var dailyBudget: Int {
        profiles.first?.dailyPointsBudget ?? 40
    }

    private var todayEntries: [FoodEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var consumedPoints: Int {
        todayEntries.reduce(0) { $0 + $1.points }
    }

    private var remainingPoints: Int {
        dailyBudget - consumedPoints
    }

    private func entries(for mealType: MealType) -> [FoodEntry] {
        todayEntries.filter { $0.mealType == mealType }
    }

    private func mealPoints(for mealType: MealType) -> Int {
        entries(for: mealType).reduce(0) { $0 + $1.points }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date selector
                    DateSelector(selectedDate: $selectedDate)

                    // Points summary card
                    PointsSummaryCard(
                        budget: dailyBudget,
                        consumed: consumedPoints,
                        remaining: remainingPoints
                    )
                    .padding(.horizontal)

                    // Meal sections
                    ForEach(MealType.allCases) { meal in
                        MealSectionView(
                            mealType: meal,
                            entries: entries(for: meal),
                            totalPoints: mealPoints(for: meal),
                            onAdd: {
                                selectedMealType = meal
                                showAddFood = true
                            },
                            onDelete: { entry in
                                modelContext.delete(entry)
                            }
                        )
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("NutriWell")
            .sheet(isPresented: $showAddFood) {
                FoodSearchView(mealType: selectedMealType, date: selectedDate)
            }
        }
    }
}

// MARK: - Date Selector

struct DateSelector: View {
    @Binding var selectedDate: Date

    var body: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }

            Spacer()

            VStack {
                if Calendar.current.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.headline)
                } else if Calendar.current.isDateInYesterday(selectedDate) {
                    Text("Yesterday")
                        .font(.headline)
                } else {
                    Text(selectedDate, format: .dateTime.weekday(.wide))
                        .font(.headline)
                }
                Text(selectedDate, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

// MARK: - Points Summary Card

struct PointsSummaryCard: View {
    let budget: Int
    let consumed: Int
    let remaining: Int

    private var progress: Double {
        guard budget > 0 else { return 0 }
        return min(Double(consumed) / Double(budget), 1.0)
    }

    private var ringColor: Color {
        if remaining < 0 { return .red }
        if remaining < budget / 4 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 30) {
                // Ring
                ZStack {
                    Circle()
                        .stroke(ringColor.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progress)
                    VStack(spacing: 2) {
                        Text("\(remaining)")
                            .font(.title.weight(.bold))
                            .foregroundStyle(ringColor)
                        Text("left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)

                // Stats
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(.blue)
                        Text("Budget")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(budget)")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)

                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("Consumed")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(consumed)")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ringColor)
                        Text("Remaining")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(remaining)")
                            .fontWeight(.semibold)
                            .foregroundStyle(ringColor)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Meal Section

struct MealSectionView: View {
    let mealType: MealType
    let entries: [FoodEntry]
    let totalPoints: Int
    let onAdd: () -> Void
    let onDelete: (FoodEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: mealType.icon)
                    .foregroundStyle(.green)
                Text(mealType.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(totalPoints) pts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal)

            if entries.isEmpty {
                Text("No items logged")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
            } else {
                ForEach(entries) { entry in
                    FoodEntryRow(entry: entry) {
                        onDelete(entry)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name.capitalized)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !entry.brand.isEmpty {
                        Text(entry.brand)
                    }
                    Text("\(Int(entry.calories)) cal")
                    Text(entry.servingSize)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.points) pts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
