import SwiftUI
import SwiftData

struct WeightTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]

    @State private var newWeight = ""
    @FocusState private var isWeightFieldFocused: Bool

    private var latestWeight: Double? {
        weightEntries.first?.weight
    }

    private var weightChange: Double? {
        guard weightEntries.count >= 2 else { return nil }
        return weightEntries[0].weight - weightEntries[1].weight
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
        }
    }

    private func addWeight() {
        guard let weight = Double(newWeight), weight > 0, weight < 1000 else { return }
        let entry = WeightEntry(weight: weight)
        modelContext.insert(entry)
        newWeight = ""
        isWeightFieldFocused = false
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(weightEntries[index])
        }
    }
}
