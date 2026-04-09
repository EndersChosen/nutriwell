import SwiftUI
import SwiftData

struct DailyLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @State private var healthService = HealthKitService.shared

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
                    // Daily summary header
                    DailySummaryHeader(
                        userName: profiles.first?.name ?? "",
                        remainingPoints: remainingPoints,
                        budget: dailyBudget,
                        steps: healthService.stepCount,
                        activeCalories: healthService.activeCalories,
                        exerciseMinutes: healthService.exerciseMinutes
                    )
                    .padding(.horizontal)

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
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if healthService.isAuthorized {
                    await healthService.refreshAllData()
                }
            }
            .sheet(isPresented: $showAddFood) {
                FoodSearchView(mealType: selectedMealType, date: selectedDate)
            }
        }
    }
}

// MARK: - Daily Summary Header

struct DailySummaryHeader: View {
    let userName: String
    let remainingPoints: Int
    let budget: Int
    let steps: Int
    let activeCalories: Int
    let exerciseMinutes: Int

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var displayName: String {
        if userName.isEmpty { return "" }
        return ", \(userName)"
    }

    private var motivationalMessage: String {
        if remainingPoints <= 0 {
            return "You've used all your points today!"
        } else if remainingPoints < budget / 4 {
            return "Almost at your limit \u{2014} choose wisely!"
        } else if steps >= 10000 {
            return "Amazing step count! Keep it up! \u{1F525}"
        } else if activeCalories >= 300 {
            return "Great calorie burn today! \u{1F4AA}"
        } else if exerciseMinutes >= 30 {
            return "Solid workout today! \u{1F3C6}"
        } else {
            return "Let's make it a great day!"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(greeting)\(displayName)")
                .font(.title2.bold())

            Text(motivationalMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if steps > 0 || activeCalories > 0 || exerciseMinutes > 0 {
                HStack(spacing: 16) {
                    ActivityPill(icon: "figure.walk", value: steps.formatted(), label: "steps")
                    ActivityPill(icon: "flame.fill", value: activeCalories.formatted(), label: "cal")
                    ActivityPill(icon: "timer", value: "\(exerciseMinutes)", label: "min")
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ActivityPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
