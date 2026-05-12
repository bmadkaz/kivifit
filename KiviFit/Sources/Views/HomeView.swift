import SwiftUI

struct HomeView: View {
    let onStart: () -> Void
    @State private var pulse = false
    @State private var appear = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "0A0A0F"), Color(hex: "0D1B2A"), Color(hex: "0A0A0F")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated grid lines
            GeometryReader { geo in
                Canvas { ctx, size in
                    let spacing: CGFloat = 40
                    ctx.opacity = 0.07
                    var path = Path()
                    var x: CGFloat = 0
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y < size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }
                    ctx.stroke(path, with: .color(.green), lineWidth: 0.5)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / Icon area
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.15), lineWidth: 1)
                        .frame(width: pulse ? 200 : 180, height: pulse ? 200 : 180)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        .frame(width: pulse ? 150 : 135, height: pulse ? 150 : 135)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.3), value: pulse)

                    // Stick figure skeleton icon
                    SkeletonIcon()
                        .frame(width: 90, height: 110)
                }
                .padding(.bottom, 40)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.7)

                // Title
                VStack(spacing: 8) {
                    Text("KIVI")
                        .font(.system(size: 56, weight: .black, design: .default))
                        .foregroundColor(.white)
                        .tracking(12)
                    + Text("FIT")
                        .font(.system(size: 56, weight: .black, design: .default))
                        .foregroundColor(.green)
                        .tracking(12)

                    Text("AI ТРЕНЕР ПО ДВИЖЕНИЮ")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green.opacity(0.7))
                        .tracking(4)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)

                Spacer().frame(height: 60)

                // Feature bullets
                VStack(spacing: 16) {
                    FeatureRow(icon: "figure.walk", text: "Анализ позы в реальном времени")
                    FeatureRow(icon: "ear.fill", text: "Голосовые подсказки об ошибках")
                    FeatureRow(icon: "cpu", text: "GPU ускорение (Metal)")
                }
                .padding(.horizontal, 40)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 30)

                Spacer().frame(height: 60)

                // Start Button
                Button(action: onStart) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("НАЧАТЬ ТРЕНИРОВКУ")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "00FF41"), Color(hex: "00C853")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.green.opacity(0.4), radius: 20, x: 0, y: 8)
                }
                .padding(.horizontal, 32)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.9)

                Spacer().frame(height: 50)
            }
        }
        .onAppear {
            pulse = true
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.1)) {
                appear = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.75))
            Spacer()
        }
    }
}

struct SkeletonIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let lw: CGFloat = 2.5

            // Joints (red dots)
            let joints: [CGPoint] = [
                CGPoint(x: w * 0.5, y: h * 0.08),   // head
                CGPoint(x: w * 0.5, y: h * 0.28),   // neck
                CGPoint(x: w * 0.25, y: h * 0.35),  // L shoulder
                CGPoint(x: w * 0.75, y: h * 0.35),  // R shoulder
                CGPoint(x: w * 0.15, y: h * 0.55),  // L elbow
                CGPoint(x: w * 0.85, y: h * 0.55),  // R elbow
                CGPoint(x: w * 0.1, y: h * 0.72),   // L wrist
                CGPoint(x: w * 0.9, y: h * 0.72),   // R wrist
                CGPoint(x: w * 0.5, y: h * 0.55),   // hip center
                CGPoint(x: w * 0.35, y: h * 0.72),  // L knee
                CGPoint(x: w * 0.65, y: h * 0.72),  // R knee
                CGPoint(x: w * 0.3, y: h * 0.92),   // L ankle
                CGPoint(x: w * 0.7, y: h * 0.92),   // R ankle
            ]

            // Bones (green lines)
            let bones: [(Int, Int)] = [
                (0, 1), (1, 2), (1, 3),
                (2, 4), (4, 6),
                (3, 5), (5, 7),
                (1, 8),
                (8, 9), (9, 11),
                (8, 10), (10, 12)
            ]

            var bonePath = Path()
            for (a, b) in bones {
                bonePath.move(to: joints[a])
                bonePath.addLine(to: joints[b])
            }
            ctx.stroke(bonePath, with: .color(.green), style: StrokeStyle(lineWidth: lw, lineCap: .round))

            // Head circle
            let headR: CGFloat = 9
            ctx.fill(
                Path(ellipseIn: CGRect(x: joints[0].x - headR, y: joints[0].y - headR, width: headR * 2, height: headR * 2)),
                with: .color(.red)
            )

            // Joint dots
            for joint in joints.dropFirst() {
                let r: CGFloat = 3.5
                ctx.fill(
                    Path(ellipseIn: CGRect(x: joint.x - r, y: joint.y - r, width: r * 2, height: r * 2)),
                    with: .color(.red)
                )
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
