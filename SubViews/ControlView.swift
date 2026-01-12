import SwiftUI
import UIKit

struct ControlView: View {
    @Binding var value: Double
    var activeIcon: String
    var activeColors: [Color]
    var iconColorOverride: Color? = nil
    var onUpdate: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let knobDiameter: CGFloat = width - 4
            let bottomPadding: CGFloat = 2
            let trackWidth: CGFloat = 12
            let trackHeight = height - knobDiameter - (bottomPadding * 2)
            
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: trackWidth)
                    .glassEffect(.clear)
                    .padding(.bottom, bottomPadding + 2)
                
                if value > 0 {
                    Capsule()
                        .fill(LinearGradient(colors: activeColors, startPoint: .bottom, endPoint: .top))
                        .frame(width: trackWidth, height: (CGFloat(value) * trackHeight) + knobDiameter + (bottomPadding * 2))
                        .animation(.spring(response: 0.3), value: value)
                }
                
                Image(systemName: activeIcon)
                    .font(.title2)
                    .foregroundColor(value > 0 ? .primary : .secondary)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .padding(5)
                    .glassEffect()
                    .offset(y: -(CGFloat(value) * trackHeight) - 2)
                    .padding(.bottom, bottomPadding)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                let dragY = gesture.location.y
                let rawValue = 1.0 - (dragY / height)
                let clamped = min(max(rawValue, 0.0), 1.0)
                
                if (value == 0 && clamped > 0) || (value > 0 && clamped == 0) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                
                value = clamped
                onUpdate()
            })
        }
        .frame(width: 40, height: 180)
    }
}
