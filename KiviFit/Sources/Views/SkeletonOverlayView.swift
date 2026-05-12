import SwiftUI

/// Maps MediaPipe PoseLandmark indices to their connections (bones)
private let skeletonConnections: [(Int, Int)] = [
    // Face
    (0, 1), (1, 2), (2, 3), (3, 7),
    (0, 4), (4, 5), (5, 6), (6, 8),
    (9, 10),
    // Upper body
    (11, 12), // shoulders
    (11, 13), (13, 15), // left arm
    (12, 14), (14, 16), // right arm
    (15, 17), (15, 19), (15, 21), // left hand
    (16, 18), (16, 20), (16, 22), // right hand
    (17, 19), (18, 20),
    // Torso
    (11, 23), (12, 24), (23, 24),
    // Legs
    (23, 25), (25, 27), (27, 29), (27, 31), (29, 31), // left leg
    (24, 26), (26, 28), (28, 30), (28, 32), (30, 32), // right leg
]

struct NormalizedLandmark {
    var x: Float
    var y: Float
    var z: Float
    var visibility: Float
    var presence: Float
}

struct SkeletonOverlayView: View {
    let landmarks: [NormalizedLandmark]
    let frameSize: CGSize
    let imageSize: CGSize

    var body: some View {
        Canvas { ctx, size in
            guard !landmarks.isEmpty else { return }

            let points = landmarks.map { lm -> CGPoint in
                // Mirror x for front camera (already mirrored via camera session)
                let sx = CGFloat(lm.x) * size.width
                let sy = CGFloat(lm.y) * size.height
                return CGPoint(x: sx, y: sy)
            }

            // Draw bones (green lines)
            var bonePath = Path()
            for (a, b) in skeletonConnections {
                guard a < points.count, b < points.count else { continue }
                let la = landmarks[a]
                let lb = landmarks[b]
                // Only draw if both landmarks are sufficiently visible
                guard la.visibility > 0.35, lb.visibility > 0.35 else { continue }
                bonePath.move(to: points[a])
                bonePath.addLine(to: points[b])
            }
            ctx.stroke(
                bonePath,
                with: .color(.green),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )

            // Draw joint dots (red)
            for (i, pt) in points.enumerated() {
                guard i < landmarks.count else { continue }
                let lm = landmarks[i]
                guard lm.visibility > 0.35 else { continue }

                let r: CGFloat = i == 0 ? 6 : 4 // nose slightly bigger
                let dot = Path(ellipseIn: CGRect(
                    x: pt.x - r, y: pt.y - r,
                    width: r * 2, height: r * 2
                ))
                ctx.fill(dot, with: .color(.red))
                // White center dot for clarity
                let inner = r * 0.4
                let innerDot = Path(ellipseIn: CGRect(
                    x: pt.x - inner, y: pt.y - inner,
                    width: inner * 2, height: inner * 2
                ))
                ctx.fill(innerDot, with: .color(.white))
            }
        }
    }
}
