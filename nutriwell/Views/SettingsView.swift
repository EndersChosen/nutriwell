import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var dailyPoints: String = ""
    @State private var userName: String = ""
    @State private var showRMRCalculator = false

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Your name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: userName) { _, newValue in
                                updateProfile { $0.name = newValue }
                            }
                    }
                }

                Section("Daily Points Budget") {
                    if profile?.useGoalBasedPoints == true {
                        HStack {
                            Text("Points per day")
                            Spacer()
                            Text("\(profile?.dailyPointsBudget ?? 40)")
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Image(systemName: "target")
                                .foregroundStyle(.green)
                            Text("Auto-managed by your weight goal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Points per day")
                            Spacer()
                            TextField("40", text: $dailyPoints)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .onChange(of: dailyPoints) { _, newValue in
                                    if let points = Int(newValue), points > 0, points <= 200 {
                                        updateProfile { $0.dailyPointsBudget = points }
                                    }
                                }
                        }
                    }
                }
                Section {
                    Text("Points are calculated based on calories, saturated fat, sugar, and protein — similar to popular points-based diet systems.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Metabolism (RMR)") {
                    if let rmr = profile?.rmr {
                        HStack {
                            Text("Resting Metabolic Rate")
                            Spacer()
                            Text("\(rmr) cal/day")
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                        }
                        if let sex = profile?.sex, let age = profile?.age,
                           let feet = profile?.heightFeet, let inches = profile?.heightInches {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 12) {
                                    Label(sex.capitalized, systemImage: "person.fill")
                                    Label("\(age) yrs", systemImage: "calendar")
                                    Label("\(feet)' \(inches)\"", systemImage: "ruler")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            showRMRCalculator = true
                        } label: {
                            Label("Recalculate RMR", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) {
                            clearRMR()
                        } label: {
                            Label("Remove RMR", systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            showRMRCalculator = true
                        } label: {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading) {
                                    Text("Set Your RMR")
                                        .font(.subheadline.bold())
                                    Text("Enter directly or calculate from your stats")
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
                    Text("Your Resting Metabolic Rate is used for more accurate daily points calculation when you set a weight goal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Food Data") {
                    HStack {
                        Text("Source")
                        Spacer()
                        Text("USDA FoodData Central")
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://fdc.nal.usda.gov")!) {
                        HStack {
                            Text("Learn more")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if let profile {
                    dailyPoints = "\(profile.dailyPointsBudget)"
                    userName = profile.name
                }
            }
            .sheet(isPresented: $showRMRCalculator) {
                RMRCalculatorView()
            }
        }
    }

    private func updateProfile(_ update: (UserProfile) -> Void) {
        if let profile {
            update(profile)
        }
    }

    private func clearRMR() {
        guard let profile else { return }
        profile.rmr = nil
        profile.heightFeet = nil
        profile.heightInches = nil
        profile.age = nil
        profile.sex = nil
    }
}
