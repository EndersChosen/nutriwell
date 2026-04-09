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

    var body: some View {
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FoodEntry.self, WeightEntry.self, UserProfile.self], inMemory: true)
}
