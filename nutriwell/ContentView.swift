//
//  ContentView.swift
//  nutriwell
//
//  Created by Caleb Kruger on 4/9/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @Query private var allFoodEntries: [FoodEntry]
    @State private var healthService = HealthKitService.shared

    private var todayEntries: [FoodEntry] {
        allFoodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                DailyLogView()
                    .tabItem {
                        Label("Today", systemImage: "fork.knife")
                    }
                    .tag(0)

                ActivityView()
                    .tabItem {
                        Label("Activity", systemImage: "heart.fill")
                    }
                    .tag(1)

                WeightTrackingView()
                    .tabItem {
                        Label("Weight", systemImage: "scalemass")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(3)
            }
            .tint(.green)

            DailyTotalsBar(
                entries: todayEntries,
                exerciseMinutes: healthService.exerciseMinutes
            )
        }
    }
}

// MARK: - Daily Totals Bar

struct DailyTotalsBar: View {
    let entries: [FoodEntry]
    let exerciseMinutes: Int

    private var totalCalories: Int { Int(entries.reduce(0) { $0 + $1.calories }) }
    private var totalFat: Int { Int(entries.reduce(0) { $0 + $1.fat }) }
    private var totalProtein: Int { Int(entries.reduce(0) { $0 + $1.protein }) }
    private var totalCarbs: Int { Int(entries.reduce(0) { $0 + $1.carbs }) }
    private var totalSugar: Int { Int(entries.reduce(0) { $0 + $1.sugar }) }
    private var totalFiber: Int { Int(entries.reduce(0) { $0 + $1.fiber }) }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    TotalPill(label: "Cal", value: "\(totalCalories)", color: .orange)
                    TotalPill(label: "Fat", value: "\(totalFat)g", color: .yellow)
                    TotalPill(label: "Protein", value: "\(totalProtein)g", color: .blue)
                    TotalPill(label: "Carbs", value: "\(totalCarbs)g", color: .purple)
                    TotalPill(label: "Sugar", value: "\(totalSugar)g", color: .pink)
                    TotalPill(label: "Fiber", value: "\(totalFiber)g", color: .brown)
                    TotalPill(label: "Active", value: "\(exerciseMinutes)m", color: .green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
        }
    }
}

private struct TotalPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 44)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FoodEntry.self, WeightEntry.self, UserProfile.self], inMemory: true)
}
