import SwiftUI
import SwiftData

struct WeightTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query private var profiles: [UserProfile]

    @State private var newWeight = ""
    @State private var showGoalSetup = false
    @FocusState private var isWeightFieldFocused: Bool

    private var profile: UserProfile? { profiles.first }

    private var latestWeight: Double? {
        weightEntries.first?.weight
    }

    private var weightChange: Double? {
        guard weightEntries.count >= 2 else { return nil }
        return weightEntries[0].weight - weightEntries[1].weight
    }

    private var hasActiveGoal: Bool {
        profile?.useGoalBasedPoints == true && profile?.goalWeight != nil
    }

    var body: some View {
        NavigationStack {
            List {
                // Current weight card
                Section {
                    VStack(spacing: 8) {
                        if let latest = latestWeight {
                            Text("\(latest, specifier: "%.1f")")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                            Text("lbs")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let change = weightChange {
                                HStack(spacing: 4) {
                                    Image(systemName: change > 0 ? "arrow.up.right" : change < 0 ? "arrow.down.right" : "arrow.right")
                                    Text("\(abs(change), specifier: "%.1f") lbs")
                                }
                                .font(.caption)
                                .foregroundStyle(change > 0 ? .red : change < 0 ? .green : .secondary)
                            }
                        } else {
                            Text("No weight logged")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                // Weight goal card
                if let profile, hasActiveGoal,
                   let goalWeight = profile.goalWeight,
                   let startWeight = profile.startingWeight,
                   let goalStart = profile.goalStartDate,
                   let totalWeeks = profile.goalWeeks {
                    Section("Weight Goal") {
                        let weeksLeft = GoalCalculator.weeksRemaining(startDate: goalStart, totalWeeks: totalWeeks)
                        let currentW = latestWeight ?? startWeight
                        let totalToLose = startWeight - goalWeight
                        let lostSoFar = startWeight - currentW
                        let progress = totalToLose > 0 ? min(max(lostSoFar / totalToLose, 0), 1.0) : 0

                        VStack(spacing: 12) {
                            // Progress bar
                            VStack(spacing: 4) {
                                HStack {
                                    Text(String(format: "%.0f lbs", startWeight))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(String(format: "%.0f lbs", goalWeight))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.green.opacity(0.2))
                                            .frame(height: 8)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.green)
                                            .frame(width: geo.size.width * progress, height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }

                            HStack(spacing: 16) {
                                GoalStat(title: "Lost", value: String(format: "%.1f lbs", max(0, lostSoFar)), color: .green)
                                GoalStat(title: "Remaining", value: String(format: "%.1f lbs", max(0, currentW - goalWeight)), color: .orange)
                                GoalStat(title: "Weeks Left", value: "\(weeksLeft)", color: .blue)
                            }

                            HStack {
                                Image(systemName: "fork.knife.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(profile.dailyPointsBudget) pts/day")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("Auto-adjusting")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            showGoalSetup = true
                        } label: {
                            Label("Edit Goal", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            clearGoal()
                        } label: {
                            Label("Remove Goal", systemImage: "xmark.circle")
                        }
                    }
                } else {
                    Section {
                        Button {
                            showGoalSetup = true
                        } label: {
                            HStack {
                                Image(systemName: "target")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                                VStack(alignment: .leading) {
                                    Text("Set a Weight Goal")
                                        .font(.subheadline.bold())
                                    Text("Get a personalized daily points budget")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Add weight
                Section("Log Weight") {
                    HStack {
                        TextField("Weight (lbs)", text: $newWeight)
                            .keyboardType(.decimalPad)
                            .focused($isWeightFieldFocused)
                        Button("Add") {
                            addWeight()
                        }
                        .disabled(newWeight.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }

                // Weight history
                if !weightEntries.isEmpty {
                    Section("History") {
                        ForEach(weightEntries) { entry in
                            HStack {
                                Text(entry.date, format: .dateTime.month().day().year())
                                    .font(.subheadline)
                                Spacer()
                                Text("\(entry.weight, specifier: "%.1f") lbs")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .navigationTitle("Weight")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isWeightFieldFocused = false
                    }
                }
            }
            .sheet(isPresented: $showGoalSetup) {
                WeightGoalView()
            }
        }
    }

    private func addWeight() {
        guard let weight = Double(newWeight), weight > 0, weight < 1000 else { return }
        let entry = WeightEntry(weight: weight)
        modelContext.insert(entry)
        newWeight = ""
        isWeightFieldFocused = false

        // Recalculate points if goal is active
        recalculateIfNeeded(newWeight: weight)
    }

    private func recalculateIfNeeded(newWeight: Double) {
        guard let profile, profile.useGoalBasedPoints,
              let goalWeight = profile.goalWeight,
              let goalStart = profile.goalStartDate,
              let totalWeeks = profile.goalWeeks else { return }

        // Check if at least a week has passed since last recalc
        let calendar = Calendar.current
        if let lastRecalc = profile.lastRecalcDate,
           let daysSinceRecalc = calendar.dateComponents([.day], from: lastRecalc, to: Date()).day,
           daysSinceRecalc < 7 {
            return
        }

        // Already at or below goal
        if newWeight <= goalWeight {
            profile.useGoalBasedPoints = false
            if let rmr = profile.rmr {
                profile.dailyPointsBudget = GoalCalculator.baselinePoints(forRMR: rmr)
            } else {
                profile.dailyPointsBudget = GoalCalculator.baselinePoints(for: newWeight)
            }
            return
        }

        let weeksLeft = GoalCalculator.weeksRemaining(startDate: goalStart, totalWeeks: totalWeeks)
        if let rmr = profile.rmr {
            profile.dailyPointsBudget = GoalCalculator.calculateDailyPoints(
                currentWeight: newWeight, goalWeight: goalWeight, weeksRemaining: weeksLeft, rmr: rmr
            )
        } else {
            profile.dailyPointsBudget = GoalCalculator.calculateDailyPoints(
                currentWeight: newWeight, goalWeight: goalWeight, weeksRemaining: weeksLeft
            )
        }
        profile.lastRecalcDate = Date()
    }

    private func clearGoal() {
        guard let profile else { return }
        profile.useGoalBasedPoints = false
        profile.startingWeight = nil
        profile.goalWeight = nil
        profile.goalWeeks = nil
        profile.goalStartDate = nil
        profile.lastRecalcDate = nil
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(weightEntries[index])
        }
    }
}

private struct GoalStat: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
