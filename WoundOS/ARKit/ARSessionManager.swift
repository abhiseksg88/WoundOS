import ARKit
import Combine
import UIKit

/// Manages the ARKit session lifecycle and provides frame data via Combine publishers
class ARSessionManager: NSObject, ObservableObject {
    let session = ARSession()
    private let depthReader = DepthReader()
    
    // Published state
    @Published var currentDistance: Float = 0  // in cm
    @Published var distanceQuality: DistanceQuality = .noDepth
    @Published var isSessionRunning = false
    @Published var sessionError: String?
    
    // Latest frame reference (for capture)
    private(set) var latestFrame: ARFrame?
    
    override init() {
        super.init()
        session.delegate = self
    }
    
    /// Start the AR session with LiDAR depth
    func startSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            sessionError = "ARKit is not supported on this device."
            return
        }
        
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) else {
            sessionError = "LiDAR depth scanning is not available. iPhone 12 Pro or later required."
            return
        }
        
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = [.smoothedSceneDepth]
        
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        sessionError = nil
        depthReader.reset()
    }
    
    /// Pause the AR session
    func pauseSession() {
        session.pause()
        isSessionRunning = false
    }
    
    /// Capture current frame data
    func captureCurrentFrame() -> CaptureData? {
        guard let frame = latestFrame else { return nil }
        guard let sceneDepth = frame.smoothedSceneDepth else { return nil }
        
        // Extract RGB image
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let rgbImage = UIImage(cgImage: cgImage)
        
        // Convert to JPEG
        guard let jpegData = rgbImage.jpegData(compressionQuality: 0.85) else { return nil }
        
        // Extract depth data
        let depthMap = depthReader.extractDepthArray(from: sceneDepth.depthMap)
        let depthWidth = CVPixelBufferGetWidth(sceneDepth.depthMap)
        let depthHeight = CVPixelBufferGetHeight(sceneDepth.depthMap)
        
        // Extract confidence
        var confidenceArray: [UInt8] = []
        if let confMap = sceneDepth.confidenceMap {
            confidenceArray = depthReader.extractConfidenceArray(from: confMap)
        }
        
        // Camera intrinsics
        let intrinsicMatrix = frame.camera.intrinsics
        let intrinsics = CaptureData.CameraIntrinsics(
            fx: intrinsicMatrix[0][0],
            fy: intrinsicMatrix[1][1],
            cx: intrinsicMatrix[2][0],
            cy: intrinsicMatrix[2][1]
        )
        
        // Center depth for capture distance
        let captureDistance = depthReader.readCenterDepth(from: frame) ?? 0
        
        // Device model
        var systemInfo = utsname()
        uname(&systemInfo)
        let deviceModel = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        
        return CaptureData(
            rgbImage: rgbImage,
            rgbJPEGData: jpegData,
            depthMap: depthMap,
            confidenceMap: confidenceArray,
            depthWidth: depthWidth,
            depthHeight: depthHeight,
            rgbWidth: Int(cgImage.width),
            rgbHeight: Int(cgImage.height),
            intrinsics: intrinsics,
            captureDistance: captureDistance,
            timestamp: Date(),
            deviceModel: deviceModel
        )
    }
}

// MARK: - ARSessionDelegate
extension ARSessionManager: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        latestFrame = frame
        
        // Update distance at frame rate (throttled by ARKit ~60Hz, we display at ~10Hz in UI)
        if let distance = depthReader.readCenterDepth(from: frame) {
            let distanceCm = distance * 100
            DispatchQueue.main.async { [weak self] in
                self?.currentDistance = distanceCm
                self?.distanceQuality = DistanceQuality.from(distance: distanceCm)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.distanceQuality = .noDepth
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.sessionError = error.localizedDescription
            self?.isSessionRunning = false
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isSessionRunning = false
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        startSession()
    }
}
