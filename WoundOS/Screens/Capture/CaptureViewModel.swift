import SwiftUI
import Combine

class CaptureViewModel: ObservableObject {
    let sessionManager = ARSessionManager()
    
    @Published var canCapture: Bool = false
    @Published var isCapturing: Bool = false
    @Published var showFlash: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Update capture availability based on distance quality
        sessionManager.$distanceQuality
            .map { quality in
                quality == .optimal || quality == .good
            }
            .assign(to: &$canCapture)
    }
    
    func startSession() {
        sessionManager.startSession()
    }
    
    func pauseSession() {
        sessionManager.pauseSession()
    }
    
    func capture() -> CaptureData? {
        guard canCapture, !isCapturing else { return nil }
        isCapturing = true
        
        // Haptic feedback
        HapticManager.impact(.medium)
        
        // Flash animation
        withAnimation(.easeOut(duration: 0.15)) {
            showFlash = true
        }
        
        // Capture the frame
        let captureData = sessionManager.captureCurrentFrame()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            withAnimation {
                self?.showFlash = false
            }
        }
        
        return captureData
    }
}
