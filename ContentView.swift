import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var captureFlow = CaptureFlowCoordinator()
    
    var body: some View {
        ZStack {
            if captureFlow.isInCaptureFlow {
                // Full-screen capture flow (tab bar hidden)
                captureFlowView
                    .transition(.opacity)
            } else {
                // Normal tab-based navigation
                tabView
            }
        }
        .environmentObject(captureFlow)
    }
    
    private var captureFlowView: some View {
        NavigationStack {
            Group {
                switch captureFlow.currentStep {
                case .capture:
                    CaptureScreen()
                case .processing:
                    ProcessingScreen()
                case .review:
                    ReviewScreen()
                case .results:
                    ResultsScreen()
                }
            }
        }
    }
    
    private var tabView: some View {
        TabView(selection: $appState.selectedTab) {
            // Camera Tab
            Button {
                withAnimation {
                    captureFlow.startCaptureFlow()
                }
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    Text("Tap to Start Scanning")
                        .font(.headline)
                    Text("Position wound 15-35cm from camera")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tabItem {
                Image(systemName: "camera.fill")
                Text("Camera")
            }
            .tag(AppState.AppTab.camera)
            
            // Scans Tab
            ScanHistoryScreen()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Scans")
                }
                .tag(AppState.AppTab.scans)
            
            // Report Tab  
            PatientReportView()
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Report")
                }
                .tag(AppState.AppTab.report)
            
            // Settings Tab
            SettingsScreen()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(AppState.AppTab.settings)
        }
    }
}

// MARK: - Capture Flow Coordinator
class CaptureFlowCoordinator: ObservableObject {
    enum Step {
        case capture, processing, review, results
    }
    
    @Published var isInCaptureFlow = false
    @Published var currentStep: Step = .capture
    @Published var captureData: CaptureData?
    @Published var segmentationResult: SegmentationResult?
    @Published var measurement: WoundMeasurement?
    
    func startCaptureFlow() {
        captureData = nil
        segmentationResult = nil
        measurement = nil
        currentStep = .capture
        isInCaptureFlow = true
    }
    
    func onCaptured(_ data: CaptureData) {
        self.captureData = data
        currentStep = .processing
    }
    
    func onSegmented(_ result: SegmentationResult) {
        self.segmentationResult = result
        currentStep = .review
    }
    
    func onConfirmed(measurement: WoundMeasurement) {
        self.measurement = measurement
        currentStep = .results
    }
    
    func retake() {
        captureData = nil
        segmentationResult = nil
        measurement = nil
        currentStep = .capture
    }
    
    func exitCaptureFlow() {
        isInCaptureFlow = false
        currentStep = .capture
    }
}
