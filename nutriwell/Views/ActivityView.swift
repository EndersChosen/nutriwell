import SwiftUI
import HealthKit

struct ActivityView: View {
    @State private var healthService = HealthKitService.shared
    @State private var recentWorkouts: [HKWorkout] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if !healthService.isAvailable {
                    unavailableView
                } else if !healthService.isAuthorized {
                    connectView
                } else {
                    activityContent
                }
            }
            .navigationTitle("Activity")
        }
    }

    // MARK: - Not Available

    private var unavailableView: some View {
        ContentUnavailableView(
            "Health Data Unavailable",
            systemImage: "heart.slash",
            description: Text("HealthKit is not available on this device.")
        )
    }

    // MARK: - Connect Prompt

    private var connectView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Connect Your Health Data")
                .font(.title2.bold())

            Text("Link your Apple Watch, Fitbit, Garmin, or other wearables through Apple Health to track your activity alongside your nutrition.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "figure.walk", text: "Steps & Distance")
                FeatureRow(icon: "flame.fill", text: "Calories Burned")
                FeatureRow(icon: "timer", text: "Exercise Minutes")
                FeatureRow(icon: "heart.fill", text: "Heart Rate")
                FeatureRow(icon: "figure.run", text: "Workouts")
            }
            .padding(.vertical)

            Button {
                Task { await healthService.requestAuthorization() }
            } label: {
                Label("Connect to Apple Health", systemImage: "heart.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Text("Data from Garmin, Fitbit, and other wearables syncs through Apple Health automatically if you have their companion app installed.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Activity Dashboard

    private var activityContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Today's stats grid
                todayStatsSection

                // Weekly steps chart
                weeklySection(title: "Steps This Week", data: healthService.weeklySteps, color: .green)

                // Weekly calories chart
                weeklySection(title: "Calories Burned This Week", data: healthService.weeklyCalories, color: .orange)

                // Recent workouts
                workoutsSection
            }
            .padding()
        }
        .refreshable {
            await refreshData()
        }
        .task {
            await refreshData()
        }
    }

    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    icon: "figure.walk",
                    title: "Steps",
                    value: healthService.stepCount.formatted(),
                    color: .green
                )
                StatCard(
                    icon: "flame.fill",
                    title: "Active Cal",
                    value: healthService.activeCalories.formatted(),
                    color: .orange
                )
                StatCard(
                    icon: "timer",
                    title: "Exercise",
                    value: "\(healthService.exerciseMinutes) min",
                    color: .blue
                )
                StatCard(
                    icon: "figure.walk.motion",
                    title: "Distance",
                    value: String(format: "%.1f mi", healthService.distanceWalking),
                    color: .purple
                )
                if healthService.heartRate > 0 {
                    StatCard(
                        icon: "heart.fill",
                        title: "Heart Rate",
                        value: "\(healthService.heartRate) bpm",
                        color: .red
                    )
                }
            }
        }
    }

    private func weeklySection(title: String, data: [(date: Date, value: Int)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if data.isEmpty {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                WeeklyBarChart(data: data, color: color)
                    .frame(height: 150)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)

            if recentWorkouts.isEmpty {
                Text("No recent workouts")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(recentWorkouts, id: \.uuid) { workout in
                    WorkoutRow(workout: workout)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func refreshData() async {
        isLoading = true
        await healthService.refreshAllData()
        recentWorkouts = await healthService.fetchRecentWorkouts()
        isLoading = false
    }
}

// MARK: - Supporting Views

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct WeeklyBarChart: View {
    let data: [(date: Date, value: Int)]
    let color: Color

    private var maxValue: Int {
        data.map(\.value).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                VStack(spacing: 4) {
                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.gradient)
                        .frame(height: max(4, CGFloat(entry.value) / CGFloat(maxValue) * 120))

                    Text(dayLabel(entry.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

private struct WorkoutRow: View {
    let workout: HKWorkout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workoutIcon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(workoutName)
                    .font(.subheadline.bold())

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedDuration)
                    .font(.subheadline.bold())

                if let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                    Text("\(Int(calories)) cal")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var workoutName: String {
        switch workout.workoutActivityType {
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .yoga: "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: "Strength Training"
        case .hiking: "Hiking"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .highIntensityIntervalTraining: "HIIT"
        case .dance: "Dance"
        case .pilates: "Pilates"
        default: "Workout"
        }
    }

    private var workoutIcon: String {
        switch workout.workoutActivityType {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .yoga: "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: "dumbbell.fill"
        case .hiking: "figure.hiking"
        case .elliptical: "figure.elliptical"
        case .rowing: "figure.rower"
        case .highIntensityIntervalTraining: "bolt.heart.fill"
        case .dance: "figure.dance"
        case .pilates: "figure.pilates"
        default: "figure.mixed.cardio"
        }
    }

    private var formattedDuration: String {
        let minutes = Int(workout.duration / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes) min"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: workout.startDate)
    }
}

#Preview {
    ActivityView()
}
