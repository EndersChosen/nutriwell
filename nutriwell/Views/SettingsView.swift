import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var dailyPoints: String = ""
    @State private var userName: String = ""

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
                Section {
                    Text("Points are calculated based on calories, saturated fat, sugar, protein, and fiber — similar to popular points-based diet systems.")
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
                } else {
                    // Create default profile
                    let newProfile = UserProfile()
                    modelContext.insert(newProfile)
                    dailyPoints = "\(newProfile.dailyPointsBudget)"
                }
            }
        }
    }

    private func updateProfile(_ update: (UserProfile) -> Void) {
        if let profile {
            update(profile)
        }
    }
}
