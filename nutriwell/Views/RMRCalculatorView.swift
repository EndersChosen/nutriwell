import SwiftUI
import SwiftData

struct RMRCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]

    @State private var mode: RMRMode = .calculate
    @State private var manualRMR = ""
    @State private var sex: Sex = .male
    @State private var weight = ""
    @State private var heightFeet = ""
    @State private var heightInches = ""
    @State private var age = ""
    @FocusState private var focusedField: Field?

    private enum RMRMode: String, CaseIterable {
        case calculate = "Calculate"
        case manual = "Enter Manually"
    }

    private enum Sex: String, CaseIterable {
        case male = "Male"
        case female = "Female"
    }

    private enum Field { case weight, feet, inches, age, manual }

    private var profile: UserProfile? { profiles.first }

    private var totalHeightInches: Double? {
        guard let ft = Int(heightFeet), let inch = Int(heightInches),
              ft >= 0, inch >= 0, inch < 12 else { return nil }
        return GoalCalculator.totalInches(feet: ft, inches: inch)
    }

    private var calculatedRMR: Int? {
        guard let w = Double(weight), w > 0,
              let h = totalHeightInches, h > 0,
              let a = Int(age), a > 0 else { return nil }
        return GoalCalculator.calculateRMR(
            weightLbs: w, heightInches: h, age: a, isMale: sex == .male
        )
    }

    private var isValid: Bool {
        switch mode {
        case .calculate: return calculatedRMR != nil
        case .manual:
            guard let rmr = Int(manualRMR) else { return false }
            return rmr >= 500 && rmr <= 5000
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Resting Metabolic Rate")
                            .font(.title3.bold())
                        Text("Your RMR is the number of calories your body burns at rest. This helps us give you a more accurate daily points budget.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Method", selection: $mode) {
                        ForEach(RMRMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                if mode == .calculate {
                    Section("Your Stats") {
                        Picker("Sex", selection: $sex) {
                            ForEach(Sex.allCases, id: \.self) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }

                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("e.g. 180", text: $weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                                .focused($focusedField, equals: .weight)
                            Text("lbs")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Height")
                            Spacer()
                            TextField("ft", text: $heightFeet)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 40)
                                .focused($focusedField, equals: .feet)
                            Text("ft")
                                .foregroundStyle(.secondary)
                            TextField("in", text: $heightInches)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 40)
                                .focused($focusedField, equals: .inches)
                            Text("in")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Age")
                            Spacer()
                            TextField("e.g. 30", text: $age)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .focused($focusedField, equals: .age)
                            Text("yrs")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let rmr = calculatedRMR {
                        Section("Your RMR") {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text("\(rmr) calories/day")
                                        .font(.headline)
                                    Text("Calories your body burns at rest")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    let tdee = Int(Double(rmr) * 1.55)
                                    Text("~\(tdee) calories/day")
                                        .font(.headline)
                                    Text("Estimated total daily expenditure (moderate activity)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Formula used:")
                                    .font(.caption.bold())
                                let offset = sex == .male ? "5" : "161"
                                Text("(4.54 × \(weight) lbs) + (15.88 × \(Int(totalHeightInches ?? 0)) in) − (5 × \(age)) − \(offset)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Section("Enter Your RMR") {
                        HStack {
                            Text("RMR")
                            Spacer()
                            TextField("e.g. 1800", text: $manualRMR)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .focused($focusedField, equals: .manual)
                            Text("cal/day")
                                .foregroundStyle(.secondary)
                        }
                        Text("If you've had your RMR measured (metabolic test, DEXA, etc.), enter it here for the most accurate results.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        saveRMR()
                    } label: {
                        Text("Save RMR")
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
            .navigationTitle("RMR Calculator")
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
                // Pre-fill from latest weight
                if let latest = weightEntries.first {
                    weight = String(format: "%.0f", latest.weight)
                }
                // Pre-fill from saved profile
                if let profile {
                    if let s = profile.sex { sex = s == "male" ? .male : .female }
                    if let a = profile.age { age = "\(a)" }
                    if let ft = profile.heightFeet { heightFeet = "\(ft)" }
                    if let inch = profile.heightInches { heightInches = "\(inch)" }
                    if let rmr = profile.rmr { manualRMR = "\(rmr)" }
                }
            }
        }
    }

    private func saveRMR() {
        guard let profile else { return }

        switch mode {
        case .calculate:
            guard let rmr = calculatedRMR else { return }
            profile.rmr = rmr
            profile.sex = sex == .male ? "male" : "female"
            profile.age = Int(age)
            profile.heightFeet = Int(heightFeet)
            profile.heightInches = Int(heightInches)
        case .manual:
            guard let rmr = Int(manualRMR) else { return }
            profile.rmr = rmr
        }

        // If weight goal is active, recalculate points with new RMR
        if profile.useGoalBasedPoints,
           let goalWeight = profile.goalWeight,
           let goalStart = profile.goalStartDate,
           let totalWeeks = profile.goalWeeks,
           let rmr = profile.rmr {
            let currentWeight = weightEntries.first?.weight ?? profile.startingWeight ?? 0
            let weeksLeft = GoalCalculator.weeksRemaining(startDate: goalStart, totalWeeks: totalWeeks)
            profile.dailyPointsBudget = GoalCalculator.calculateDailyPoints(
                currentWeight: currentWeight, goalWeight: goalWeight,
                weeksRemaining: weeksLeft, rmr: rmr
            )
        }

        dismiss()
    }
}
