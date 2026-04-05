import SwiftUI

@main
struct WoundOSApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .camera
    @Published var isCapturing: Bool = true // Start in capture mode
    
    enum AppTab: Int {
        case camera = 0
        case scans = 1
        case report = 2
        case settings = 3
    }
}
