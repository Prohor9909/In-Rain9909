import SwiftUI
import UIKit

struct ControlView: View {
    @Binding var value: Double
    var activeIcon: String
    var activeColors: [Color]
    var onUpdate: () -> Void
    
    // Fixed constants
    private let width: CGFloat = 40
    private let height: CGFloat = 180
    
    var body: some View {
        let knobDiameter: CGFloat = width - 4
        let bottomPadding: CGFloat = 2
        let trackWidth: CGFloat = 12
        let trackHeight = height - knobDiameter - (bottomPadding * 2)
        
        ZStack(alignment: .bottom) {
            // Track Background
            Capsule()
                .fill(Color.white.opacity(0.1))
                .frame(width: trackWidth)
                .glassEffect(.clear)
                .padding(.bottom, bottomPadding + 2)
            
            // Active Fill Level
            if value > 0 {
                Capsule()
                    .fill(LinearGradient(colors: activeColors, startPoint: .bottom, endPoint: .top))
                    .frame(width: trackWidth, height: (CGFloat(value) * trackHeight) + knobDiameter + (bottomPadding * 2))
                    .animation(.spring(response: 0.3), value: value)
            }
            
            // Icon Knob
            Image(systemName: activeIcon)
                .font(.title2)
                .frame(width: knobDiameter, height: knobDiameter)
                .glassEffect()
                .offset(y: -(CGFloat(value) * trackHeight) - 2)
                .padding(.bottom, bottomPadding)
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
            let dragY = gesture.location.y
            // Calculate value based on fixed height
            let rawValue = 1.0 - (dragY / height)
            let clamped = min(max(rawValue, 0.0), 1.0)
            
            // Haptic feedback for 0/1 threshold
            if (value == 0 && clamped > 0) || (value > 0 && clamped == 0) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            
            value = clamped
            onUpdate()
        })
    }
}
