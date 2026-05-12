import SwiftUI

// MediaPipe BlazePose 33-point landmark indices:
//  0=нос  1=левый глаз внутри  2=левый глаз  3=левый глаз снаружи
//  4=правый глаз внутри  5=правый глаз  6=правый глаз снаружи
//  7=левое ухо  8=правое ухо  9=рот левый  10=рот правый
// 11=левое плечо  12=правое плечо  13=левый локоть  14=правый локоть
// 15=левое запястье  16=правое запястье  17=левый мизинец  18=правый мизинец
// 19=левый указатель  20=правый указатель  21=левый большой  22=правый большой
// 23=левое бедро  24=правое бедро  25=левое колено  26=правое колено
// 27=левая лодыжка  28=правая лодыжка  29=левая пятка  30=правая пятка
// 31=левый носок  32=правый носок
private let skeletonConnections: [(Int, Int)] = [
    (0, 1), (1, 2), (2, 3), (3, 7),
    (0, 4), (4, 5), (5, 6), (6, 8),
    (9, 10),
    (11, 12),
    (11, 13), (13, 15),
    (12, 14), (14, 16),
    (15, 17), (15, 19), (15, 21),
    (16, 18), (16, 20), (16, 22),
    (17, 19), (18, 20),
    (11, 23), (12, 24), (23, 24),
    (23, 25), (25, 27), (27, 29), (27, 31), (29, 31),
    (24, 26), (26, 28), (28, 30), (28, 32), (30, 32),
]

struct PoseLandmark {
    var x: Float
    var y: Float
    var z: Float
    var visibility: Float
    var presence: Float
}

struct SkeletonOverlayView: View {
    let landmarks: [PoseLandmark]
    let frameSize: CGSize   // view size
    let imageSize: CGSize   // MediaPipe input image size (portrait: 360×480)

    var body: some View {
        Canvas { ctx, size in
            guard !landmarks.isEmpty else { return }

            // AVCaptureVideoPreviewLayer uses .resizeAspectFill:
            // scale up the image so it covers the entire view, crop the overflow.
            let scaleToFill = max(size.width  / imageSize.width,
                                  size.height / imageSize.height)
            let scaledW = imageSize.width  * scaleToFill
            let scaledH = imageSize.height * scaleToFill
            // How many scaled pixels are cropped on each side
            let cropX = (scaledW - size.width)  / 2
            let cropY = (scaledH - size.height) / 2

            let points: [CGPoint] = landmarks.map { lm in
                let sx = CGFloat(lm.x) * scaledW - cropX
                let sy = CGFloat(lm.y) * scaledH - cropY
                return CGPoint(x: sx, y: sy)
            }

            // Bones (green)
            var bonePath = Path()
            for (a, b) in skeletonConnections {
                guard a < points.count, b < points.count else { continue }
                guard landmarks[a].visibility > 0.35, landmarks[b].visibility > 0.35 else { continue }
                bonePath.move(to: points[a])
                bonePath.addLine(to: points[b])
            }
            ctx.stroke(bonePath, with: .color(.green),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            // Joints + index numbers
            for (i, pt) in points.enumerated() {
                guard i < landmarks.count, landmarks[i].visibility > 0.35 else { continue }

                let r: CGFloat = i == 0 ? 6 : 4

                // Red dot
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                                width: r * 2, height: r * 2)),
                         with: .color(.red))
                // White center
                let inner = r * 0.4
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - inner, y: pt.y - inner,
                                                width: inner * 2, height: inner * 2)),
                         with: .color(.white))

                // Index number (yellow, small, offset to avoid overlap with dot)
                ctx.draw(
                    Text("\(i)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow),
                    at: CGPoint(x: pt.x + r + 3, y: pt.y - r),
                    anchor: .topLeading
                )
            }
        }
    }
}
