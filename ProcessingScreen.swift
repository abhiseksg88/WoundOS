import SwiftUI

// MARK: - Processing Screen
struct ProcessingScreen: View {
    @EnvironmentObject var flow: CaptureFlowCoordinator
    @StateObject private var viewModel = ProcessingViewModel()
    
    var body: some View {
        ZStack {
            // Background: captured image with blur
            if let captureData = flow.captureData {
                Image(uiImage: captureData.rgbImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: 10)
                    .overlay(Color.black.opacity(0.3))
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // Center: progress indicator
            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(viewModel.statusMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut, value: viewModel.statusMessage)
                
                if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                        
                        Button("Try Again") {
                            if let data = flow.captureData {
                                viewModel.startProcessing(captureData: data)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
            }
            .padding()
        }
        .navigationBarHidden(true)
        .onAppear {
            if let data = flow.captureData {
                viewModel.startProcessing(captureData: data)
            }
        }
        .onChange(of: viewModel.result) { result in
            if let result = result {
                flow.onSegmented(result)
            }
        }
    }
}

// MARK: - Processing ViewModel
class ProcessingViewModel: ObservableObject {
    @Published var statusMessage = "Analyzing wound..."
    @Published var errorMessage: String?
    @Published var result: SegmentationResult?
    
    private var processingTask: Task<Void, Never>?
    
    func startProcessing(captureData: CaptureData) {
        errorMessage = nil
        result = nil
        
        processingTask?.cancel()
        processingTask = Task { @MainActor in
            do {
                // Phase 1: API call
                statusMessage = "Analyzing wound..."
                try await Task.sleep(for: .milliseconds(300))
                
                statusMessage = "AI processing image..."
                let segResult = try await SegmentationService.shared.segment(image: captureData.rgbJPEGData)
                
                statusMessage = "Computing 3D measurements..."
                try await Task.sleep(for: .milliseconds(500))
                
                statusMessage = "Done ✓"
                try await Task.sleep(for: .milliseconds(400))
                
                result = segResult
                
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Processing failed"
            }
        }
    }
    
    deinit {
        processingTask?.cancel()
    }
}
