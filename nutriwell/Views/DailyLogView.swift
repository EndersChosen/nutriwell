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
        healthJokes.randomElement() ?? "Stay healthy!"
    }

    private let healthJokes = [
        "I told my trainer I wanted to touch my toes. She said, \"Which ones?\" \u{1F602}",
        "I don't need a personal trainer… I need someone to follow me around and slap unhealthy food out of my hands. \u{1F354}",
        "My favorite exercise is a cross between a lunge and a crunch. I call it lunch. \u{1F96A}",
        "I went to the gym and asked the trainer, \"Can you teach me to do the splits?\" He said, \"How flexible are you?\" I said, \"I can't make Tuesdays.\" \u{1F3CB}",
        "I don't sweat — I sparkle. \u{2728}",
        "Running late counts as cardio, right? \u{1F3C3}",
        "They say laughter is the best medicine. So technically, this app is a health product. \u{1F48A}",
        "I do 5 sit-ups every morning. It might not sound like much, but there are only so many times you can hit the snooze button. \u{23F0}",
        "Ate a salad today. It was on a pizza, but still. \u{1F355}",
        "My doctor told me to watch my calories. So now I eat in front of the TV. \u{1F4FA}",
        "I've been on a diet for two weeks and all I've lost is 14 days. \u{1F4C5}",
        "Does refusing to take the elevator count as a workout? \u{1FA9C}",
        "The only marathon I'm running is a Netflix marathon. \u{1F3AC}",
        "I tried yoga once. The instructor said \"Namaste\" and I said \"Nah, Imma leave.\" \u{1F9D8}",
        "My gym routine: 1% working out, 99% wondering why I'm there. \u{1F914}",
        "I recently started jogging. The ice cream truck was pulling away. \u{1F366}",
        "An apple a day keeps anyone away if you throw it hard enough. \u{1F34E}",
        "My six-pack is protected by a layer of fat. Safety first. \u{1F6E1}",
        "I walk because punching people is frowned upon. \u{1F6B6}",
        "Water is the healthiest drink. It goes with pizza, burgers, and cake. \u{1F4A7}",
    ]

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
