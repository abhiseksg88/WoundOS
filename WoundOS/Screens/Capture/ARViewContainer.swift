import SwiftUI
import ARKit
import RealityKit

/// UIViewRepresentable wrapper for ARView to display the camera feed
struct ARViewContainer: UIViewRepresentable {
    let sessionManager: ARSessionManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = sessionManager.session
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        arView.environment.background = .cameraFeed()
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // No-op: session managed externally
    }
}
