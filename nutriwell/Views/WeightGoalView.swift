import SwiftUI
import SwiftData

struct WeightGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]

    @State private var currentWeight = ""
    @State private var goalWeight = ""
    @State private var goalWeeks = ""
    @FocusState private var focusedField: Field?

    private enum Field { case current, goal, weeks }

    private var profile: UserProfile? { profiles.first }

    private var currentWeightValue: Double? { Double(currentWeight) }
    private var goalWeightValue: Double? { Double(goalWeight) }
    private var goalWeeksValue: Int? { Int(goalWeeks) }

    private var isValid: Bool {
        guard let cw = currentWeightValue, let gw = goalWeightValue, let weeks = goalWeeksValue else { return false }
        return cw > 0 && gw > 0 && gw < cw && weeks > 0 && weeks <= 104
    }

    private var previewPoints: Int? {
        guard let cw = currentWeightValue, let gw = goalWeightValue, let weeks = goalWeeksValue,
              isValid else { return nil }
        return GoalCalculator.calculateDailyPoints(currentWeight: cw, goalWeight: gw, weeksRemaining: weeks)
    }

    private var weeklyLossRate: Double? {
        guard let cw = currentWeightValue, let gw = goalWeightValue, let weeks = goalWeeksValue,
              isValid else { return nil }
        return GoalCalculator.weeklyLossRate(currentWeight: cw, goalWeight: gw, weeksRemaining: weeks)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        Text("Set Your Weight Goal")
                            .font(.title3.bold())
                        Text("We'll calculate a daily points budget to help you reach your target weight at a healthy pace.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Your Details") {
                    HStack {
                        Text("Current Weight")
                        Spacer()
                        TextField("e.g. 240", text: $currentWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .current)
                        Text("lbs")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Goal Weight")
                        Spacer()
                        TextField("e.g. 200", text: $goalWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .goal)
                        Text("lbs")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Timeframe")
                        Spacer()
                        TextField("e.g. 26", text: $goalWeeks)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .focused($focusedField, equals: .weeks)
                        Text("weeks")
                            .foregroundStyle(.secondary)
                    }
                }

                if let points = previewPoints, let rate = weeklyLossRate {
                    Section("Your Plan") {
                        HStack {
                            Image(systemName: "fork.knife.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("\(points) points/day")
                                    .font(.headline)
                                Text("Your calculated daily budget")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Image(systemName: "arrow.down.right.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(String(format: "%.1f lbs/week", rate))
                                    .font(.headline)
                                Text("Expected loss rate")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let cw = currentWeightValue, let gw = goalWeightValue {
                            HStack {
                                Image(systemName: "scalemass.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(String(format: "%.0f lbs to lose", cw - gw))
                                        .font(.headline)
                                    Text("Total weight to lose")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if rate > 1.5 {
                            Label("Consider extending your timeline for healthier, more sustainable weight loss.", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    Button {
                        saveGoal()
                    } label: {
                        Text("Set Goal")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!isValid)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Weight Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear {
                // Pre-fill current weight from latest entry
                if let latest = weightEntries.first {
                    currentWeight = String(format: "%.0f", latest.weight)
                }
                // Pre-fill from existing goal
                if let profile, profile.useGoalBasedPoints {
                    if let sw = profile.startingWeight { currentWeight = String(format: "%.0f", sw) }
                    if let gw = profile.goalWeight { goalWeight = String(format: "%.0f", gw) }
                    if let weeks = profile.goalWeeks { goalWeeks = "\(weeks)" }
                }
            }
        }
    }

    private func saveGoal() {
        guard let cw = currentWeightValue, let gw = goalWeightValue, let weeks = goalWeeksValue,
              let profile else { return }

        profile.startingWeight = cw
        profile.goalWeight = gw
        profile.goalWeeks = weeks
        profile.goalStartDate = Date()
        profile.lastRecalcDate = Date()
        profile.useGoalBasedPoints = true
        profile.dailyPointsBudget = GoalCalculator.calculateDailyPoints(
            currentWeight: cw, goalWeight: gw, weeksRemaining: weeks
        )

        // Also log the current weight if no entry exists today
        let today = Date()
        let hasEntryToday = weightEntries.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }
        if !hasEntryToday {
            modelContext.insert(WeightEntry(weight: cw))
        }

        dismiss()
    }
}
