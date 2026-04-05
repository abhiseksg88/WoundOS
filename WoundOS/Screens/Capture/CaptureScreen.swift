import SwiftUI

struct CaptureScreen: View {
    @EnvironmentObject var flow: CaptureFlowCoordinator
    @StateObject private var viewModel = CaptureViewModel()
    
    var body: some View {
        ZStack {
            // AR Camera feed
            ARViewContainer(sessionManager: viewModel.sessionManager)
                .ignoresSafeArea()
            
            // Flash overlay
            if viewModel.showFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // UI Overlay
            VStack {
                // Distance pill (top)
                DistancePill(
                    distance: viewModel.sessionManager.currentDistance,
                    quality: viewModel.sessionManager.distanceQuality
                )
                .padding(.top, 60)
                
                Spacer()
                
                // Error message if needed
                if let error = viewModel.sessionManager.sessionError {
                    errorBanner(error)
                }
                
                // Capture button (bottom)
                CaptureButton(isEnabled: viewModel.canCapture) {
                    if let captureData = viewModel.capture() {
                        viewModel.pauseSession()
                        flow.onCaptured(captureData)
                    }
                }
                .padding(.bottom, 40)
                
                Text("Position wound 15-35cm from camera")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 20)
            }
            
            // Close button (top-left)
            VStack {
                HStack {
                    Button {
                        viewModel.pauseSession()
                        flow.exitCaptureFlow()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.7))
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.top, 60)
                    .padding(.leading, 20)
                    
                    Spacer()
                }
                Spacer()
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.pauseSession()
        }
        .navigationBarHidden(true)
    }
    
    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding()
            .background(Color.red.opacity(0.8))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
    }
}
