import SwiftUI

struct SettingsScreen: View {
    @State private var useMockAPI: Bool = SegmentationService.shared.useMockAPI
    @State private var apiEndpoint: String = SegmentationService.shared.apiEndpoint
    @State private var showEndpointEditor = false
    
    var body: some View {
        NavigationStack {
            List {
                // API Configuration
                Section {
                    Toggle("Use Mock API", isOn: $useMockAPI)
                        .onChange(of: useMockAPI) { newValue in
                            SegmentationService.shared.useMockAPI = newValue
                        }
                    
                    if !useMockAPI {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Endpoint")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("https://...", text: $apiEndpoint)
                                .font(.system(.subheadline, design: .monospaced))
                                .textContentType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onChange(of: apiEndpoint) { newValue in
                                    SegmentationService.shared.apiEndpoint = newValue
                                }
                        }
                    }
                } header: {
                    Text("Segmentation API")
                } footer: {
                    Text("Mock API returns sample wound masks for testing without a live backend.")
                }
                
                // Device Information
                Section("Device Info") {
                    infoRow("Device", UIDevice.current.name)
                    infoRow("Model", UIDevice.current.model)
                    infoRow("iOS", UIDevice.current.systemVersion)
                    infoRow("LiDAR", lidarAvailable ? "Available" : "Not Available")
                }
                
                // App Information
                Section("About") {
                    infoRow("App Version", "1.0.0")
                    infoRow("Build", "1")
                    infoRow("Engine", "ARKit LiDAR + RANSAC 3D")
                    
                    Link(destination: URL(string: "https://careplix.com")!) {
                        HStack {
                            Text("CarePlix Healthcare")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Data Management
                Section("Data") {
                    let scanCount = ScanStore.shared.records.count
                    infoRow("Saved Scans", "\(scanCount)")
                    
                    if scanCount > 0 {
                        Button(role: .destructive) {
                            clearAllScans()
                        } label: {
                            Text("Clear All Scans")
                        }
                    }
                }
                
                // Legal
                Section {
                    Text("This app is for clinical reference only and is not intended as a substitute for professional clinical assessment. Measurements are approximate (±5% accuracy) and should be verified by a qualified healthcare provider.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
    
    private var lidarAvailable: Bool {
        if #available(iOS 16.0, *) {
            return ARKitChecker.isLiDARAvailable
        }
        return false
    }
    
    private func clearAllScans() {
        let store = ScanStore.shared
        for record in store.records {
            store.delete(record: record)
        }
    }
}

// MARK: - ARKit LiDAR Check
import ARKit

struct ARKitChecker {
    static var isLiDARAvailable: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
    }
}
