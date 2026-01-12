import SwiftUI

struct LightningEffectView: View {
    var intensity: Double
    var triggerFlash: Bool
    var isEnabled: Bool
    
    @State private var flashMultiplier = 0.0
    
    var body: some View {
        RadialGradient(
            colors: [.white.opacity(0.8), .clear],
            center: .top,
            startRadius: 0,
            endRadius: 600
        )
            .ignoresSafeArea()
            .opacity(isEnabled ? flashMultiplier * intensity * 0.5 : 0)
            .allowsHitTesting(false)
            .task(id: triggerFlash) {
                guard isEnabled && intensity > 0 else { return }
                
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                
                withAnimation(.bouncy(duration: 0.4)) { flashMultiplier = 1.0 }
                try? await Task.sleep(nanoseconds: 400_000_000)
                withAnimation(.easeOut(duration: 0.4)) { flashMultiplier = 0.0 }
                
                while !Task.isCancelled {
                    let interval = Double.random(in: 1.0...5.0)
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    
                    let loopIntensity = Double.random(in: 0.4...0.7)
                    withAnimation(.bouncy(duration: 0.2)) { flashMultiplier = loopIntensity }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    withAnimation(.easeOut(duration: 0.2)) { flashMultiplier = 0.0 }
                }
            }
            .onChange(of: isEnabled) {
                if !isEnabled { flashMultiplier = 0.0 }
            }
    }
}

struct RainParticle: Identifiable { let id = UUID(); var x: CGFloat; var y: CGFloat; var speed: Double; var opacity: Double; var scale: Double; var length: CGFloat }
struct RainEffectView: View {
    var intensity: Double
    var windAngle: Double
    @State private var particles = [RainParticle]()
    private var targetParticleCount: Int { return intensity > 0 ? Int(300 + (800 * intensity)) : 0 }
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                Canvas { context, size in
                    for particle in particles {
                        var particleContext = context; particleContext.opacity = particle.opacity
                        let frame = CGRect(x: particle.x, y: particle.y, width: 2 * particle.scale, height: particle.length)
                        particleContext.fill(Capsule().path(in: frame), with: .color(.white.opacity(0.7)))
                    }
                }
                .rotationEffect(.degrees(10 + (windAngle * 5)))
                .opacity(intensity > 0 ? 1.0 : 0.0).animation(.linear(duration: 0.3), value: intensity > 0)
                .onChange(of: timeline.date) {
                    let volumeSpeedMultiplier = 1.0 + (intensity * 0.3)
                    for i in particles.indices {
                        particles[i].y += particles[i].speed * (0.016 * 60) * 2.25 * volumeSpeedMultiplier * 0.3
                        if particles[i].y > geometry.size.height + 100 { particles[i] = createParticle(in: geometry.size, isInitial: false) }
                    }
                }
            }
            .onAppear { particles = (0..<targetParticleCount).map { _ in createParticle(in: geometry.size, isInitial: true) } }
            .onChange(of: intensity) {
                let diff = targetParticleCount - particles.count
                if diff > 0 { particles.append(contentsOf: (0..<diff).map { _ in createParticle(in: geometry.size, isInitial: false) }) }
                else if diff < 0 { particles.removeLast(abs(diff)) }
            }
        }.allowsHitTesting(false)
    }
    private func createParticle(in size: CGSize, isInitial: Bool) -> RainParticle {
        let scale = Double.random(in: 0.5...1.0)
        return RainParticle(x: .random(in: -50...size.width + 50), y: .random(in: isInitial ? -100...size.height : -150...(-50)), speed: .random(in: 15...25) * scale, opacity: .random(in: 0.1...0.5), scale: scale, length: .random(in: 20...50) * scale)
    }
}

