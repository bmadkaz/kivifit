import SwiftUI
import AVFoundation

struct WorkoutView: View {
    @Binding var isActive: Bool
    @StateObject private var viewModel = WorkoutViewModel()

    var body: some View {
        ZStack {
            // Camera preview layer
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()

            // Skeleton overlay
            GeometryReader { geo in
                SkeletonOverlayView(
                    landmarks: viewModel.landmarks,
                    frameSize: geo.size,
                    imageSize: viewModel.imageSize
                )
                .ignoresSafeArea()
            }

            // HUD overlay
            VStack {
                // Top bar
                HStack {
                    Button(action: { isActive = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()

                    Spacer()

                    // FPS counter
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(viewModel.fps) FPS")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Text(viewModel.processingStatus)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                }
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.6), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer()

                // Error / feedback panel
                if !viewModel.currentError.isEmpty {
                    ErrorBanner(message: viewModel.currentError)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Bottom bar
                HStack {
                    // Exercise selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("УПРАЖНЕНИЕ")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.green.opacity(0.7))
                            .tracking(2)
                        Text(viewModel.selectedExercise.rawValue)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Exercise picker menu
                    Menu {
                        ForEach(Exercise.allCases, id: \.self) { exercise in
                            Button(exercise.rawValue) {
                                viewModel.selectExercise(exercise)
                            }
                        }
                    } label: {
                        Image(systemName: "list.bullet.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .animation(.spring(response: 0.4), value: viewModel.currentError)
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red, lineWidth: 1)
                )
        )
    }
}
