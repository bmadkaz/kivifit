import SwiftUI

struct ContentView: View {
    @State private var isWorkoutActive = false
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""

    var body: some View {
        if isWorkoutActive {
            WorkoutView(isActive: $isWorkoutActive)
                .ignoresSafeArea()
        } else {
            HomeView(
                onStart: {
                    PermissionManager.shared.requestAll { granted, message in
                        DispatchQueue.main.async {
                            if granted {
                                isWorkoutActive = true
                            } else {
                                permissionMessage = message
                                showPermissionAlert = true
                            }
                        }
                    }
                }
            )
            .alert("Разрешения необходимы", isPresented: $showPermissionAlert) {
                Button("Настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text(permissionMessage)
            }
        }
    }
}