struct FireParticle: Identifiable { let id = UUID(); var x: CGFloat; var y: CGFloat; var speed: Double; var opacity: Double; var scale: Double; var color: Color; var drift: Double; var shapeSeed: Double }
struct FireGlowView: View {
    let intensity: Double
    @State private var isAnimating1 = false
    @State private var isAnimating2 = false
    private var glowScale: CGFloat { 0.5 + (intensity * 1) }
    var body: some View {
        ZStack {
            Ellipse().fill(Color.orange.opacity(0.6)).frame(width: 300 * glowScale, height: 100 * glowScale).blur(radius: 60).scaleEffect(isAnimating1 ? 1.05 : 0.95, anchor: .bottom).opacity(isAnimating1 ? 0.7 : 0.5)
            Ellipse().fill(Color.yellow.opacity(0.5)).frame(width: 200 * glowScale, height: 80 * glowScale).blur(radius: 50).scaleEffect(isAnimating2 ? 0.95 : 1.05, anchor: .bottom).opacity(isAnimating2 ? 0.6 : 0.4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).opacity(intensity > 0 ? 1.0 : 0.0).animation(.linear(duration: 0.5), value: intensity)
        .onAppear { withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) { isAnimating1 = true }; withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { isAnimating2 = true } }
        .allowsHitTesting(false)
    }
}
struct FireEffectView: View {
    var ParticleSize = 8.0
    var intensity: Double
    @State private var particles = [FireParticle]()
    private var targetParticleCount: Int { Int(10 + (100 * intensity)) }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                FireGlowView(intensity: intensity)
                TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                    Canvas { context, size in
                        for particle in particles {
                            var particleContext = context; particleContext.opacity = particle.opacity
                            let frame = CGRect(x: particle.x, y: particle.y, width: ParticleSize * particle.scale, height: ParticleSize * particle.scale)
                            let shape = createEmberShape(in: frame, seed: particle.shapeSeed, time: timeline.date.timeIntervalSinceReferenceDate)
                            particleContext.addFilter(.shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)); particleContext.fill(shape, with: .color(particle.color))
                        }
                    }
                    .opacity(intensity > 0 ? 1.0 : 0.0).animation(.linear(duration: 0.3), value: intensity > 0)
                    .onChange(of: timeline.date) {
                        let volumeSpeedMultiplier = 1.0 + (intensity * 0.5)
                        for i in particles.indices {
                            particles[i].y -= particles[i].speed * (0.016 * 60) * volumeSpeedMultiplier; particles[i].x += sin(timeline.date.timeIntervalSinceReferenceDate * particles[i].drift) * 0.5; particles[i].opacity -= 0.008
                            if particles[i].y < geometry.size.height - 250 || particles[i].opacity <= 0 { particles[i] = createParticle(in: geometry.size) }
                        }
                    }
                }
            }
            .onAppear { particles = (0..<targetParticleCount).map { _ in createParticle(in: geometry.size) } }
            .onChange(of: intensity) {
                let diff = targetParticleCount - particles.count
                if diff > 0 { particles.append(contentsOf: (0..<diff).map { _ in createParticle(in: geometry.size) }) }
                else if diff < 0 { particles.removeLast(abs(diff)) }
            }
        }
    }
    private func createEmberShape(in rect: CGRect, seed: Double, time: TimeInterval) -> Path {
        var path = Path(); let wobble = sin(time * 3 + seed) * (rect.width / 3), wobble2 = cos(time * 2 + seed) * (rect.width / 3)
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.maxX + wobble, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY + wobble2))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.minX - wobble, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY - wobble2))
        return path
    }
    private func createParticle(in size: CGSize) -> FireParticle {
        let scale = Double.random(in: 0.4...1.0)
        return FireParticle(x: .random(in: 0...size.width), y: .random(in: size.height...size.height + 40), speed: .random(in: 0.3...1.0), opacity: .random(in: 0.6...0.9), scale: scale, color: [.orange, .yellow, .red].randomElement()!, drift: .random(in: 1...3), shapeSeed: .random(in: 0...100))
    }
}
