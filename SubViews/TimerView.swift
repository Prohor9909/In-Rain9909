import SwiftUI

struct TimerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var timerManager: TimerManager
    var audioManager: AudioEngineManager
    @State private var selectedHours = 0
    @State private var selectedMinutes = 5
    @State private var selectedSeconds = 0
    
    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                Picker("Hours", selection: $selectedHours) { ForEach(0..<24) { i in Text("\(i) h").tag(i) } }
                    .pickerStyle(.wheel)
                    .frame(width: 70)
                    .clipped()
                Picker("Minutes", selection: $selectedMinutes) { ForEach(0..<60) { i in Text("\(i) m").tag(i) } }
                    .pickerStyle(.wheel)
                    .frame(width: 70)
                    .clipped()
                Picker("Seconds", selection: $selectedSeconds) { ForEach(0..<60) { i in Text("\(i) s").tag(i) } }
                    .pickerStyle(.wheel)
                    .frame(width: 70)
                    .clipped()
            }
            .colorScheme(.dark)
            
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        let totalSeconds = TimeInterval((selectedHours * 3600) + (selectedMinutes * 60) + selectedSeconds)
                        if totalSeconds > 0 { timerManager.startTimer(duration: totalSeconds) }
                        dismiss()
                    }) {
                        Text("Set")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}
