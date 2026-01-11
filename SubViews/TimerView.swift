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
            VStack(spacing: 30) {
                Text("Set Duration").font(.title3).foregroundColor(.white.opacity(0.7)).padding(.top, 20)
                HStack(spacing: 0) {
                    Picker("Hours", selection: $selectedHours) { ForEach(0..<24) { i in Text("\(i) h").tag(i).foregroundColor(.white) } }.pickerStyle(.wheel).frame(width: 70).clipped()
                    Picker("Minutes", selection: $selectedMinutes) { ForEach(0..<60) { i in Text("\(i) m").tag(i).foregroundColor(.white) } }.pickerStyle(.wheel).frame(width: 70).clipped()
                    Picker("Seconds", selection: $selectedSeconds) { ForEach(0..<60) { i in Text("\(i) s").tag(i).foregroundColor(.white) } }.pickerStyle(.wheel).frame(width: 70).clipped()
                }
                .colorScheme(.dark).padding()
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let totalSeconds = TimeInterval((selectedHours * 3600) + (selectedMinutes * 60) + selectedSeconds)
                        if totalSeconds > 0 { timerManager.startTimer(duration: totalSeconds) }
                        dismiss()
                    }.font(.headline).foregroundColor(.blue)
                }
            }
        }
    }
}

struct CountDownView: View {
    @ObservedObject var timerManager: TimerManager
    @Environment(\.dismiss) var dismiss
    @State private var showCancelConfirmation = false
    
    var body: some View {
        VStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.compact.down").font(.system(size: 44, weight: .bold)).foregroundColor(.white.opacity(0.5)).padding(.top, 20)
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 15)
                Circle().trim(from: 0, to: CGFloat(timerManager.progress))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timerManager.progress)
                Text(timerManager.formattedTime)
                    .font(.system(size: 64, weight: .thin, design: .default)).monospacedDigit().foregroundColor(.white)
            }.frame(width: 300, height: 300).padding()
            Spacer()
            Button(action: { showCancelConfirmation = true }) {
                Text("Cancel").font(.title2).fontWeight(.medium).foregroundColor(.black)
                    .frame(width: 110, height: 110).background(Color.gray).clipShape(Circle())
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
            }.padding(.bottom, 50)
        }
        .alert(isPresented: $showCancelConfirmation) {
            Alert(title: Text("Cancel Timer"), message: Text("Are you sure you want to cancel the timer?"), primaryButton: .destructive(Text("Cancel Timer")) { timerManager.stopTimer(); dismiss() }, secondaryButton: .cancel())
        }
    }
}
